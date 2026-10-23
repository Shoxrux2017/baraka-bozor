import 'package:flutter/material.dart';

import '../../theme/kit_colors.dart';

/// A round avatar with the initials of [name], green on its wash — or, when
/// [muted], grey on `field`.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar(
    this.name, {
    this.size = 42,
    this.muted = false,
    super.key,
  });

  final String? name;
  final double size;
  final bool muted;

  String get _initials {
    final List<String> words = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return '?';
    }
    final String first = String.fromCharCode(words.first.runes.first);
    final String second = words.length > 1
        ? String.fromCharCode(words[1].runes.first)
        : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: muted ? KitColors.field : KitColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: muted ? KitColors.muted : KitColors.primaryDark,
        ),
      ),
    );
  }
}

/// A person as a line: the avatar, then the [name] with its [tags] after it
/// over the [detail] in muted 12.
class PanelPersonLine extends StatelessWidget {
  const PanelPersonLine({
    required this.name,
    required this.detail,
    this.tags = const <Widget>[],
    this.avatar = 40,
    this.muted = false,
    super.key,
  });

  final String name;
  final String detail;
  final List<Widget> tags;
  final double avatar;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Text nameText = Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: muted ? KitColors.muted : KitColors.ink,
      ),
    );

    return Row(
      children: <Widget>[
        PersonAvatar(name, size: avatar, muted: muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (tags.isEmpty)
                nameText
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[nameText, ...tags],
                ),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: KitColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
