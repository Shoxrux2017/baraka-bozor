import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/layout/text_width.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/addresses_controllers.dart';
import '../data/device_location.dart';
import '../domain/address_search.dart';
import '../domain/addresses.dart';
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
    super.key,
  });

  final GeoPoint initial;
  final bool placed;
  final Address? openedAt;

  /// Whether the host will put the typed words into the street; the step
  /// promises to keep them only then.
  final bool keepsWords;
  final ValueChanged<AddressPointResult> onConfirmed;

  @override
  ConsumerState<AddressPointStep> createState() => _AddressPointStepState();
}

enum _Search { start, found, notFound, unavailable }

class _AddressPointStepState extends ConsumerState<AddressPointStep> {
  static const int _shortest = 3;
  static const int _searchMax = 200;

  final PointMapMover _mover = PointMapMover();
  final TextEditingController _field = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  final GlobalKey _mapArea = GlobalKey();

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

  /// Counts the Customer's touches on the map; an answer sent before the
  /// latest touch is not heard. The map's own camera reports are not touches:
  /// Android sends them too when its permission windows cover the screen.
  int _touches = 0;

  /// Counts what takes the pin out of the silent fix's hands: a touch, a
  /// search, "где я".
  int _intent = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.placed && ref.read(addressMapProvider).movable) {
      _fixSilently();
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
  void dispose() {
    _mover.dispose();
    _field.dispose();
    super.dispose();
  }

  /// The Customer put a finger to move the map: the pin lifts.
  void _moveStarted() {
    _intent++;
    setState(() {
      _moving = true;
      _hintGone = true;
    });
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
      }
    });
    if (own) {
      HapticFeedback.lightImpact();
    }
  }

  /// An answer moves the map and places the pin.
  void _moveTo(GeoPoint point) {
    _point = point;
    _placed = true;
    _mover.moveTo(point);
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
    setState(() {
      _searching = false;
      if (touches != _touches) {
        return;
      }
      if (failed) {
        _search = _Search.unavailable;
      } else if (found == null) {
        _search = _Search.notFound;
      } else {
        _search = _Search.found;
        _moveTo(found);
      }
    });
  }

  void _clear() {
    _searchId++;
    _field.clear();
    setState(() {
      _words = null;
      _search = _Search.start;
      _searching = false;
    });
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
    if (outcome case LocationFound(point: final GeoPoint here)) {
      if (touches == _touches) {
        setState(() => _moveTo(here));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).addressLocationFailed),
        ),
      );
    }
  }

  /// Whether the pin is put down: a map without movement takes typed fields
  /// and counts as placed.
  bool _isPlaced(bool movable) => _placed || !movable;

  void _confirm(bool movable) {
    if (!_isPlaced(movable) || _moving || _locating) {
      return;
    }
    if (!movable && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    widget.onConfirmed(
      AddressPointResult(
        point: _point,
        words: _words,
        mapHeight: _mapArea.currentContext?.size?.height ?? 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AddressMap map = ref.watch(addressMapProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            key: _mapArea,
            child: map.movable ? _movableMap(map) : _fields(map),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.5),
            child: _panel(map.movable),
          ),
        ],
      ),
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

  Widget _movableMap(AddressMap map) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            _touches++;
            _intent++;
          },
          child: map.picker(
            initial: widget.initial,
            mover: _mover,
            enabled: true,
            onMoveStarted: _moveStarted,
            onMoved: _moved,
          ),
        ),
        Positioned.fill(
          child: MapPin(lifted: _moving, drops: _drops),
        ),
        Positioned(left: 16, right: 16, top: 14, child: _searchField(l10n)),
        if (!_largeText)
          Positioned(
            left: 16,
            right: 16,
            top: 14 + 50 + 8,
            child: IgnorePointer(
              child: Align(
                alignment: Alignment.topLeft,
                child: AnimatedOpacity(
                  opacity: _hintGone ? 0 : 1,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 250),
                  curve: Curves.easeOut,
                  child: _Hint(
                    _search == _Search.found
                        ? l10n.addressSearchFound
                        : l10n.addressMapHint,
                  ),
                ),
              ),
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
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: const Color(0x33000000),
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        height: 50,
        child: TextField(
          key: const ValueKey<String>('address-search-field'),
          controller: _field,
          textInputAction: TextInputAction.search,
          maxLength: _searchMax,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          onSubmitted: _submit,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14, color: KitColors.ink),
          decoration: InputDecoration(
            hintText: l10n.addressSearchHint,
            hintStyle: const TextStyle(fontSize: 14, color: KitColors.muted),
            prefixIcon: const Icon(Icons.search, color: KitColors.muted),
            suffixIcon: _searching
                ? const Padding(
                    key: ValueKey<String>('address-search-busy'),
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: KitColors.primary,
                    ),
                  )
                : _field.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey<String>('address-search-clear'),
                    tooltip: l10n.addressSearchClear,
                    icon: const Icon(Icons.close, color: KitColors.muted),
                    onPressed: _clear,
                  ),
            counterText: '',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
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
    );
  }

  Widget _panel(bool movable) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool placed = _isPlaced(movable);
    final Address? openedAt = widget.openedAt;
    final String text = movable && !placed && openedAt != null
        ? l10n.addressOpenedAt(openedAt.name)
        : movable && _largeText
        ? l10n.addressPointTextLarge
        : l10n.addressPointText;
    final Widget? box = switch (_search) {
      _Search.notFound => _Notice(
        'address-search-not-found',
        Icons.travel_explore,
        l10n.addressSearchNotFound,
      ),
      _Search.unavailable => _Notice(
        'address-search-unavailable',
        Icons.cloud_off,
        l10n.addressSearchUnavailable,
      ),
      _ => null,
    };
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
                      box ??
                          Text(
                            text,
                            style: const TextStyle(
                              fontSize: 14,
                              color: KitColors.ink2,
                            ),
                          ),
                      if (_words != null && widget.keepsWords) ...<Widget>[
                        const SizedBox(height: 10),
                        Row(
                          key: const ValueKey<String>('address-words-kept'),
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: KitColors.primaryDark,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.addressWordsKept,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: KitColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
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
              SizedBox(
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>('address-point-confirm'),
                  onPressed: placed ? () => _confirm(movable) : null,
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
            ],
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
          style: const TextStyle(fontSize: 12, color: KitColors.ink2),
        ),
      ),
    );
  }
}

/// The drawing's amber box: the search could not place the address.
class _Notice extends StatelessWidget {
  const _Notice(this.keyName, this.icon, this.text);

  final String keyName;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>(keyName),
      decoration: BoxDecoration(
        color: KitColors.warningWash,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, size: 20, color: KitColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: KitColors.ink2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
