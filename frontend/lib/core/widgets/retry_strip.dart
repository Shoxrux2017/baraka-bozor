import 'dart:async';

import 'package:flutter/material.dart';

import '../layout/text_width.dart';
import '../localization/generated/app_localizations.dart';
import '../theme/kit_colors.dart';

const Cubic _settle = Cubic(0.2, 0.8, 0.2, 1);

/// The red strip of a failure that can be repeated (`DL-134`, `DL-135`): an
/// icon, the [message] and a white «Повторить» 44 high. Above 1.3 at 13 px the
/// button goes under the words at full width. It rises 8 px with a fade in
/// 260 ms when first built (only a fade, in 200 ms, under reduced motion) and is one live
/// region for a reader. [retryKey] sits on the button, [stripKey] on the box.
class RetryStrip extends StatefulWidget {
  const RetryStrip({
    required this.message,
    required this.onRetry,
    this.icon = Icons.wifi_off,
    this.retryKey,
    this.stripKey,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  final IconData icon;
  final Key? retryKey;
  final Key? stripKey;

  @override
  State<RetryStrip> createState() => _RetryStripState();
}

class _RetryStripState extends State<RetryStrip>
    with SingleTickerProviderStateMixin {
  // Reduced motion changes how it arrives, not how long it takes, so the
  // platform's shortening of controllers is switched off.
  late final AnimationController _run = AnimationController(
    vsync: this,
    animationBehavior: AnimationBehavior.preserve,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run.duration = Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 200 : 260,
      );
      unawaited(_run.forward());
    }
  }

  @override
  void dispose() {
    _run.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduced = MediaQuery.disableAnimationsOf(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 13) > 1.3;
    final Widget words = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        widget.message,
        style: const TextStyle(
          fontSize: 13,
          height: 1.35,
          color: KitColors.ink2,
        ),
      ),
    );
    final Widget retry = _RetryButton(
      key: widget.retryKey,
      label: AppLocalizations.of(context).retryButton,
      onTap: widget.onRetry,
    );
    final Widget icon = Icon(widget.icon, size: 20, color: KitColors.danger);

    final Widget strip = Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        key: widget.stripKey,
        decoration: BoxDecoration(
          color: KitColors.dangerWash,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: large
              ? const EdgeInsets.fromLTRB(12, 6, 12, 6)
              : const EdgeInsets.fromLTRB(12, 6, 6, 6),
          child: large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        icon,
                        const SizedBox(width: 10),
                        Expanded(child: words),
                      ],
                    ),
                    retry,
                  ],
                )
              : Row(
                  children: <Widget>[
                    icon,
                    const SizedBox(width: 10),
                    Expanded(child: words),
                    const SizedBox(width: 10),
                    retry,
                  ],
                ),
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedBuilder(
        animation: _run,
        child: strip,
        builder: (BuildContext context, Widget? child) {
          final double t = (reduced ? Curves.easeOut : _settle).transform(
            _run.value,
          );
          return Opacity(
            opacity: t,
            child: reduced
                ? child
                : Transform.translate(
                    offset: Offset(0, (1 - t) * 8),
                    child: child,
                  ),
          );
        },
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: KitColors.danger,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
