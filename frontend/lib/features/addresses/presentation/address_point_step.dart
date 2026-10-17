import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../application/addresses_controllers.dart';
import '../data/device_location.dart';
import '../domain/addresses.dart';
import 'map/address_map.dart';

/// What the map step hands on: the point the Customer confirmed and the
/// address as they typed it, when they did (`DL-84` (2), `DL-86` (3)).
final class AddressPointResult {
  const AddressPointResult({required this.point, required this.words});

  final GeoPoint point;
  final String? words;
}

/// The map step of a new address (drawings 22, 22б): the pin in the centre,
/// the address typed in words above the map, "где я", and the confirm
/// button. It fills the screen body; the host gives the app bar.
class AddressPointStep extends ConsumerStatefulWidget {
  const AddressPointStep({
    required this.initial,
    required this.onConfirmed,
    super.key,
  });

  final GeoPoint initial;
  final ValueChanged<AddressPointResult> onConfirmed;

  @override
  ConsumerState<AddressPointStep> createState() => _AddressPointStepState();
}

enum _Search { start, found, notFound, unavailable }

// The drawing's orange box; the kit palette has no warning colour.
const Color _warningFill = Color(0xFFFFF4E5);
const Color _warningLine = Color(0xFFF5B66B);

class _AddressPointStepState extends ConsumerState<AddressPointStep> {
  static const int _shortest = 3;

  final PointMapMover _mover = PointMapMover();
  final TextEditingController _field = TextEditingController();
  final GlobalKey<FormState> _form = GlobalKey<FormState>();

  late GeoPoint _point = widget.initial;
  String? _words;
  _Search _search = _Search.start;
  bool _searching = false;
  bool _locating = false;

  /// The latest search sent; an older answer is not heard.
  int _searchId = 0;

  /// Counts every move of the pin, the Customer's or ours; an answer sent
  /// before the latest move is not heard.
  int _moves = 0;

  @override
  void dispose() {
    _mover.dispose();
    _field.dispose();
    super.dispose();
  }

  /// The Customer moved the map.
  void _moved(GeoPoint point) {
    _moves++;
    setState(() => _point = point);
  }

  /// An answer moves the map.
  void _moveTo(GeoPoint point) {
    _moves++;
    _point = point;
    _mover.moveTo(point);
  }

  Future<void> _submit(String text) async {
    final String query = text.trim();
    if (query.length < _shortest) {
      return;
    }
    final int id = ++_searchId;
    final int moves = _moves;
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
      if (moves != _moves) {
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
    final int moves = _moves;
    setState(() => _locating = true);
    final GeoPoint? here = await ref.read(deviceLocationProvider).current();
    if (!mounted) {
      return;
    }
    setState(() => _locating = false);
    if (here == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).addressLocationFailed),
        ),
      );
    } else if (moves == _moves) {
      setState(() => _moveTo(here));
    }
  }

  void _confirm(bool movable) {
    if (!movable && !(_form.currentState?.validate() ?? false)) {
      return;
    }
    widget.onConfirmed(AddressPointResult(point: _point, words: _words));
  }

  @override
  Widget build(BuildContext context) {
    final AddressMap map = ref.watch(addressMapProvider);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: map.movable ? _movableMap(map) : _fields(map)),
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
        onMoved: _moved,
      ),
    ),
  );

  Widget _movableMap(AddressMap map) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        map.picker(
          initial: widget.initial,
          mover: _mover,
          enabled: true,
          onMoved: _moved,
        ),
        const IgnorePointer(child: _Pin()),
        Positioned(left: 16, right: 16, top: 14, child: _searchField(l10n)),
        Positioned(
          left: 16,
          right: 16,
          top: 14 + 50 + 8,
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topLeft,
              child: _Hint(
                _search == _Search.found
                    ? l10n.addressSearchFound
                    : l10n.addressMapHint,
              ),
            ),
          ),
        ),
        Positioned(right: 16, bottom: 16, child: _myLocation(l10n)),
      ],
    );
  }

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
    final Widget? box = switch (_search) {
      _Search.notFound => _Notice(
        'address-search-not-found',
        l10n.addressSearchNotFound,
      ),
      _Search.unavailable => _Notice(
        'address-search-unavailable',
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
                      Text(
                        l10n.addressPointTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      box ??
                          Text(
                            l10n.addressPointText,
                            style: const TextStyle(
                              fontSize: 14,
                              color: KitColors.ink2,
                            ),
                          ),
                      if (_words != null) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          l10n.addressWordsKept,
                          key: const ValueKey<String>('address-words-kept'),
                          style: const TextStyle(
                            fontSize: 12,
                            color: KitColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 54,
                child: FilledButton(
                  key: const ValueKey<String>('address-point-confirm'),
                  onPressed: () => _confirm(movable),
                  style: FilledButton.styleFrom(
                    backgroundColor: KitColors.primary,
                    foregroundColor: Colors.white,
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

/// The pin in the centre of the map; its tip is on the map's centre.
class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return const Stack(
      alignment: Alignment.center,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(color: Color(0x4D000000), blurRadius: 4),
            ],
          ),
          child: SizedBox(width: 8, height: 3),
        ),
        Padding(
          padding: EdgeInsets.only(bottom: 48),
          child: Icon(
            Icons.location_on,
            size: 48,
            color: KitColors.primaryDark,
          ),
        ),
      ],
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

/// The drawing's orange box: the search could not place the address.
class _Notice extends StatelessWidget {
  const _Notice(this.keyName, this.text);

  final String keyName;
  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>(keyName),
      decoration: BoxDecoration(
        color: _warningFill,
        border: Border.all(color: _warningLine),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: KitColors.ink),
        ),
      ),
    );
  }
}
