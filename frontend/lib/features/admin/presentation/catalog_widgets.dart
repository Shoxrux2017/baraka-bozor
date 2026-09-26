import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/widgets/failure_message.dart';
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

/// The page controls under a list: where the list is, and the way to the
/// previous and the next page.
class PaginationBar extends StatelessWidget {
  const PaginationBar({required this.page, required this.onPage, super.key});

  final Paged<Object?> page;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        IconButton(
          key: const ValueKey<String>('previous-page'),
          tooltip: l10n.catalogPreviousPage,
          icon: const Icon(Icons.chevron_left),
          onPressed: page.hasPrevious ? () => onPage(page.page - 1) : null,
        ),
        Text(l10n.catalogPage(page.page, page.lastPage)),
        IconButton(
          key: const ValueKey<String>('next-page'),
          tooltip: l10n.catalogNextPage,
          icon: const Icon(Icons.chevron_right),
          onPressed: page.hasNext ? () => onPage(page.page + 1) : null,
        ),
      ],
    );
  }
}

/// A list that could not be loaded: the reason and a retry.
class LoadFailure extends StatelessWidget {
  const LoadFailure({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ApiFailure failure = error is ApiFailure
        ? error as ApiFailure
        : const UnexpectedFailure();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        FailureMessage(failure),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          child: Text(AppLocalizations.of(context).retryButton),
        ),
      ],
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
