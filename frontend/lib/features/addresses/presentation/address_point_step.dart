import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/accessibility/announce.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/addresses_controllers.dart';
import '../data/device_location.dart';
import '../domain/address_search.dart';
import '../domain/addresses.dart';
import 'address_point_parts.dart';
import 'map/address_map.dart';
import 'map/map_pin.dart';

/// What the map step hands on: the point the Customer confirmed, the address
/// as they typed it, when they did (`DL-84` (2), `DL-86` (3)), the address
/// the map named under the pin when it did, and the height of the map area
/// the details morph from (`DL-138`).
final class AddressPointResult {
  const AddressPointResult({
    required this.point,
    required this.words,
    required this.mapHeight,
    this.place,
  });

  final GeoPoint point;
  final String? words;
  final PointAddress? place;
  final double mapHeight;
}

/// The map step of a new address (drawings 22, 22б): the pin in the centre,
/// the address typed in words above the map, "где я", and the confirm
/// button. It fills the screen body; the host gives the app bar. A new address
/// opens not [placed]: the confirm button waits until the Customer, a search,
/// "где я" or the location already allowed puts the pin down; [openedAt] is
/// the address the map opened at when that is why it is there (`DL-138`).
class AddressPointStep extends ConsumerStatefulWidget {
  const AddressPointStep({
    required this.initial,
    required this.placed,
    required this.keepsWords,
    required this.onConfirmed,
    this.openedAt,
    this.place,
    this.onTyped,
    this.onWords,
    this.panelRises = false,
    super.key,
  });

  final GeoPoint initial;
  final bool placed;
  final Address? openedAt;

  /// The address the map already named at [initial], when the host holds it:
  /// the map reopened from the details does not ask for it again.
  final PointAddress? place;

  /// Whether the host will put the typed words into the street; the step
  /// promises to keep them only then.
  final bool keepsWords;
  final ValueChanged<AddressPointResult> onConfirmed;

  /// Tells whether the search field holds words, typed or sent, so the host
  /// knows when leaving would lose something (`DL-138`).
  final ValueChanged<bool>? onTyped;

  /// The words the search field holds, whenever they change.
  final ValueChanged<String>? onWords;

  /// The step is reached by the preview growing back into the map: the panel
  /// slides up from below on its first frame.
  final bool panelRises;

  @override
  ConsumerState<AddressPointStep> createState() => _AddressPointStepState();
}

enum _Search { start, found, notFound, unavailable }

class _AddressPointStepState extends ConsumerState<AddressPointStep>
    with SingleTickerProviderStateMixin {
  static const int _shortest = 3;
  static const int _searchMax = 200;

  /// The wait after the pin came to rest before the address is asked for.
  static const Duration _lookupWait = Duration(milliseconds: 400);

  /// How long lookups wait after a `429` that named no time.
  static const Duration _pauseDefault = Duration(seconds: 60);

  /// How long a lifted finger still owns the next camera start.
  static const Duration _touchGrace = Duration(milliseconds: 600);

  /// A rest this near the last looked-up point asks nothing again.
  static const double _reuseMetres = 15;

  final PointMapMover _mover = PointMapMover();
  final TextEditingController _field = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final GlobalKey _mapArea = GlobalKey();

  /// The map area's height the last time no keyboard was up; the morph to the
  /// details starts from it, since the keyboard closes with the confirm.
  double? _calmHeight;

  late GeoPoint _point = widget.initial;
  late bool _placed = widget.placed;
  String? _words;
  _Search _search = _Search.start;
  bool _searching = false;
  bool _locating = false;

  /// The Customer's finger is on the map and it has not come to rest.
  bool _moving = false;

  /// Counts the pin's drops; the pin plays one for each.
  int _drops = 0;

  /// The hint under the search field fades after the first move.
  bool _hintGone = false;

  /// The latest search sent; an older answer is not heard.
  int _searchId = 0;

  /// Counts the answers the search gave; the answer comes in anew for each.
  int _answers = 0;

  /// Counts the Customer's touches on the map; an answer sent before the
  /// latest touch is not heard. The map's own camera reports are not touches:
  /// Android sends them too when its permission windows cover the screen.
  int _touches = 0;

  /// A finger is on the map, or lifted a moment ago: only then is a camera
  /// start the Customer's. Android's SDK also reports camera moves when the
  /// keyboard resizes the map or a window covers it (`DL-86` (7)); those have
  /// no finger behind them (`DL-138`).
  bool _touching = false;
  Timer? _touchEnd;

  /// Counts what takes the pin out of the silent fix's hands: a touch, a
  /// search, "где я".
  int _intent = 0;

  Timer? _lookupTimer;

  /// The panel's rise when [AddressPointStep.panelRises]; started once the
  /// motion setting is known.
  AnimationController? _rise;
  CurvedAnimation? _riseCurve;

  /// The latest lookup scheduled; an older answer is not heard.
  int _lookupId = 0;

  /// The resting pin's address is waited for or on its way.
  bool _lookupPending = false;

  /// The point the last answer was for, `null` when there is none in hand
  /// (never asked, or the last ask failed).
  GeoPoint? _placeAt;

  /// The last answer: what the map names there, `null` when it names nothing.
  PointAddress? _place;

  /// Lookups wait until a `429` has run out; the Customer's pin still moves
  /// and confirms.
  bool _lookupsPaused = false;
  Timer? _pauseTimer;

  @override
  void initState() {
    super.initState();
    if (widget.place != null) {
      _placeAt = widget.initial;
      _place = widget.place;
    }
    if (ref.read(addressMapProvider).movable) {
      if (widget.placed) {
        _scheduleLookup();
      } else {
        _fixSilently();
      }
    }
  }

  /// The map opens where the phone is when the location is already allowed;
  /// nothing is asked. It moves nothing the Customer has already acted on.
  Future<void> _fixSilently() async {
    final int intent = _intent;
    final GeoPoint? here = await ref
        .read(deviceLocationProvider)
        .currentIfAllowed();
    if (!mounted || here == null || intent != _intent) {
      return;
    }
    setState(() => _moveTo(here));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.panelRises &&
        _rise == null &&
        !MediaQuery.disableAnimationsOf(context)) {
      _rise = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      )..forward();
      _riseCurve = CurvedAnimation(
        parent: _rise!,
        curve: const Cubic(0.2, 0.8, 0.2, 1),
      );
    }
  }

  @override
  void dispose() {
    _riseCurve?.dispose();
    _rise?.dispose();
    _lookupTimer?.cancel();
    _touchEnd?.cancel();
    _pauseTimer?.cancel();
    _mover.dispose();
    _field.dispose();
    super.dispose();
  }

  /// The Customer put a finger to move the map: the pin lifts and the old
  /// address is no longer the pin's.
  void _moveStarted() {
    if (!_touching) {
      return;
    }
    _intent++;
    _lookupTimer?.cancel();
    _lookupId++;
    setState(() {
      _moving = true;
      _hintGone = true;
      _lookupPending = false;
    });
  }

  /// The finger left the map; its camera start may still be on the way from
  /// the platform, so the touch counts for a moment longer.
  void _fingerLifted() {
    _touchEnd?.cancel();
    _touchEnd = Timer(_touchGrace, () => _touching = false);
  }

  /// The map came to rest at [point]. After the Customer's own move the pin
  /// drops with a light tap and is placed; any other report only follows the
  /// camera.
  void _moved(GeoPoint point) {
    final bool own = _moving;
    setState(() {
      _point = point;
      if (own) {
        _moving = false;
        _placed = true;
        _drops++;
        _scheduleLookup();
      }
    });
    if (own) {
      HapticFeedback.lightImpact();
      _announceRest(null);
    }
  }

  /// An answer moves the map and places the pin. It also ends a lift the
  /// Customer's glide began: the app's move interrupts the glide, so no rest
  /// of theirs would follow.
  void _moveTo(GeoPoint point) {
    _point = point;
    _placed = true;
    _moving = false;
    _mover.moveTo(point);
    _scheduleLookup();
  }

  /// The pin came to rest on a movable map: asks what is under it 400 ms
  /// later, unless that is within 15 m of the point already answered.
  void _scheduleLookup() {
    _lookupTimer?.cancel();
    final int id = ++_lookupId;
    final GeoPoint? at = _placeAt;
    if (at != null && greatCircleKm(at, _point) * 1000 <= _reuseMetres) {
      _lookupPending = false;
      return;
    }
    if (_lookupsPaused) {
      _lookupPending = false;
      return;
    }
    _lookupPending = true;
    final GeoPoint point = _point;
    _lookupTimer = Timer(_lookupWait, () => _lookUp(id, point));
  }

  Future<void> _lookUp(int id, GeoPoint point) async {
    final String language = Localizations.localeOf(context).languageCode;
    PointAddress? answer;
    bool failed = false;
    try {
      answer = await ref
          .read(addressSearchRepositoryProvider)
          .addressAt(point, language: language);
    } on ApiFailure catch (failure) {
      failed = true;
      if (failure is ApiRefusal && failure.error.status == 429) {
        _pauseLookups(failure.retryAfterSeconds);
      }
    }
    if (!mounted || id != _lookupId) {
      return;
    }
    setState(() {
      _lookupPending = false;
      _placeAt = failed ? null : point;
      _place = failed ? null : answer;
    });
  }

  /// A `429` was answered: no lookup goes out until its `Retry-After` (a
  /// minute when it named none) has passed, then the resting pin is asked
  /// for once (`DL-138`).
  void _pauseLookups(int? seconds) {
    _lookupsPaused = true;
    _pauseTimer?.cancel();
    _pauseTimer = Timer(
      seconds == null || seconds <= 0
          ? _pauseDefault
          : Duration(seconds: seconds),
      () {
        _lookupsPaused = false;
        if (mounted && _placed && !_moving && _placeAt == null) {
          setState(_scheduleLookup);
        }
      },
    );
  }

  /// The address under the resting pin, when the map has answered for it.
  bool get _answered => _placeAt != null && !_lookupPending && !_moving;

  /// Whether the pin at rest is outside the delivery [zone]; with no zone,
  /// still loading or failed, nothing is outside.
  bool _isOutside(ServiceArea? zone, bool movable) =>
      movable && zone != null && _placed && !_moving && !zone.contains(_point);

  /// Says what a screen reader needs after the pin came to rest: [lead] when
  /// there is one, then that the pin is outside the zone.
  void _announceRest(String? lead) {
    final ServiceArea? zone = ref.read(serviceAreaProvider).value;
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> parts = <String>[
      ?lead,
      if (zone != null && !zone.contains(_point))
        l10n.addressOutsideZoneSpoken(
          zone.distanceLabel(_point),
          zone.radiusLabel,
        ),
    ];
    if (parts.isNotEmpty) {
      announce(context, parts.join('. '));
    }
  }

  Future<void> _submit(String text) async {
    final String query = text.trim();
    if (query.length < _shortest) {
      return;
    }
    final int id = ++_searchId;
    _intent++;
    final int touches = _touches;
    setState(() {
      _words = query;
      _searching = true;
    });
    GeoPoint? found;
    bool failed = false;
    try {
      found = await ref.read(addressSearchRepositoryProvider).locate(query);
    } on ApiFailure {
      failed = true;
    }
    if (!mounted || id != _searchId) {
      return;
    }
    final AppLocalizations l10n = AppLocalizations.of(context);
    bool moved = false;
    setState(() {
      _searching = false;
      if (touches != _touches) {
        return;
      }
      _answers++;
      _hintGone = true;
      if (failed) {
        _search = _Search.unavailable;
      } else if (found == null) {
        _search = _Search.notFound;
      } else {
        _search = _Search.found;
        _moveTo(found);
        moved = true;
      }
    });
    if (touches != _touches) {
      return;
    }
    if (moved) {
      _announceRest(l10n.addressFoundSpoken);
    } else {
      announce(
        context,
        failed ? l10n.addressSearchDown : l10n.addressSearchNotFoundAt(query),
      );
    }
  }

  void _clear() {
    _searchId++;
    _field.clear();
    setState(() {
      _words = null;
      _search = _Search.start;
      _searching = false;
    });
    _reportWords();
  }

  void _reportWords() {
    widget.onTyped?.call(_field.text.trim().isNotEmpty);
    widget.onWords?.call(_field.text.trim());
  }

  Future<void> _whereAmI() async {
    _intent++;
    final int touches = _touches;
    setState(() => _locating = true);
    final LocationOutcome outcome = await ref
        .read(deviceLocationProvider)
        .current();
    if (!mounted) {
      return;
    }
    setState(() => _locating = false);
    switch (outcome) {
      case LocationFound(point: final GeoPoint here):
        if (touches == _touches) {
          setState(() => _moveTo(here));
          _announceRest(AppLocalizations.of(context).addressLocatedSpoken);
        }
      case LocationFailed(reason: final LocationFailure why):
        _locationFailed(why);
    }
  }

  /// The snack bar outlives the step in the root messenger: its action asks
  /// again only while the step is there.
  void _askAgain() {
    if (mounted) {
      unawaited(_whereAmI());
    }
  }

  /// Says why the location failed, with the way out when there is one
  /// (`DL-138`).
  void _locationFailed(LocationFailure why) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final DeviceLocation device = ref.read(deviceLocationProvider);
    final (String, String?, VoidCallback?) face = switch (why) {
      LocationFailure.deniedForever => (
        l10n.addressLocationDenied,
        l10n.addressLocationSettings,
        device.openAppSettings,
      ),
      LocationFailure.serviceOff => (
        l10n.addressLocationOff,
        l10n.addressLocationTurnOn,
        device.openLocationSettings,
      ),
      LocationFailure.timedOut => (
        l10n.addressLocationSlow,
        l10n.addressLocationAgain,
        _askAgain,
      ),
      LocationFailure.denied ||
      LocationFailure.failed => (l10n.addressLocationFailed, null, null),
    };
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: Text(face.$1),
          action: face.$2 == null
              ? null
              : SnackBarAction(label: face.$2!, onPressed: face.$3!),
        ),
      );
  }

  /// Whether the pin is put down: a map without movement takes typed fields
  /// and counts as placed.
  bool _isPlaced(bool movable) => _placed || !movable;

  void _confirm(bool movable, ServiceArea? zone) {
    if (!_isPlaced(movable) ||
        _isOutside(zone, movable) ||
        _moving ||
        _locating) {
      return;
    }
    if (!movable && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    widget.onConfirmed(
      AddressPointResult(
        point: _point,
        words: _words,
        mapHeight: _mapHeight(),
        place: movable && _answered ? _place : null,
      ),
    );
  }

  /// The keyboard's height; the host's scaffold hides it from the step's
  /// own media query.
  double _keyboard() {
    final FlutterView view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

  /// The map area's height without a keyboard: the one measured while none
  /// was up, else the one in view plus the keyboard's height.
  double _mapHeight() {
    final double shown = _mapArea.currentContext?.size?.height ?? 0;
    final double keyboard = _keyboard();
    return keyboard > 0 ? _calmHeight ?? shown + keyboard : shown;
  }

  @override
  Widget build(BuildContext context) {
    if (_keyboard() == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final double? height = _mapArea.currentContext?.size?.height;
        if (mounted && height != null && height > 0) {
          _calmHeight = height;
        }
      });
    }
    final AddressMap map = ref.watch(addressMapProvider);
    final ServiceArea? zone = map.movable
        ? ref.watch(serviceAreaProvider).value
        : null;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            key: _mapArea,
            child: map.movable ? _movableMap(map, zone) : _fields(map),
          ),
          _rising(
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
              child: _panel(map.movable, zone),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rising(Widget panel) {
    final CurvedAnimation? curve = _riseCurve;
    return curve == null
        ? panel
        : SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(curve),
            child: panel,
          );
  }

  Widget _fields(AddressMap map) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Form(
      key: _form,
      child: map.picker(
        initial: widget.initial,
        mover: _mover,
        enabled: true,
        onMoveStarted: _moveStarted,
        onMoved: _moved,
      ),
    ),
  );

  /// What a reader hears of the map: where the pin is, the address under it
  /// when the map named one, and how to place it without the map.
  String _mapSpoken(AppLocalizations l10n) {
    final PointAddress? place = _answered ? _place : null;
    return <String>[
      l10n.addressMapSpoken,
      if (place != null) l10n.addressMapPinSpoken(place.line),
      l10n.addressMapWaySpoken,
    ].join(' ');
  }

  Widget _movableMap(AddressMap map, ServiceArea? zone) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool hint = !_largeText;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Semantics(
          key: const ValueKey<String>('address-point-map'),
          container: true,
          excludeSemantics: true,
          label: _mapSpoken(l10n),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  _touches++;
                  _intent++;
                  _touchEnd?.cancel();
                  _touching = true;
                },
                onPointerUp: (_) => _fingerLifted(),
                onPointerCancel: (_) => _fingerLifted(),
                child: map.picker(
                  initial: widget.initial,
                  mover: _mover,
                  enabled: true,
                  onMoveStarted: _moveStarted,
                  onMoved: _moved,
                  zone: zone,
                ),
              ),
              Positioned.fill(
                child: MapPin(lifted: _moving, drops: _drops),
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _searchField(l10n),
              if (_search != _Search.start) ...<Widget>[
                const SizedBox(height: 8),
                SearchAnswer(
                  key: const ValueKey<String>('address-search-result'),
                  face: switch (_search) {
                    _Search.found => SearchFace.found,
                    _Search.notFound => SearchFace.notFound,
                    _ => SearchFace.unavailable,
                  },
                  query: _words ?? '',
                  serial: _answers,
                  // A found address fills the street itself: only a search
                  // that found nothing promises the words (`DL-138`).
                  keptLine:
                      _words != null &&
                          widget.keepsWords &&
                          _search != _Search.found
                      ? l10n.addressWordsKept
                      : null,
                ),
              ],
              if (hint) ...<Widget>[
                const SizedBox(height: 8),
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: AnimatedOpacity(
                      opacity: _hintGone ? 0 : 1,
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: _Hint(l10n.addressMapHint),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(right: 16, bottom: 16, child: _myLocation(l10n)),
      ],
    );
  }

  /// Large text has no room for a hint over the map; the panel says it
  /// (`DL-126`).
  bool get _largeText =>
      textScaleAt(MediaQuery.textScalerOf(context), 14) > 1.3;

  Widget _searchField(AppLocalizations l10n) {
    final bool canGo = _field.text.trim().length >= _shortest;
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(14),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Semantics(
          label: l10n.addressSearchSpoken,
          child: TextField(
            key: const ValueKey<String>('address-search-field'),
            controller: _field,
            textInputAction: TextInputAction.search,
            maxLength: _searchMax,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            onSubmitted: _submit,
            onChanged: (_) {
              setState(() {});
              _reportWords();
            },
            style: const TextStyle(fontSize: 14, color: KitColors.ink),
            decoration: InputDecoration(
              hintText: l10n.addressSearchHint,
              hintStyle: const TextStyle(fontSize: 14, color: KitColors.muted),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(Icons.search, size: 24, color: KitColors.muted),
              ),
              prefixIconConstraints: const BoxConstraints(),
              suffixIcon: _searching
                  ? const Padding(
                      key: ValueKey<String>('address-search-busy'),
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: KitColors.primary,
                        ),
                      ),
                    )
                  : _field.text.isEmpty
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (canGo)
                            _SuffixButton(
                              key: const ValueKey<String>('address-search-go'),
                              label: l10n.addressSearchGo,
                              fill: KitColors.primary,
                              icon: Icons.arrow_forward,
                              iconColor: Colors.white,
                              onTap: () => _submit(_field.text),
                            ),
                          _SuffixButton(
                            key: const ValueKey<String>('address-search-clear'),
                            label: l10n.addressSearchClear,
                            icon: Icons.close,
                            iconColor: KitColors.muted,
                            onTap: _clear,
                          ),
                        ],
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(),
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _myLocation(AppLocalizations l10n) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Material(
        color: KitColors.primary,
        shape: const CircleBorder(),
        elevation: 3,
        child: Semantics(
          button: true,
          excludeSemantics: true,
          label: l10n.addressMyLocationSpoken,
          onTap: _locating ? null : _whereAmI,
          child: Tooltip(
            message: l10n.addressMyLocation,
            child: InkWell(
              key: const ValueKey<String>('address-my-location'),
              customBorder: const CircleBorder(),
              onTap: _locating ? null : _whereAmI,
              child: Center(
                child: _locating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The address row of the panel: a bar while the map looks, the answer
  /// when it has one, nothing when the ask failed.
  Widget? _placeRow(AppLocalizations l10n, bool movable) {
    if (!movable || !_placed) {
      return null;
    }
    const Key key = ValueKey<String>('address-point-place');
    if (_moving || _lookupPending) {
      return const PlaceRow(key: key);
    }
    if (_placeAt == null) {
      return null;
    }
    final PointAddress? place = _place;
    if (place == null) {
      return PlaceRow(
        key: key,
        line: l10n.addressPlaceUnknown,
        sub: l10n.addressPlaceUnknownHint,
      );
    }
    return PlaceRow(
      key: key,
      line: place.line,
      sub: place.houseKnown ? null : l10n.addressPlaceNoHouse,
    );
  }

  Widget _panel(bool movable, ServiceArea? zone) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool placed = _isPlaced(movable);
    final bool outside = _isOutside(zone, movable);
    final Address? openedAt = widget.openedAt;
    final String text = movable && !placed && openedAt != null
        ? l10n.addressOpenedAt(openedAt.name)
        : movable && _largeText
        ? l10n.addressPointTextLarge
        : l10n.addressPointText;
    final Widget? place = _placeRow(l10n, movable);
    final String? why = !placed
        ? l10n.addressConfirmWhyMove
        : outside
        ? l10n.addressConfirmWhyZone
        : null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      if (place != null) ...<Widget>[
                        place,
                        const SizedBox(height: 8),
                      ],
                      Text(
                        text,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: KitColors.ink2,
                        ),
                      ),
                      if (outside && zone != null) ...<Widget>[
                        const SizedBox(height: 10),
                        ZoneNotice(
                          key: const ValueKey<String>('address-outside-zone'),
                          distance: zone.distanceLabel(_point),
                          radius: zone.radiusLabel,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (movable && !placed) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  l10n.addressMoveFirst,
                  key: const ValueKey<String>('address-move-first'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: KitColors.ink2,
                  ),
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 14),
              MergeSemantics(
                child: Semantics(
                  hint: why,
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      key: const ValueKey<String>('address-point-confirm'),
                      onPressed: placed && !outside
                          ? () => _confirm(movable, zone)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: KitColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: KitColors.line,
                        disabledForegroundColor: KitColors.muted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: Text(l10n.addressPointConfirm),
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
}

/// A 44 x 44 button inside the search field: the green arrow or the grey
/// cross.
class _SuffixButton extends StatelessWidget {
  const _SuffixButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.fill,
    super.key,
  });

  final String label;
  final IconData icon;
  final Color iconColor;
  final Color? fill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: fill ?? Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: onTap,
            child: Icon(icon, size: 24, color: iconColor),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xE6FFFFFF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          text,
          key: const ValueKey<String>('address-point-hint'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.4,
            color: KitColors.ink2,
          ),
        ),
      ),
    );
  }
}
