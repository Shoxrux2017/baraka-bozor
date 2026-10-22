import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/report_unexpected_error.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/failure_message.dart';
import '../application/admin_catalog_controllers.dart';
import '../domain/admin_catalog.dart';
import 'catalog_widgets.dart' show ProductThumbnail;

/// A catalog entry's picture: the current one, a picked one waiting to be
/// sent, the way to choose another and the way to remove it. The product form
/// and the category dialog share it.
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
    this.title,
    this.removeConfirm,
    super.key,
  });

  final String? imageUrl;
  final Future<void> Function(PickedImage image) onUpload;
  final Future<void> Function() onRemove;

  /// The upload or removal that runs now, or the failure of the last one.
  final MutationState change;
  final String keyPrefix;

  /// The card's heading and the removal question; the product's when null.
  final String? title;
  final String? removeConfirm;

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
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            content: Text(
              widget.removeConfirm ?? l10n.productRemoveImageConfirm,
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancelButton),
              ),
              FilledButton(
                key: _key('confirm-remove-image'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.productRemoveImage),
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final MutationState change = widget.change;
    final PickedImage? picked = _picked;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title ?? l10n.productImage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(l10n.productImageRules),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: <Widget>[
                ProductThumbnail(
                  key: _key('current-image'),
                  url: widget.imageUrl,
                  size: 160,
                ),
                if (picked != null)
                  ClipRRect(
                    key: _key('picked-image'),
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      picked.bytes,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (BuildContext context, Object error, StackTrace? _) =>
                              const SizedBox.square(
                                dimension: 160,
                                child: Icon(Icons.broken_image_outlined),
                              ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  key: _key('choose-image'),
                  icon: const Icon(Icons.image_outlined),
                  label: Text(l10n.productChooseImage),
                  onPressed: change.isBusy ? null : _choose,
                ),
                if (picked != null)
                  FilledButton.icon(
                    key: _key('upload-image'),
                    icon: const Icon(Icons.upload),
                    label: Text(l10n.productUploadImage),
                    onPressed: change.isBusy ? null : _upload,
                  ),
                if (widget.imageUrl != null && picked == null)
                  TextButton.icon(
                    key: _key('remove-image'),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.productRemoveImage),
                    onPressed: change.isBusy ? null : _remove,
                  ),
              ],
            ),
            if (_problem != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _problem!,
                  key: _key('image-problem'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FailureMessage(change.failure),
          ],
        ),
      ),
    );
  }
}
