import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/shake.dart';
import '../application/addresses_controllers.dart';
import '../application/delivery_address.dart';
import '../domain/address_search.dart';
import '../domain/addresses.dart';
import 'address_label_chips.dart';
import 'address_leave_sheet.dart';
import 'address_point_step.dart';
import 'map/address_map.dart';

/// A new address, or an edit of [addressId]. A new address is two steps on
/// one screen: the point on the map, then the details under a still preview
/// of it; an edit opens on the details. A point outside the service area is
/// refused with both distances, as the server answers (`BR-AREA-001`).
class AddressFormScreen extends ConsumerWidget {
  const AddressFormScreen({required this.addressId, super.key});

  final String? addressId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String? id = addressId;

    if (id == null) {
      return const _AddressForm(address: null);
    }

    final AsyncValue<List<Address>> addresses = ref.watch(addressesProvider);
    return addresses.when(
      skipLoadingOnReload: false,
      // A retry after a failed load shows progress; a reload after a
      // save keeps the form.
      skipLoadingOnRefresh: !addresses.hasError,
      data: (List<Address> addresses) {
        final Address? address = addresses
            .where((Address a) => a.id == id)
            .firstOrNull;
        return address == null
            ? _Plain(child: Center(child: Text(l10n.errorNotFound)))
            : _AddressForm(address: address);
      },
      error: (Object error, StackTrace _) => _Plain(
        child: _Retry(
          failure: error is ApiFailure ? error : const UnexpectedFailure(),
          onRetry: () => ref.invalidate(addressesProvider),
        ),
      ),
      loading: () =>
          const _Plain(child: Center(child: CircularProgressIndicator())),
    );
  }
}

/// The edit screen while its address is not there to show.
class _Plain extends StatelessWidget {
  const _Plain({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(title: AppLocalizations.of(context).addressEdit),
      body: SafeArea(child: UnderActiveMode(child: child)),
    );
  }
}

enum _Step { point, details }

/// The one transition running between the steps of a new address: the map
/// shrinking into the preview, the preview growing back, and with reduced
/// motion the map step fading in after it (`DL-138`).
enum _Move { none, toDetails, toMap, mapIn }

/// Which part of a form field a call builds: the field whole, or its label
/// and its input apart, for two fields that share a row.
enum _FieldPart { whole, label, input }

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.address});

  final Address? address;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm>
    with SingleTickerProviderStateMixin {
  static const int _streetMax = 160;

  /// The fields in the order the keyboard's "next" walks them and a save
  /// looks for the first gap (`DL-138`).
  static const List<String> _order = <String>[
    'street',
    'house',
    'apartment',
    'landmark',
    'delivery_note',
    'label',
  ];

  final Map<String, FocusNode> _focus = <String, FocusNode>{
    for (final String key in _order) key: FocusNode(),
  };

  /// Each field's visible label, where a save scrolls to.
  final Map<String, GlobalKey> _labelKeys = <String, GlobalKey>{
    for (final String key in _order) key: GlobalKey(),
  };

  final ScrollController _scroll = ScrollController();

  /// The fields that show their problem: left empty, or a save found them
  /// wanting.
  final Set<String> _marked = <String>{};

  /// How many times each field was asked to shake.
  final Map<String, int> _shakes = <String, int>{};

  /// The save is done and its check shows before the screen closes.
  bool _saved = false;
  final TextEditingController _label = TextEditingController();
  late final TextEditingController _street = TextEditingController(
    text: widget.address?.street ?? '',
  );
  late final TextEditingController _house = TextEditingController(
    text: widget.address?.house ?? '',
  );
  late final TextEditingController _apartment = TextEditingController(
    text: widget.address?.apartment ?? '',
  );
  late final TextEditingController _landmark = TextEditingController(
    text: widget.address?.landmark ?? '',
  );
  late final TextEditingController _note = TextEditingController(
    text: widget.address?.deliveryNote ?? '',
  );

  /// The delivery address as the form opened; a new address' map opens there
  /// when the phone's location is not already allowed (`DL-138`).
  late final Address? _delivery = _isNew
      ? ref.read(deliveryAddressProvider).value
      : null;

  late GeoPoint _point =
      widget.address?.point ?? _delivery?.point ?? defaultMapCentre;

  /// The Customer confirmed a point on this new address; going back to the
  /// map keeps it placed.
  bool _pointConfirmed = false;

  /// A new address starts on the map, an edit on the details.
  late _Step _step = _isNew ? _Step.point : _Step.details;

  /// Chosen from the address's label once the language is known.
  AddressLabelKind? _kind;

  /// The point of the last save, so a refusal of the area is shown only
  /// while the pin is still where it was refused.
  GeoPoint? _sentPoint;

  /// The words the street was last filled with from the map step.
  String? _filledWords;

  /// The map step was opened from the details of a new address, so back
  /// from it returns there.
  bool _backToDetails = false;

  /// Runs the morph between the steps; [_move] says which one.
  late final AnimationController _morph = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  _Move _move = _Move.none;

  /// The height of the map area when the point was confirmed: the preview
  /// shrinks from it and grows back to it.
  double _mapHeight = 0;

  /// What the map named under the confirmed point, `null` when it named
  /// nothing.
  PointAddress? _place;

  /// The map step's search field holds words, and those words.
  bool _typed = false;
  String _typedWords = '';

  /// The map step is reached by the preview growing back: its panel rises.
  bool _rise = false;

  /// The leave sheet is open.
  bool _leaving = false;

  bool get _isNew => widget.address == null;

  @override
  void initState() {
    super.initState();
    _morph.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed) {
        _moveDone();
      }
    });
    for (final String key in <String>['street', 'house']) {
      _focus[key]!.addListener(() => _left(key));
    }
  }

  /// Leaving an empty required field says it is needed at once.
  void _left(String key) {
    if (_focus[key]!.hasFocus ||
        _step != _Step.details ||
        _controller(key).text.trim().isNotEmpty ||
        _marked.contains(key)) {
      return;
    }
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          setState(() => _marked.add(key));
        }
      });
    } else if (mounted) {
      setState(() => _marked.add(key));
    }
  }

  TextEditingController _controller(String key) => switch (key) {
    'street' => _street,
    'house' => _house,
    'apartment' => _apartment,
    'landmark' => _landmark,
    'delivery_note' => _note,
    _ => _label,
  };

  static int _maxOf(String key) => switch (key) {
    'street' => _streetMax,
    'house' || 'apartment' => 40,
    'landmark' => 160,
    'delivery_note' => 300,
    _ => 60,
  };

  /// What is wrong with the field's text, or null.
  String? _problem(String key, AppLocalizations l10n) {
    final String value = _controller(key).text.trim();
    if ((key == 'street' || key == 'house') && value.isEmpty) {
      return l10n.fieldRequired;
    }
    final int max = _maxOf(key);
    return value.runes.length > max ? l10n.fieldTooLong(max) : null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_kind == null) {
      final String? label = widget.address?.label;
      final AddressLabelKind kind = addressLabelKindOf(
        label,
        AppLocalizations.of(context),
      );
      if (kind == AddressLabelKind.custom) {
        _label.text = label ?? '';
      }
      _kind = kind;
    }
  }

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _label,
      _street,
      _house,
      _apartment,
      _landmark,
      _note,
    ]) {
      controller.dispose();
    }
    for (final FocusNode node in _focus.values) {
      node.dispose();
    }
    _scroll.dispose();
    _morph.dispose();
    super.dispose();
  }

  static String? _optional(String text) {
    final String value = text.trim();
    return value.isEmpty ? null : value;
  }

  /// The word, or the Customer's own text, the address is named by.
  String? _labelValue(AppLocalizations l10n) =>
      switch (_kind ?? AddressLabelKind.none) {
        AddressLabelKind.none => null,
        AddressLabelKind.home => l10n.addressLabelHome,
        AddressLabelKind.work => l10n.addressLabelWork,
        AddressLabelKind.custom => _optional(_label.text),
      };

  /// The words may fill the street on a new address while it is empty or
  /// still holds what the words filled before, unedited.
  bool get _streetTakesWords =>
      _isNew && (_street.text.trim().isEmpty || _street.text == _filledWords);

  /// The Customer confirmed the pin: the details follow. The words they typed
  /// fill the street where [_streetTakesWords] allows. While a morph runs a
  /// second confirm does nothing.
  void _confirmed(AddressPointResult result) {
    if (_move != _Move.none) {
      return;
    }
    void change() {
      _point = result.point;
      final String? words = result.words;
      if (words != null && _streetTakesWords) {
        final String filled = String.fromCharCodes(
          words.runes.take(_streetMax),
        );
        _street.text = filled;
        _filledWords = filled;
      }
      _backToDetails = false;
      _pointConfirmed = true;
      _step = _Step.details;
      _place = result.place;
      _typed = false;
      _typedWords = '';
      _rise = false;
      if (result.mapHeight > 0) {
        _mapHeight = result.mapHeight;
      }
    }

    if (_isNew) {
      _run(_Move.toDetails, change);
    } else {
      setState(change);
    }
  }

  /// Starts [move] after [change]; the controller's length follows the
  /// motion setting.
  void _run(_Move move, VoidCallback change) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    _morph.duration = Duration(
      milliseconds: switch (move) {
        _Move.toDetails => still ? 200 : 400,
        _Move.toMap => still ? 160 : 320,
        _ => 200,
      },
    );
    setState(() {
      change();
      _move = move;
    });
    _morph.forward(from: 0);
  }

  void _moveDone() {
    if (!mounted) {
      return;
    }
    switch (_move) {
      case _Move.toMap:
        final bool still = MediaQuery.disableAnimationsOf(context);
        void arrive() {
          _step = _Step.point;
          _typed = false;
          _typedWords = '';
          _rise = !still;
        }

        if (still) {
          _run(_Move.mapIn, arrive);
        } else {
          setState(() {
            arrive();
            _move = _Move.none;
          });
        }
      case _Move.toDetails || _Move.mapIn:
        setState(() => _move = _Move.none);
      case _Move.none:
        break;
    }
  }

  /// Something was entered on a new address: leaving would lose it.
  bool get _entered =>
      _typed ||
      <TextEditingController>[
        _street,
        _house,
        _apartment,
        _landmark,
        _note,
      ].any((TextEditingController c) => c.text.trim().isNotEmpty) ||
      (_kind ?? AddressLabelKind.none) != AddressLabelKind.none;

  /// Back walks the steps; nothing moves while a save or a morph runs, and a
  /// new address that was filled in asks before it is left.
  void _back(bool didPop) {
    if (didPop ||
        _saved ||
        _move != _Move.none ||
        ref.read(addressFormControllerProvider).isBusy) {
      return;
    }
    if (_isNew && _step == _Step.point && !_backToDetails) {
      unawaited(_askToLeave());
    } else if (_isNew && _step == _Step.details) {
      _growBack(toDetailsAfter: false);
    } else {
      setState(() {
        _step = _Step.details;
        _backToDetails = false;
      });
    }
  }

  /// The preview grows back into the map; [toDetailsAfter] tells that back
  /// from that map returns to the details.
  void _growBack({required bool toDetailsAfter}) {
    FocusManager.instance.primaryFocus?.unfocus();
    // The preview is the list's first row: it grows from where it can be
    // seen, not from partly out of sight.
    if (_scroll.hasClients && _scroll.offset > 0) {
      _scroll.jumpTo(0);
    }
    _run(_Move.toMap, () => _backToDetails = toDetailsAfter);
  }

  /// The preview was tapped: a new address grows it back into the map, an
  /// edit swaps to the map.
  void _changePoint() {
    if (_saved ||
        _move != _Move.none ||
        ref.read(addressFormControllerProvider).isBusy) {
      return;
    }
    if (_isNew) {
      _growBack(toDetailsAfter: true);
    } else {
      setState(() => _step = _Step.point);
    }
  }

  Future<void> _askToLeave() async {
    if (_leaving) {
      return;
    }
    _leaving = true;
    final String street = _street.text.trim();
    final bool leave = await showAddressLeaveSheet(
      context,
      name: street.isNotEmpty
          ? street
          : _typedWords.isNotEmpty
          ? _typedWords
          : null,
    );
    _leaving = false;
    if (!mounted || !leave) {
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppPaths.customerAddresses);
    }
  }

  Future<void> _submit() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> gaps = <String>[
      for (final String key in _order)
        if ((key != 'label' || _kind == AddressLabelKind.custom) &&
            _problem(key, l10n) != null)
          key,
    ];
    if (gaps.isNotEmpty) {
      setState(() => _marked.addAll(gaps));
      unawaited(_showGap(gaps.first, l10n));
      return;
    }
    final Address? address = widget.address;
    final AddressDraft draft = AddressDraft(
      label: _labelValue(l10n),
      point: _point,
      street: _street.text.trim(),
      house: _house.text.trim(),
      apartment: _optional(_apartment.text),
      landmark: _optional(_landmark.text),
      deliveryNote: _optional(_note.text),
    );
    // An edit that changes nothing sends nothing and says so (`DL-27` (3)).
    if (address != null && draft.sameAs(address)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.noChanges)));
      return;
    }
    setState(() => _sentPoint = _point);

    final Address? saved = await ref
        .read(addressFormControllerProvider.notifier)
        .save(address, draft);
    // The Customer may have signed out while the save ran; where they went
    // stays on screen.
    if (!mounted || saved == null) {
      return;
    }
    // The check shows for a moment before the screen closes (`DL-138`).
    setState(() => _saved = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) {
      return;
    }
    // The bar names the address and takes the place of any bar showing, so
    // the name is seen at once (`DL-137`).
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            address == null
                ? l10n.addressAdded(saved.name)
                : l10n.addressSavedNamed(saved.name),
          ),
        ),
      );
    if (context.canPop()) {
      // Whoever asked for the form gets the saved address back: a new one
      // becomes the delivery address (`DL-75`), a saved one glows in the
      // list (`DL-137`).
      context.pop<Address>(saved);
    } else {
      context.go(AppPaths.customerAddresses);
    }
  }

  /// A save found a gap: the list brings the first one in view, then focus
  /// and a shake point at it; a warning tap and a spoken line say the same
  /// (`DL-138`).
  Future<void> _showGap(String key, AppLocalizations l10n) async {
    final String label = _labelText(key, l10n);
    unawaited(HapticFeedback.warningNotification());
    announce(
      context,
      key == 'street' || key == 'house'
          ? l10n.addressFieldMissingSpoken(label)
          : _problem(key, l10n) ?? l10n.addressFieldMissingSpoken(label),
    );
    final bool still = MediaQuery.disableAnimationsOf(context);
    // The error lines lengthen the list: measure once they are laid out.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      return;
    }
    final RenderObject? box = await _builtLabel(key);
    if (!mounted) {
      return;
    }
    if (_scroll.hasClients) {
      final RenderAbstractViewport? viewport = box == null
          ? null
          : RenderAbstractViewport.maybeOf(box);
      final double target = viewport == null
          ? _scroll.position.maxScrollExtent
          : viewport.getOffsetToReveal(box!, 0).offset - 12;
      final double offset = target.clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      if (still) {
        _scroll.jumpTo(offset);
      } else {
        await _scroll.animateTo(
          offset,
          duration: const Duration(milliseconds: 300),
          curve: const Cubic(0.2, 0.8, 0.2, 1),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    }
    if (!mounted) {
      return;
    }
    _focus[key]!.requestFocus();
    setState(() => _shakes[key] = (_shakes[key] ?? 0) + 1);
  }

  /// The label of [key] once its row is built. The list builds only the rows
  /// in view, so a row far above or below is not there: the list jumps toward
  /// it (where its place in the form says it lies, then to either end) and
  /// waits for the frame, until the row exists (`DL-138`).
  Future<RenderObject?> _builtLabel(String key) async {
    RenderObject? built() =>
        _labelKeys[key]!.currentContext?.findRenderObject();
    if (built() != null || !_scroll.hasClients) {
      return built();
    }
    final ScrollPosition position = _scroll.position;
    final int at = _order.indexOf(key);
    final double share = _order.length < 2 ? 0 : at / (_order.length - 1);
    for (final double guess in <double>[
      position.minScrollExtent +
          (position.maxScrollExtent - position.minScrollExtent) * share,
      position.minScrollExtent,
      position.maxScrollExtent,
    ]) {
      _scroll.jumpTo(guess);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return null;
      }
      if (built() != null) {
        return built();
      }
    }
    return null;
  }

  /// The label a field carries over it, without "необязательно".
  String _labelText(String key, AppLocalizations l10n) => switch (key) {
    'street' => l10n.addressFieldStreet,
    'house' => l10n.addressHouse,
    'apartment' => l10n.addressFieldApartment,
    'landmark' => l10n.addressLandmark,
    'delivery_note' => l10n.addressFieldNote,
    _ => l10n.addressLabelName,
  };

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = ref.watch(addressFormControllerProvider);
    final bool onPoint = _step == _Step.point;
    final String title = onPoint && !_isNew
        ? l10n.addressPointTitle
        : _isNew
        ? l10n.addressNew
        : l10n.addressEdit;
    final double barHeight = kitSubtitleBarHeight(
      MediaQuery.textScalerOf(context),
    );

    return PopScope(
      canPop:
          !change.isBusy &&
          !_saved &&
          _move == _Move.none &&
          (_isNew ? onPoint && !_backToDetails && !_entered : !onPoint),
      onPopInvokedWithResult: (bool didPop, Object? _) => _back(didPop),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _isNew
            ? kitAppBar(
                title: title,
                subtitle: onPoint
                    ? l10n.addressStepPoint
                    : l10n.addressStepDetails,
                spokenTitle: onPoint
                    ? l10n.addressStepPointSpoken
                    : l10n.addressStepDetailsSpoken,
                toolbarHeight: barHeight,
              )
            : kitAppBar(title: title),
        body: UnderActiveMode(
          child: onPoint ? _pointStep() : _details(l10n, change),
        ),
      ),
    );
  }

  /// The map step; with reduced motion it fades in after the details fade out.
  Widget _pointStep() {
    return AnimatedBuilder(
      animation: _morph,
      builder: (BuildContext context, Widget? step) => Opacity(
        key: const ValueKey<String>('address-map-fade'),
        opacity: _move == _Move.mapIn
            ? Curves.easeOut.transform(_morph.value)
            : 1,
        child: step,
      ),
      child: AddressPointStep(
        key: const ValueKey<String>('address-point-step'),
        initial: _point,
        placed: !_isNew || _pointConfirmed,
        openedAt: _isNew && !_pointConfirmed ? _delivery : null,
        place: _pointConfirmed ? _place : null,
        keepsWords: _streetTakesWords,
        onConfirmed: _confirmed,
        onTyped: (bool typed) => setState(() => _typed = typed),
        onWords: (String words) => _typedWords = words,
        panelRises: _rise,
      ),
    );
  }

  Widget _details(AppLocalizations l10n, MutationState change) {
    return AnimatedBuilder(
      animation: _morph,
      builder: (BuildContext context, Widget? _) =>
          _detailsAt(l10n, change, _look()),
    );
  }

  /// How far each part of the details has come in the running morph: the
  /// preview's shrink, the fields' arrival, the footer's offset (a fraction
  /// of its height) and, with reduced motion, the whole face's opacity.
  ({double preview, double fields, double footer, double whole}) _look() {
    const Cubic out = Cubic(0.2, 0.8, 0.2, 1);
    final double t = _morph.value;
    final bool still = MediaQuery.disableAnimationsOf(context);
    switch (_move) {
      case _Move.toDetails when still:
        return (
          preview: 1,
          fields: 1,
          footer: 0,
          whole: Curves.easeOut.transform(t),
        );
      case _Move.toDetails:
        return (
          preview: const Interval(0, 350 / 400, curve: out).transform(t),
          fields: const Interval(80 / 400, 1, curve: out).transform(t),
          footer:
              1 - const Interval(60 / 400, 360 / 400, curve: out).transform(t),
          whole: 1,
        );
      case _Move.toMap when still:
        return (
          preview: 1,
          fields: 1,
          footer: 0,
          whole: 1 - Curves.easeIn.transform(t),
        );
      case _Move.toMap:
        return (
          preview: 1 - const Cubic(0.4, 0, 0.2, 1).transform(t),
          fields: 1 - const Interval(0, 0.5, curve: Curves.easeIn).transform(t),
          footer: const Interval(
            0,
            260 / 320,
            curve: Curves.easeIn,
          ).transform(t),
          whole: 1,
        );
      case _Move.none || _Move.mapIn:
        return (preview: 1, fields: 1, footer: 0, whole: 1);
    }
  }

  Widget _detailsAt(
    AppLocalizations l10n,
    MutationState change,
    ({double preview, double fields, double footer, double whole}) look,
  ) {
    final bool custom = _kind == AddressLabelKind.custom;
    final bool locked = change.isBusy || _saved;
    // At large text the house and the apartment each take the width.
    final bool stacked =
        textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3;
    Widget house(_FieldPart part) => _field(
      'house',
      l10n.addressHouse,
      locked: locked,
      required: true,
      action: TextInputAction.next,
      part: part,
    );
    Widget apartment(_FieldPart part) => _field(
      'apartment',
      l10n.addressFieldApartment,
      locked: locked,
      action: TextInputAction.next,
      part: part,
    );
    final Widget houseLabel = house(_FieldPart.label);
    final Widget houseInput = house(_FieldPart.input);
    final Widget apartmentLabel = apartment(_FieldPart.label);
    final Widget apartmentInput = apartment(_FieldPart.input);
    final PointAddress? place = _place;
    // Each row below the preview arrives on its own, so the list still builds
    // only the rows in view.
    Widget fade(Widget row) => Opacity(
      opacity: look.fields,
      child: Transform.translate(
        offset: Offset(0, 48 * (1 - look.fields)),
        child: row,
      ),
    );
    return IgnorePointer(
      ignoring: _move != _Move.none,
      child: Opacity(
        key: const ValueKey<String>('address-details-fade'),
        opacity: look.whole,
        child: Form(
          child: Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  key: const ValueKey<String>('address-form'),
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    _preview(l10n, change, look.preview),
                    ...<Widget>[
                      if (place != null) _placeLine(place),
                      const SizedBox(height: 16),
                      _field(
                        'street',
                        l10n.addressFieldStreet,
                        locked: locked,
                        required: true,
                        action: TextInputAction.next,
                      ),
                      if (stacked) ...<Widget>[
                        house(_FieldPart.whole),
                        apartment(_FieldPart.whole),
                      ] else ...<Widget>[
                        // The labels stand in their own row, bottom-aligned,
                        // so the inputs below stay level whatever a label
                        // wraps to or the house error line adds.
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: <Widget>[
                              Expanded(child: houseLabel),
                              const SizedBox(width: 12),
                              Expanded(child: apartmentLabel),
                            ],
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: houseInput),
                            const SizedBox(width: 12),
                            Expanded(child: apartmentInput),
                          ],
                        ),
                      ],
                      _field(
                        'landmark',
                        l10n.addressLandmark,
                        locked: locked,
                        hint: l10n.addressLandmarkHint,
                        action: TextInputAction.next,
                      ),
                      _field(
                        'delivery_note',
                        l10n.addressFieldNote,
                        locked: locked,
                        hint: l10n.addressNoteHint,
                        maxLines: 3,
                        counter: true,
                      ),
                      Text(
                        l10n.addressLabelTitle,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: KitColors.muted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      AddressLabelChips(
                        kind: _kind ?? AddressLabelKind.none,
                        enabled: !locked,
                        onChanged: (AddressLabelKind kind) =>
                            setState(() => _kind = kind),
                      ),
                      if (custom) ...<Widget>[
                        const SizedBox(height: 14),
                        _field(
                          'label',
                          l10n.addressLabelName,
                          locked: locked,
                          action: TextInputAction.done,
                        ),
                      ],
                    ].map(fade),
                  ],
                ),
              ),
              ClipRect(
                child: FractionalTranslation(
                  translation: Offset(0, look.footer),
                  child: _footer(l10n, change),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The address the map named under the point, under the preview.
  Widget _placeLine(PointAddress place) {
    return Padding(
      key: const ValueKey<String>('address-preview-place'),
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.location_on, size: 18, color: KitColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              AppLocalizations.of(context).addressPinLine(place.line),
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: KitColors.ink2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// What the preview keeps free at its left for the map's own Google logo,
  /// which must stay visible: the pill wraps upward instead (`DL-86` (2),
  /// `DL-138`).
  static const double _logoClear = 90;

  /// The preview's height when the pill is one line.
  static const double _previewHeight = 118;

  /// The still map of the point as one button, with the pill "Изменить
  /// точку" over its corner. [grown] is how far the map has shrunk into it:
  /// 0 is the map's own height, edge to edge; 1 is the preview.
  Widget _preview(AppLocalizations l10n, MutationState change, double grown) {
    final AddressMap map = ref.watch(addressMapProvider);
    final PointAddress? place = _place;
    final bool idle = change.isBusy || _saved || _move != _Move.none;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) {
        final double pillWidth = math.max(0, box.maxWidth - 10 - _logoClear);
        final double rest = math.max(
          _previewHeight,
          _pillHeight(l10n, pillWidth) + 20,
        );
        final double height = _mapHeight > rest
            ? _mapHeight + (rest - _mapHeight) * grown
            : rest;
        return SizedBox(
          height: height,
          child: OverflowBox(
            minWidth: box.maxWidth + 32 * (1 - grown),
            maxWidth: box.maxWidth + 32 * (1 - grown),
            child: Transform.translate(
              offset: Offset(0, -16 * (1 - grown)),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16 * grown),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    IgnorePointer(child: map.preview(point: _point)),
                    Semantics(
                      container: true,
                      button: true,
                      excludeSemantics: true,
                      label: place == null
                          ? l10n.addressChangePointSpoken
                          : '${l10n.addressChangePointSpoken}. '
                                '${l10n.addressPinLine(place.line)}',
                      onTap: idle ? null : _changePoint,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: const ValueKey<String>('address-preview'),
                          onTap: idle ? null : _changePoint,
                          child: Stack(
                            children: <Widget>[
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: pillWidth,
                                  ),
                                  child: _pill(l10n, change.isBusy),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const TextStyle _pillText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// How tall the pill is when its text wraps in [width]: the preview is
  /// never lower than the pill and its margins, so a large text still leaves
  /// the logo corner free (`DL-138`).
  double _pillHeight(AppLocalizations l10n, double width) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: l10n.addressChangePoint,
        style:
            Theme.of(context).textTheme.bodyMedium?.merge(_pillText) ??
            _pillText,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: math.max(0, width - 28 - 20 - 6));
    final double height = painter.height;
    painter.dispose();
    return math.max(44, height.ceilToDouble());
  }

  /// The pill the preview carries: white, 44 high at least.
  Widget _pill(AppLocalizations l10n, bool busy) {
    return Container(
      key: const ValueKey<String>('address-change-point'),
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.edit_location_alt_outlined,
            size: 20,
            color: busy ? KitColors.muted : KitColors.primary,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              l10n.addressChangePoint,
              style: _pillText.copyWith(
                color: busy ? KitColors.muted : KitColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A field of the kit: the label above, a soft fill, radius 14.
  ///
  /// An optional field says so in its label; a reader hears the label as one
  /// line with the field, not apart from it. While [locked] the field keeps
  /// its look but takes no input (`DL-138`).
  Widget _field(
    String key,
    String label, {
    required bool locked,
    bool required = false,
    int maxLines = 1,
    String? hint,
    bool counter = false,
    TextInputAction? action,
    _FieldPart part = _FieldPart.whole,
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller = _controller(key);
    final int max = _maxOf(key);
    final int at = _order.indexOf(key);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    final bool withLabel = part != _FieldPart.input;
    final bool withInput = part != _FieldPart.label;
    final Widget labelText = ExcludeSemantics(
      key: ValueKey<String>('label-of-$key'),
      child: Text(
        key: _labelKeys[key],
        required ? label : l10n.addressOptional(label),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: KitColors.muted,
        ),
      ),
    );
    if (!withInput) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Shake(trigger: _shakes[key] ?? 0, child: labelText),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Shake(
        trigger: _shakes[key] ?? 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (withLabel) ...<Widget>[labelText, const SizedBox(height: 6)],
            Semantics(
              label: required
                  ? l10n.fieldRequiredSpoken(label)
                  : l10n.fieldOptionalSpoken(label),
              child: TextFormField(
                key: ValueKey<String>('field-$key'),
                controller: controller,
                focusNode: _focus[key],
                readOnly: locked,
                textInputAction: action,
                onEditingComplete: action == TextInputAction.next
                    ? () => _focus[_order[at + 1]]!.requestFocus()
                    : null,
                autovalidateMode: _marked.contains(key)
                    ? AutovalidateMode.always
                    : AutovalidateMode.disabled,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 14, color: KitColors.ink),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(
                    fontSize: 14,
                    color: KitColors.muted,
                  ),
                  filled: true,
                  fillColor: KitColors.field,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 16,
                  ),
                  border: border(KitColors.line),
                  enabledBorder: border(KitColors.line),
                  disabledBorder: border(KitColors.line),
                  focusedBorder: border(KitColors.primary),
                  errorBorder: border(KitColors.danger),
                  focusedErrorBorder: border(KitColors.danger),
                  errorStyle: const TextStyle(
                    fontSize: 12,
                    color: KitColors.danger,
                  ),
                ),
                validator: (String? _) => _problem(key, l10n),
              ),
            ),
            if (counter)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder:
                        (BuildContext _, TextEditingValue value, Widget? _) =>
                            Text(
                              '${value.text.runes.length} / $max',
                              key: ValueKey<String>('counter-$key'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: KitColors.muted,
                              ),
                            ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The bar under the form (the cart's footer look): a refusal above the
  /// save button.
  Widget _footer(AppLocalizations l10n, MutationState change) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: _SaveFailure(
                    change.failure,
                    samePoint: _point == _sentPoint,
                  ),
                ),
              ),
              FilledButton(
                key: const ValueKey<String>('address-save'),
                // Saving and saved keep the green: a grey button would read
                // as a failure (`DL-138`).
                onPressed: change.isBusy || _saved ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: KitColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: KitColors.primary,
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (change.isBusy)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    else if (_saved)
                      const Icon(Icons.check, size: 20),
                    if (change.isBusy || _saved) const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        change.isBusy
                            ? l10n.addressSaving
                            : _saved
                            ? l10n.addressSavedButton
                            : l10n.addressSaveButton,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A refused save: outside the service area it says how far and how far is
/// served, from the answer's `details` — while the pin is still where it
/// was refused; anything else as its code says.
class _SaveFailure extends StatelessWidget {
  const _SaveFailure(this.failure, {required this.samePoint});

  final ApiFailure? failure;
  final bool samePoint;

  /// Two decimals, as `details` carries them (`docs/09` section 13).
  static final RegExp _kilometres = RegExp(r'^\d+\.\d{2}$');

  @override
  Widget build(BuildContext context) {
    final ApiFailure? failure = this.failure;
    if (failure is ApiRefusal &&
        failure.code == 'address_outside_service_area') {
      if (!samePoint) {
        return const SizedBox.shrink();
      }
      final AppLocalizations l10n = AppLocalizations.of(context);
      final Object? distance = failure.error.details['distance_km'];
      final Object? max = failure.error.details['max_distance_km'];
      // Kilometres with the decimal comma of both languages; without
      // readable numbers the refusal is said without them.
      final String text =
          distance is String &&
              max is String &&
              _kilometres.hasMatch(distance) &&
              _kilometres.hasMatch(max)
          ? l10n.addressOutsideArea(
              distance.replaceAll('.', ','),
              max.replaceAll('.', ','),
            )
          : l10n.addressOutsideAreaPlain;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          key: const ValueKey<String>('address-outside-area'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    return FailureMessage(failure);
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.failure, required this.onRetry});

  final ApiFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FailureMessage(failure),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retryButton),
            ),
          ],
        ),
      ),
    );
  }
}
