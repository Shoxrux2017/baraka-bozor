import 'dart:async';

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
import '../domain/addresses.dart';
import 'address_label_chips.dart';
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

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.address});

  final Address? address;

  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
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

  bool get _isNew => widget.address == null;

  @override
  void initState() {
    super.initState();
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
  /// fill the street where [_streetTakesWords] allows.
  void _confirmed(AddressPointResult result) {
    setState(() {
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
    });
  }

  /// Back walks the steps; nothing moves while a save runs.
  void _back(bool didPop) {
    if (didPop || _saved || ref.read(addressFormControllerProvider).isBusy) {
      return;
    }
    setState(() {
      _step = _isNew && !_backToDetails ? _Step.point : _Step.details;
      _backToDetails = false;
    });
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
    final RenderObject? box = _labelKeys[key]!.currentContext
        ?.findRenderObject();
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
          (_isNew ? onPoint && !_backToDetails : !onPoint),
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
          child: onPoint
              ? AddressPointStep(
                  key: const ValueKey<String>('address-point-step'),
                  initial: _point,
                  placed: !_isNew || _pointConfirmed,
                  openedAt: _isNew && !_pointConfirmed ? _delivery : null,
                  keepsWords: _streetTakesWords,
                  onConfirmed: _confirmed,
                )
              : _details(l10n, change),
        ),
      ),
    );
  }

  Widget _details(AppLocalizations l10n, MutationState change) {
    final bool custom = _kind == AddressLabelKind.custom;
    final bool locked = change.isBusy || _saved;
    // At large text the house and the apartment each take the width.
    final bool stacked =
        textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3;
    final Widget house = _field(
      'house',
      l10n.addressHouse,
      locked: locked,
      required: true,
      action: TextInputAction.next,
    );
    final Widget apartment = _field(
      'apartment',
      l10n.addressFieldApartment,
      locked: locked,
      action: TextInputAction.next,
    );
    return Form(
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              key: const ValueKey<String>('address-form'),
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _preview(l10n, change),
                const SizedBox(height: 16),
                _field(
                  'street',
                  l10n.addressFieldStreet,
                  locked: locked,
                  required: true,
                  action: TextInputAction.next,
                ),
                if (stacked) ...<Widget>[house, apartment] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: house),
                      const SizedBox(width: 12),
                      Expanded(child: apartment),
                    ],
                  ),
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
              ],
            ),
          ),
          _footer(l10n, change),
        ],
      ),
    );
  }

  /// The still map of the point with "Изменить точку" over its corner.
  Widget _preview(AppLocalizations l10n, MutationState change) {
    final AddressMap map = ref.watch(addressMapProvider);
    return SizedBox(
      height: 118,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) => Stack(
            fit: StackFit.expand,
            children: <Widget>[
              IgnorePointer(child: map.preview(point: _point)),
              Positioned(
                right: 10,
                bottom: 10,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: box.maxWidth * 0.6 - 11,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      shadowColor: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        key: const ValueKey<String>('address-change-point'),
                        borderRadius: BorderRadius.circular(10),
                        onTap: change.isBusy || _saved
                            ? null
                            : () => setState(() {
                                _backToDetails = _isNew;
                                _step = _Step.point;
                              }),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                Icons.edit_location_alt_outlined,
                                size: 16,
                                color: change.isBusy
                                    ? KitColors.muted
                                    : KitColors.primaryDark,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  l10n.addressChangePoint,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: change.isBusy
                                        ? KitColors.muted
                                        : KitColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
  }) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final TextEditingController controller = _controller(key);
    final int max = _maxOf(key);
    final int at = _order.indexOf(key);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Shake(
        trigger: _shakes[key] ?? 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ExcludeSemantics(
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
            ),
            const SizedBox(height: 6),
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
