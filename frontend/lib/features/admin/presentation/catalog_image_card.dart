import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_card.dart';
import '../../../core/widgets/kit/kit_dialog.dart';
import '../../../core/widgets/panel/panel_card.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'catalog_widgets.dart' show CatalogThumb, catalogThumbRadius;

const TextStyle _cardTitle = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: KitColors.ink,
);

/// A catalog entry's picture: the current one, a picked one waiting to be
/// sent, the way to choose another and the way to remove it. The product page
/// and the category window share it.
///
/// A [compact] card is an outlined box with the picture at its left, as in the
/// category window; otherwise the picture is a square filling the card's
/// width, as at the right of the product page.
///
/// [keyPrefix] goes in front of every key, so two cards can be told apart in
/// tests. A picked image is dropped once [imageUrl] changes: the upload went
/// through.
class CatalogImageCard extends ConsumerStatefulWidget {
  const CatalogImageCard({
    required this.imageUrl,
    required this.onUpload,
    required this.onRemove,
    required this.change,
    required this.keyPrefix,
    required this.compact,
    this.compactPictureSize = 88,
    this.onCard = false,
    this.title,
    this.removeConfirm,
    this.removeExplained,
    super.key,
  });

  final String? imageUrl;
  final Future<void> Function(PickedImage image) onUpload;
  final Future<void> Function() onRemove;

  /// The upload or removal that runs now, or the failure of the last one.
  final MutationState change;
  final String keyPrefix;
  final bool compact;

  /// The side of the picture of a [compact] card.
  final double compactPictureSize;

  /// Stands a [compact] card on a white card of its own, with the title above
  /// the picture as the square card has it, instead of in an outlined box.
  final bool onCard;

  /// The card's heading, the removal question and what it says Customers will
  /// see instead; the product's when null.
  final String? title;
  final String? removeConfirm;
  final String? removeExplained;

  @override
  ConsumerState<CatalogImageCard> createState() => _CatalogImageCardState();
}

class _CatalogImageCardState extends ConsumerState<CatalogImageCard> {
  PickedImage? _picked;
  String? _problem;

  ValueKey<String> _key(String name) =>
      ValueKey<String>('${widget.keyPrefix}$name');

  @override
  void didUpdateWidget(CatalogImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _picked = null;
    }
  }

  Future<void> _choose() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final PickedImage? image;
    try {
      image = await ref.read(productImagePickerProvider).pick();
    } on Object catch (error, stackTrace) {
      // A file moved or deleted after it was chosen cannot be read.
      reportUnexpectedError(error, stackTrace, 'while reading a picked image');
      if (mounted) {
        setState(() {
          _picked = null;
          _problem = l10n.productImageUnreadable;
        });
      }
      return;
    }
    if (!mounted || image == null) {
      return;
    }
    final String? problem = image.isTooLarge
        ? l10n.productImageTooLarge
        : image.looksLikeAcceptedImage
        ? null
        : l10n.productImageWrongType;
    setState(() {
      _problem = problem;
      _picked = problem == null ? image : null;
    });
  }

  Future<void> _upload() async {
    final PickedImage? image = _picked;
    if (image == null) {
      return;
    }
    await widget.onUpload(image);
  }

  Future<void> _remove() async {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool confirmed =
        await showKitDialog<bool>(
          context: context,
          dialogKey: '${widget.keyPrefix}remove-image-dialog',
          title: widget.removeConfirm ?? l10n.productRemoveImageConfirm,
          builder: (BuildContext dialog) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                widget.removeExplained ?? l10n.productRemoveImageExplained,
                style: const TextStyle(fontSize: 13, color: KitColors.ink2),
              ),
              const SizedBox(height: 20),
              kitDialogButtons(
                context: dialog,
                busy: false,
                destructive: true,
                confirm: l10n.productRemoveImage,
                confirmIcon: Icons.delete_outline,
                confirmKey: _key('confirm-remove-image'),
                submit: () => Navigator.of(dialog).pop(true),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await widget.onRemove();
  }

  /// The current picture, or the picked one in its place, outlined and
  /// labelled as not uploaded.
  Widget _picture(AppLocalizations l10n, double size) {
    final PickedImage? picked = _picked;
    if (picked == null) {
      return CatalogThumb(
        key: _key('current-image'),
        url: widget.imageUrl,
        size: size,
      );
    }
    final BorderRadius radius = BorderRadius.circular(catalogThumbRadius(size));
    return SizedBox.square(
      key: _key('picked-image'),
      dimension: size,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: KitColors.primary, width: 2),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              Image.memory(
                picked.bytes,
                fit: BoxFit.cover,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? _) =>
                        const ColoredBox(
                          color: KitColors.field,
                          child: Icon(Icons.broken_image_outlined),
                        ),
              ),
              Positioned(
                left: 0,
                top: 0,
                right: 0,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: KitColors.primary,
                      borderRadius: BorderRadius.only(
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.upload,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              l10n.productImagePicked,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
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

  Widget _problemLine(String problem) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Icon(Icons.error_outline, size: 16, color: KitColors.danger),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            problem,
            key: _key('image-problem'),
            style: const TextStyle(fontSize: 12, color: KitColors.danger),
          ),
        ),
      ],
    );
  }

  /// "Upload" (only with a picked image), "choose" and "remove" (only with a
  /// current image and nothing picked), in that order.
  List<Widget> _buttons(AppLocalizations l10n, double height, double fontSize) {
    final TextStyle label = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
    final bool busy = widget.change.isBusy;
    final bool picked = _picked != null;
    return <Widget>[
      if (picked)
        FilledButton.icon(
          key: _key('upload-image'),
          style: kitFilled(height: height)
              .copyWith(textStyle: WidgetStatePropertyAll<TextStyle>(label)),
          icon: const Icon(Icons.upload, size: 18),
          label: Text(l10n.productUploadImage),
          onPressed: busy ? null : _upload,
        ),
      OutlinedButton.icon(
        key: _key('choose-image'),
        style: kitOutlined(height: height)
            .copyWith(textStyle: WidgetStatePropertyAll<TextStyle>(label)),
        icon: const Icon(Icons.image_outlined, size: 18),
        label: Text(l10n.productChooseImage),
        onPressed: busy ? null : _choose,
      ),
      if (widget.imageUrl != null && !picked)
        TextButton.icon(
          key: _key('remove-image'),
          style: TextButton.styleFrom(
            foregroundColor: KitColors.danger,
            minimumSize: Size(0, height),
            textStyle: label,
          ),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: Text(l10n.productRemoveImage),
          onPressed: busy ? null : _remove,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final String title = widget.title ?? l10n.productImage;
    final String? problem = _problem;

    if (widget.compact) {
      final Widget row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _picture(l10n, widget.compactPictureSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!widget.onCard) ...<Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  l10n.productImageRules,
                  style: const TextStyle(fontSize: 12, color: KitColors.muted),
                ),
                if (problem != null) ...<Widget>[
                  const SizedBox(height: 6),
                  _problemLine(problem),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _buttons(l10n, 36, 12),
                ),
                FailureMessage(widget.change.failure),
              ],
            ),
          ),
        ],
      );
      if (widget.onCard) {
        return KitCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: _cardTitle),
              const SizedBox(height: 12),
              row,
            ],
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KitColors.line),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: row),
      );
    }

    final List<Widget> buttons = _buttons(l10n, 44, 13);
    return KitCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title, style: _cardTitle),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints box) =>
                _picture(l10n, box.maxWidth),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.productImageRules,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: KitColors.muted),
          ),
          if (problem != null) ...<Widget>[
            const SizedBox(height: 8),
            Center(child: _problemLine(problem)),
          ],
          const SizedBox(height: 12),
          for (int i = 0; i < buttons.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 8),
            buttons[i],
          ],
          FailureMessage(widget.change.failure),
        ],
      ),
    );
  }
}

/// What a picture's place says before the entry exists: a picture can be added
/// once it is saved. A [compact] place is the outlined box (or, [onCard], the
/// white card) with the empty picture at its left; otherwise a card with a
/// square one.
class CatalogImagePlaceholder extends StatelessWidget {
  const CatalogImagePlaceholder({
    required this.title,
    required this.text,
    required this.compact,
    this.onCard = false,
    super.key,
  });

  final String title;
  final String text;
  final bool compact;
  final bool onCard;

  @override
  Widget build(BuildContext context) {
    const Widget icon = Icon(
      Icons.add_photo_alternate_outlined,
      size: 44,
      color: KitColors.muted,
    );
    final Widget note = Text(
      text,
      textAlign: compact ? TextAlign.start : TextAlign.center,
      style: const TextStyle(fontSize: 12, color: KitColors.muted),
    );
    final BoxDecoration ground = BoxDecoration(
      color: KitColors.field,
      borderRadius: BorderRadius.circular(catalogThumbRadius(88)),
    );

    if (compact) {
      final Widget row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox.square(
            dimension: 88,
            child: DecoratedBox(
              decoration: ground,
              child: const Center(child: icon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (!onCard) ...<Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                ],
                note,
              ],
            ),
          ),
        ],
      );
      if (onCard) {
        return KitCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(title, style: _cardTitle),
              const SizedBox(height: 12),
              row,
            ],
          ),
        );
      }
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: KitColors.line),
        ),
        child: Padding(padding: const EdgeInsets.all(12), child: row),
      );
    }

    return PanelCard(
      title: title,
      children: <Widget>[
        const SizedBox(height: 12),
        AspectRatio(
          aspectRatio: 1,
          child: DecoratedBox(
            decoration: ground,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[icon, const SizedBox(height: 8), note],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
