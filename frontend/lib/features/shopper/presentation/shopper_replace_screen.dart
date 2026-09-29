import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/paged.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/list_widgets.dart';
import '../application/shopper_orders_controllers.dart';
import '../domain/price_guard.dart';
import '../domain/shopper_orders.dart';
import 'shopper_line_actions.dart';

/// The longest search the server takes (`DL-44` (4)).
const int _searchMax = 100;

/// A replacement for one line (`docs/09` section 33, `DL-54` (17)): the
/// products of the line's unit the Customer's catalog shows, searched as the
/// catalog searches, each with its market price. Choosing one asks for the
/// price paid; the line's policy decides whether the replacement is
/// authorized at once or asked of the Customer.
class ShopperReplaceScreen extends ConsumerStatefulWidget {
  const ShopperReplaceScreen({
    required this.orderId,
    required this.itemId,
    super.key,
  });

  final String orderId;
  final String itemId;

  @override
  ConsumerState<ShopperReplaceScreen> createState() =>
      _ShopperReplaceScreenState();
}

class _ShopperReplaceScreenState extends ConsumerState<ShopperReplaceScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int _page = 1;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _find(String text) => setState(() {
    _query = text.trim();
    _page = 1;
  });

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final ShopperLine? line = ref
        .watch(shopperOrderProvider(widget.orderId))
        .value
        ?.items
        .where((ShopperLine line) => line.id == widget.itemId)
        .firstOrNull;
    final ReplacementQuery query = (
      orderId: widget.orderId,
      itemId: widget.itemId,
      search: _query,
      page: _page,
    );
    final AsyncValue<Paged<ReplacementChoice>> choices = ref.watch(
      replacementChoicesProvider(query),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          line == null
              ? l10n.lineReplace
              : l10n.replaceTitle(
                  language == AppLanguage.ru ? line.nameRu : line.nameUz,
                ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                key: const ValueKey<String>('replace-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                inputFormatters: <TextInputFormatter>[
                  LengthLimitingTextInputFormatter(_searchMax),
                ],
                decoration: InputDecoration(
                  hintText: l10n.replaceSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: _find,
              ),
            ),
            Expanded(
              child: choices.when(
                data: (Paged<ReplacementChoice> page) => page.items.isEmpty
                    ? Center(
                        key: const ValueKey<String>('replace-none'),
                        child: Text(l10n.replaceNone),
                      )
                    : ListView(
                        key: const ValueKey<String>('replace-choices'),
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          for (final ReplacementChoice choice in page.items)
                            Card(
                              child: ListTile(
                                key: ValueKey<String>(
                                  'replacement-${choice.id}',
                                ),
                                title: Text(
                                  language == AppLanguage.ru
                                      ? choice.nameRu
                                      : choice.nameUz,
                                ),
                                subtitle: Text(
                                  l10n.itemMarketPrice(
                                    MoneyFormat.uzs(
                                      choice.marketPriceUzs,
                                      language,
                                    ),
                                  ),
                                ),
                                onTap: line == null
                                    ? null
                                    : () => _offer(context, line, choice),
                              ),
                            ),
                          PaginationBar(
                            page: page,
                            onPage: (int page) => setState(() => _page = page),
                          ),
                        ],
                      ),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: LoadFailure(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(replacementChoicesProvider(query)),
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _offer(
    BuildContext context,
    ShopperLine line,
    ReplacementChoice choice,
  ) async {
    final bool? offered = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => _SubstituteDialog(
        orderId: widget.orderId,
        line: line,
        choice: choice,
      ),
    );
    if (offered == true && context.mounted) {
      context.pop();
    }
  }
}

/// The price paid for a replacement, and a note for the Customer; the typo
/// guard compares the price with the replacement's market price
/// (`DL-54` (20)).
class _SubstituteDialog extends ConsumerStatefulWidget {
  const _SubstituteDialog({
    required this.orderId,
    required this.line,
    required this.choice,
  });

  final String orderId;
  final ShopperLine line;
  final ReplacementChoice choice;

  @override
  ConsumerState<_SubstituteDialog> createState() => _SubstituteDialogState();
}

class _SubstituteDialogState extends ConsumerState<_SubstituteDialog> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final TextEditingController _price = TextEditingController();
  final TextEditingController _note = TextEditingController();

  ShopperLineRef get _lineRef =>
      (orderId: widget.orderId, itemId: widget.line.id);

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      return;
    }
    final int price = parsePrice(_price.text)!;
    final int market = widget.choice.marketPriceUzs;
    if (looksMistyped(price, market) &&
        !await confirmUnusualPrice(context, price, market)) {
      return;
    }
    if (!mounted) {
      return;
    }
    final ShopperOrder? done = await ref
        .read(shopperLineActionProvider(_lineRef).notifier)
        .substitute(widget.choice.id, price, optionalNote(_note.text));
    if (mounted && done != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState change = ref.watch(shopperLineActionProvider(_lineRef));
    final ReplacementChoice choice = widget.choice;

    return PopScope(
      canPop: !change.isBusy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
          l10n.substituteTitle(
            language == AppLanguage.ru ? choice.nameRu : choice.nameUz,
          ),
        ),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  l10n.itemMarketPrice(
                    MoneyFormat.uzs(choice.marketPriceUzs, language),
                  ),
                ),
                const SizedBox(height: 12),
                PriceField(
                  fieldKey: 'substitute-price',
                  controller: _price,
                  label: l10n.purchasePrice,
                  required: true,
                  enabled: !change.isBusy,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey<String>('substitute-note'),
                  controller: _note,
                  enabled: !change.isBusy,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: l10n.askNote,
                    border: const OutlineInputBorder(),
                  ),
                  validator: (String? text) => noteTooLong(l10n, text ?? ''),
                ),
                FailureMessage(change.failure),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            key: const ValueKey<String>('substitute-cancel'),
            onPressed: change.isBusy ? null : () => Navigator.of(context).pop(),
            child: Text(l10n.cancelButton),
          ),
          FilledButton(
            key: const ValueKey<String>('substitute-save'),
            onPressed: change.isBusy ? null : _submit,
            child: Text(l10n.substituteSave),
          ),
        ],
      ),
    );
  }
}
