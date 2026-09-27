import 'package:flutter/material.dart';

import '../localization/generated/app_localizations.dart';
import '../network/api_failure.dart';
import '../network/paged.dart';
import 'failure_message.dart';

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
        Flexible(
          child: Text(
            l10n.catalogPage(page.page, page.lastPage),
            overflow: TextOverflow.ellipsis,
          ),
        ),
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

/// Something that could not be loaded: the reason, and a retry unless the
/// thing does not exist — asking again cannot bring it back.
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
        if (!(failure is ApiRefusal && failure.status == 404)) ...<Widget>[
          const SizedBox(height: 12),
          OutlinedButton(
            key: const ValueKey<String>('retry-load'),
            onPressed: onRetry,
            child: Text(AppLocalizations.of(context).retryButton),
          ),
        ],
      ],
    );
  }
}
