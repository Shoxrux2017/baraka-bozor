import 'package:flutter/material.dart';

/// The Telegram mark without an asset: a blue disc with a white paper plane.
/// [size] is the disc's side; the sign-in pages draw it at 20, 24 and 40
/// (`DL-139`).
class TelegramMark extends StatelessWidget {
  const TelegramMark({this.size = 20, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Color(0xFF2AABEE),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: -0.5236,
          child: Icon(
            Icons.send_rounded,
            size: size * 11 / 20,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
