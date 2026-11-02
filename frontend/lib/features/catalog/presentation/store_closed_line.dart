import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/clock.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../cart/application/cart_controllers.dart';
import '../../cart/domain/store_hours.dart';

/// "Сейчас закрыто. …": shown on the home while the cart's working hours
/// exist and the store is closed at the clock's now. It comes and goes at
/// the moment the hours change, and never blocks an order: checkout stays the
/// authority (`DL-125`).
class StoreClosedLine extends ConsumerStatefulWidget {
  const StoreClosedLine({super.key});

  @override
  ConsumerState<StoreClosedLine> createState() => _StoreClosedLineState();
}

class _StoreClosedLineState extends ConsumerState<StoreClosedLine> {
  Timer? _timer;

  /// The hours last known, kept while the line folds away.
  StoreHours? _hours;

  /// Whether the line is in the tree, folding included.
  bool _present = false;

  /// Whether the line unfolds when it comes; one closed at the first build
  /// stands.
  bool _appear = false;
  bool _first = true;

  void _schedule(StoreHours? hours, DateTime now) {
    _timer?.cancel();
    _timer = null;
    if (hours == null) {
      return;
    }
    _timer = Timer(hours.nextChangeAfter(now).difference(now), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StoreHours? hours = ref.watch(currentCartProvider).value?.hours;
    final DateTime now = ref.watch(clockProvider)();
    _schedule(hours, now);
    final bool closed = hours != null && !hours.isOpenAt(now);
    if (hours != null) {
      _hours = hours;
    }
    if (closed && !_present) {
      _present = true;
      _appear = !_first;
    }
    _first = false;
    final StoreHours? shown = _hours;
    if (!_present || shown == null) {
      return const SizedBox.shrink();
    }
    return Fold(
      shown: closed,
      appear: _appear,
      onFolded: () => setState(() => _present = false),
      child: _Line(opensAt: shown.opensAt),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.opensAt});

  final String opensAt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    // 08:00 is read 8:00.
    final String time = opensAt.replaceFirst(RegExp(r'^0'), '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Semantics(
        key: const ValueKey<String>('store-closed'),
        container: true,
        label: '${l10n.homeClosedTitle} ${l10n.homeClosedBody(time)}',
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KitColors.warningWash,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.schedule,
                  size: 20,
                  color: KitColors.warningDark,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: l10n.homeClosedTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: KitColors.warningDark,
                          ),
                        ),
                        TextSpan(text: ' ${l10n.homeClosedBody(time)}'),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: KitColors.ink2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
