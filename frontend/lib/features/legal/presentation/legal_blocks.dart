import 'package:flutter/material.dart';

import '../../../core/theme/kit_colors.dart';
import '../domain/legal.dart';

/// A document's headings, paragraphs and list items in order, as the app
/// shows them (`DL-136` (2)). The Admin's preview draws the same blocks
/// smaller, with a [scale] below one.
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
            previous: i > 0 ? blocks[i - 1].type : null,
          ),
      ],
    );
  }
}

/// The same blocks as a lazy list, so a long text lays out only the blocks
/// that show. The Admin's preview uses it in its fixed frame.
class LegalBlockList extends StatelessWidget {
  const LegalBlockList(
    this.blocks, {
    this.scale = 1,
    this.padding,
    this.physics,
    super.key,
  });

  final List<LegalBlock> blocks;
  final double scale;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: padding,
      physics: physics,
      itemCount: blocks.length,
      itemBuilder: (BuildContext context, int i) => _Block(
        block: blocks[i],
        scale: scale,
        previous: i > 0 ? blocks[i - 1].type : null,
      ),
    );
  }
}

/// One block: reading text 16/26, headings 18 bold `ink`, a drawn 6 px dot
/// for items (`DL-136` (2)). Every size and gap follows [scale].
class _Block extends StatelessWidget {
  const _Block({
    required this.block,
    required this.scale,
    required this.previous,
  });

  final LegalBlock block;
  final double scale;

  /// The kind of the block above, or null for the first block.
  final LegalBlockType? previous;

  @override
  Widget build(BuildContext context) {
    // The first line grows with the text size; the marker box follows it.
    final double grow =
        MediaQuery.textScalerOf(context).scale(16 * scale) / (16 * scale);
    final TextStyle text = TextStyle(
      fontSize: 16 * scale,
      height: 26 / 16,
      color: KitColors.ink2,
    );

    return switch (block.type) {
      LegalBlockType.heading => Padding(
        padding: EdgeInsets.only(
          top: (previous == null ? 6 : 28) * scale,
          bottom: 8 * scale,
        ),
        child: Semantics(
          header: true,
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: 18 * scale,
              height: 24 / 18,
              fontWeight: FontWeight.w700,
              color: KitColors.ink,
            ),
          ),
        ),
      ),
      LegalBlockType.paragraph => Padding(
        padding: EdgeInsets.only(
          top:
              (switch (previous) {
                LegalBlockType.paragraph => 12,
                LegalBlockType.item => 10,
                _ => 0,
              }) *
              scale,
        ),
        child: Text(block.text, style: text),
      ),
      LegalBlockType.item => Padding(
        padding: EdgeInsets.only(
          top:
              (previous == null || previous == LegalBlockType.heading ? 0 : 4) *
              scale,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ExcludeSemantics(
              child: SizedBox(
                width: 22 * scale * grow,
                height: 26 * scale * grow,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 3 * scale),
                    child: SizedBox(
                      width: 6 * scale,
                      height: 6 * scale,
                      child: const DecoratedBox(
                        key: ValueKey<String>('legal-dot'),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: KitColors.ink2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: Text(block.text, style: text)),
          ],
        ),
      ),
    };
  }
}
