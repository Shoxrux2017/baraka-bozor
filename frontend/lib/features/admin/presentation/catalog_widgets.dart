import 'package:flutter/material.dart';

import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/kit_colors.dart';
import '../domain/admin_catalog.dart';

/// Where an entry stands, in words and with an icon, so the state is never
/// told by colour alone.
class EntryStateChip extends StatelessWidget {
  const EntryStateChip(this.state, {super.key});

  final CatalogEntryState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final (IconData icon, String label) = switch (state) {
      CatalogEntryState.active => (
        Icons.visibility_outlined,
        l10n.catalogStateActive,
      ),
      CatalogEntryState.hidden => (
        Icons.visibility_off_outlined,
        l10n.catalogStateHidden,
      ),
      CatalogEntryState.archived => (
        Icons.inventory_2_outlined,
        l10n.catalogStateArchived,
      ),
    };

    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The fields a `validation_failed` refusal names, by API field name.
Set<String> rejectedFields(ApiFailure? failure) =>
    failure is ApiRefusal && failure.code == 'validation_failed'
    ? failure.error.errors.keys.toSet()
    : <String>{};

/// Two fields side by side on a wide form, one under the other on a narrow
/// one — the Uzbek and the Russian text of the same thing.
class SideBySide extends StatelessWidget {
  const SideBySide({required this.first, required this.second, super.key});

  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 560) {
          return Column(children: <Widget>[first, second]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: first),
            const SizedBox(width: 16),
            Expanded(child: second),
          ],
        );
      },
    );
  }
}

/// A name in the panel's language: the Russian one when the panel is in
/// Russian, the Uzbek one otherwise.
String catalogName(
  BuildContext context, {
  required String uz,
  required String ru,
}) => Localizations.localeOf(context).languageCode == AppLanguage.ru.code
    ? ru
    : uz;

/// The name in the other language than the panel's, shown smaller.
String catalogOtherName(
  BuildContext context, {
  required String uz,
  required String ru,
}) => Localizations.localeOf(context).languageCode == AppLanguage.ru.code
    ? uz
    : ru;

/// A product's or category's picture, or — with none, or when it cannot be
/// loaded — a placeholder: the [letter] on `primarySoft` for a category, an
/// image icon on `field` for a product.
class CatalogThumb extends StatelessWidget {
  const CatalogThumb({
    required this.url,
    this.size = 44,
    this.letter,
    super.key,
  });

  final String? url;
  final double size;

  /// The category's first letter, shown when there is no picture.
  final String? letter;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.circular(size * 12 / 44);
    final String? letter = this.letter;
    final Widget placeholder = letter != null
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: KitColors.primarySoft,
              borderRadius: radius,
            ),
            child: Center(
              child: Text(
                letter,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: KitColors.primaryDark,
                ),
              ),
            ),
          )
        : DecoratedBox(
            decoration: BoxDecoration(
              color: KitColors.field,
              borderRadius: radius,
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: size / 2,
                color: KitColors.muted,
                semanticLabel: AppLocalizations.of(context).productNoImage,
              ),
            ),
          );
    final String? url = this.url;

    return SizedBox.square(
      dimension: size,
      child: url == null
          ? placeholder
          : ClipRRect(
              borderRadius: radius,
              child: ColoredBox(
                color: KitColors.field,
                child: Image.network(
                  url,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  // The browser loads an image from another origin, one that
                  // sends no CORS headers for its files, only as its own
                  // image element: tried after the ordinary load fails
                  // (`DL-34`).
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? _,
                  ) => placeholder,
                ),
              ),
            ),
    );
  }
}

/// A 24-high chip of radius 6 with its [label], used for a state and a tag.
class _CatalogChip extends StatelessWidget {
  const _CatalogChip({
    required this.background,
    required this.foreground,
    required this.label,
    this.icon,
    this.iconSize = 14,
  });

  final Color background;
  final Color foreground;
  final String label;
  final IconData? icon;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final IconData? icon = this.icon;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: iconSize, color: foreground),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Where an entry stands, in words: shown (green), hidden or archived (grey,
/// with an icon), so the state is never told by colour alone.
class CatalogStateChip extends StatelessWidget {
  const CatalogStateChip(this.state, {super.key});

  final CatalogEntryState state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return switch (state) {
      CatalogEntryState.active => _CatalogChip(
        background: KitColors.primaryWash,
        foreground: KitColors.primaryDark,
        label: l10n.catalogStateActive,
      ),
      CatalogEntryState.hidden => _CatalogChip(
        background: KitColors.field,
        foreground: KitColors.ink2,
        label: l10n.catalogStateHidden,
        icon: Icons.visibility_off_outlined,
      ),
      CatalogEntryState.archived => _CatalogChip(
        background: KitColors.line,
        foreground: KitColors.ink2,
        label: l10n.catalogStateArchived,
        icon: Icons.inventory_2_outlined,
      ),
    };
  }
}

/// The "recommended" tag of a featured product.
class FeaturedTag extends StatelessWidget {
  const FeaturedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return _CatalogChip(
      background: KitColors.warningWash,
      foreground: KitColors.warningDark,
      label: AppLocalizations.of(context).productFeaturedBadge,
      icon: Icons.star,
      iconSize: 15,
    );
  }
}

/// What the list says of a product that is shown but that no Customer sees
/// because its [category] is hidden or archived (`CustomerCatalogListing::
/// visibleProducts`); null when the category hides nothing or is not known.
String? categoryHidesLine(
  AppLocalizations l10n,
  CatalogEntryState product,
  AdminCategory? category,
) {
  if (product != CatalogEntryState.active || category == null) {
    return null;
  }
  return switch (category.state) {
    CatalogEntryState.active => null,
    CatalogEntryState.hidden => l10n.catalogCategoryHiddenLine,
    CatalogEntryState.archived => l10n.catalogCategoryArchivedLine,
  };
}

/// A product's image, or a placeholder when it has none or it cannot be
/// loaded.
class ProductThumbnail extends StatelessWidget {
  const ProductThumbnail({required this.url, required this.size, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget placeholder = SizedBox.square(
      dimension: size,
      child: Icon(
        Icons.image_not_supported_outlined,
        size: size / 2,
        semanticLabel: AppLocalizations.of(context).productNoImage,
      ),
    );
    final String? url = this.url;
    if (url == null) {
      return placeholder;
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // The browser loads an image from another origin, one that sends no
        // CORS headers for its files, only as its own image element: tried
        // after the ordinary load fails (`DL-34`).
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        errorBuilder: (BuildContext context, Object error, StackTrace? _) =>
            placeholder,
      ),
    );
  }
}
