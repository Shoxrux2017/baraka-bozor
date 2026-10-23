import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';
import '../domain/legal.dart';

/// A document's headings, paragraphs and list items in order, as the app
/// shows them (kit drawings 34 and 35). The Admin's preview draws the same
/// blocks smaller, with a [scale] below one.
class LegalBlocks extends StatelessWidget {
  const LegalBlocks(this.blocks, {this.scale = 1, super.key});

  final List<LegalBlock> blocks;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int i = 0; i < blocks.length; i++)
          _Block(
            block: blocks[i],
            scale: scale,
            first: i == 0,
            afterParagraph:
                i > 0 && blocks[i - 1].type == LegalBlockType.paragraph,
          ),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.scale,
    required this.first,
    required this.afterParagraph,
  });

  final LegalBlock block;
  final double scale;
  final bool first;
  final bool afterParagraph;

  @override
  Widget build(BuildContext context) {
    final TextStyle text = TextStyle(
      fontSize: 14 * scale,
      height: 22 / 14,
      color: KitColors.ink2,
    );

    return switch (block.type) {
      LegalBlockType.heading => Padding(
        padding: EdgeInsets.only(top: first ? 4 : 22, bottom: 6),
        child: Semantics(
          header: true,
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 15 * scale,
              height: 22 / 15,
              fontWeight: FontWeight.w700,
              color: KitColors.primaryDark,
            ),
          ),
        ),
      ),
      LegalBlockType.paragraph => Padding(
        padding: EdgeInsets.only(top: afterParagraph ? 6 : 0),
        child: Text(block.text, style: text),
      ),
      LegalBlockType.item => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 18 * scale,
            child: Text('•', style: text),
          ),
          Expanded(child: Text(block.text, style: text)),
        ],
      ),
    };
  }
}
