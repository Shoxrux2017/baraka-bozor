import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatting/money_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/catalog_labels.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/interface_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/paged.dart';
import '../../../core/orders/order_values.dart';
import '../../../core/orders/quantity_rules.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/state/mutation_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/active_mode_bar.dart';
import '../../../core/widgets/failure_message.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../../core/widgets/kit/kit_empty_state.dart';
import '../../../core/widgets/kit/kit_note.dart';
import '../../../core/widgets/kit/kit_sheet.dart';
import '../../../core/widgets/kit_app_bar.dart';
import '../../../core/widgets/list_widgets.dart';
import '../../../core/widgets/product_image.dart';
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

  void _clear() {
    _search.clear();
    _find('');
  }

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

    // The policy note scrolls with the results: at a large text size it would
    // otherwise leave no room for them.
    final Widget? policy = line == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
            child: KitNote(
              icon: Icons.swap_horiz,
              text: Text(
                line.substitutionPolicy == SubstitutionPolicy.contactBefore
                    ? l10n.replaceInfoContact
                    : l10n.replaceInfoSimilar,
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: kitAppBar(
        title: line == null
            ? l10n.lineReplace
            : l10n.replaceTitle(
                language == AppLanguage.ru ? line.nameRu : line.nameUz,
              ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const ActiveModeBar(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: _SearchField(
                controller: _search,
                hint: l10n.replaceSearchHint,
                onSubmitted: _find,
                onClear: _clear,
              ),
            ),
            Expanded(
              child: choices.when(
                data: (Paged<ReplacementChoice> page) => page.items.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: <Widget>[
                            ?policy,
                            SizedBox(
                              height: 360,
                              child: KitEmptyState(
                                key: const ValueKey<String>('replace-none'),
                                icon: Icons.search_off,
                                title: l10n.replaceNone,
                                text: l10n.replaceNoneHint,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        key: const ValueKey<String>('replace-choices'),
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                        children: <Widget>[
                          ?policy,
                          for (
                            int i = 0;
                            i < page.items.length;
                            i++
                          ) ...<Widget>[
                            if (i > 0)
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: KitColors.line,
                              ),
                            _ChoiceRow(
                              choice: page.items[i],
                              onTap: line == null
                                  ? null
                                  : () => _offer(context, line, page.items[i]),
                            ),
                          ],
                          if (line != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(
                                l10n.replaceUnitHint(
                                  CatalogLabels.unit(l10n, line.unit),
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: KitColors.muted,
                                ),
                              ),
                            ),
                          PaginationBar(
                            page: page,
                            onPage: (int page) => setState(() => _page = page),
                          ),
                        ],
                      ),
                error: (Object error, StackTrace _) => Padding(
                  padding: const EdgeInsets.all(20),
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
    final bool? offered = await showKitSheet<bool>(
      context,
      title: AppLocalizations.of(context).substituteSheetTitle,
      sheetKey: 'substitute-sheet',
      builder: (BuildContext sheet) =>
          _SubstituteSheet(orderId: widget.orderId, line: line, choice: choice),
    );
    if (offered == true && context.mounted) {
      // Opened over the order, back to it; entered alone, on to it.
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppPaths.shopperOrder(widget.orderId));
      }
    }
  }
}

/// The search field: searches on submit, shows a x once something is typed.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) {
        return TextField(
          key: const ValueKey<String>('replace-search'),
          controller: controller,
          textInputAction: TextInputAction.search,
          style: const TextStyle(fontSize: 15, color: KitColors.ink),
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(_searchMax),
          ],
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 15, color: KitColors.muted),
            filled: true,
            fillColor: KitColors.field,
            constraints: const BoxConstraints(minHeight: 50),
            prefixIcon: const Icon(
              Icons.search,
              size: 22,
              color: KitColors.muted,
            ),
            suffixIcon: controller.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey<String>('replace-search-clear'),
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: KitColors.muted,
                    ),
                    onPressed: onClear,
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: KitColors.primary,
                width: 1.5,
              ),
            ),
          ),
          onSubmitted: onSubmitted,
        );
      },
    );
  }
}

/// A product's picture in a square of the kit's card colour.
class _Picture extends StatelessWidget {
  const _Picture({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: KitColors.card,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ProductImage(url: url, size: 56),
    );
  }
}

/// One product the line may be replaced with.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.choice, required this.onTap});

  final ReplacementChoice choice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);

    return InkWell(
      key: ValueKey<String>('replacement-${choice.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: <Widget>[
            _Picture(url: choice.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    language == AppLanguage.ru ? choice.nameRu : choice.nameUz,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: KitColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: <Widget>[
                      Text(
                        l10n.replacePricePer(
                          MoneyFormat.uzs(choice.marketPriceUzs, language),
                          CatalogLabels.unit(l10n, choice.unit),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: KitColors.ink,
                        ),
                      ),
                      Text(
                        '· ${l10n.replaceMarket}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: KitColors.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: KitColors.muted),
          ],
        ),
      ),
    );
  }
}

/// The price paid for a replacement, and a note for the Customer; the typo
/// guard compares the price with the replacement's market price
/// (`DL-54` (20)).
class _SubstituteSheet extends ConsumerStatefulWidget {
  const _SubstituteSheet({
    required this.orderId,
    required this.line,
    required this.choice,
  });

  final String orderId;
  final ShopperLine line;
  final ReplacementChoice choice;

  @override
  ConsumerState<_SubstituteSheet> createState() => _SubstituteSheetState();
}

class _SubstituteSheetState extends ConsumerState<_SubstituteSheet> {
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
    final NavigatorState sheet = Navigator.of(context);
    final GoRouter router = GoRouter.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ShopperOrder? done = await ref
        .read(shopperLineActionProvider(_lineRef).notifier)
        .substitute(widget.choice.id, price, optionalNote(_note.text));
    if (mounted && done != null) {
      closeOnAnswer(
        dialog: sheet,
        router: router,
        messenger: messenger,
        l10n: l10n,
        answer: done,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage language = interfaceLanguage(context);
    final MutationState change = ref.watch(shopperLineActionProvider(_lineRef));
    final ReplacementChoice choice = widget.choice;
    final ShopperLine line = widget.line;
    final bool ru = language == AppLanguage.ru;

    return PopScope(
      canPop: !change.isBusy,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.substituteInstead(
                  ru ? line.nameRu : line.nameUz,
                  '${QuantityRules.display(line.quantity)} '
                  '${CatalogLabels.unit(l10n, line.unit)}',
                ),
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: KitColors.ink2,
                ),
              ),
              const SizedBox(height: 12),
              ShopperSheetHeader(
                imageUrl: choice.imageUrl,
                name: ru ? choice.nameRu : choice.nameUz,
                detail: l10n.itemMarketPrice(
                  MoneyFormat.uzs(choice.marketPriceUzs, language),
                ),
              ),
              const SizedBox(height: 16),
              PriceField(
                fieldKey: 'substitute-price',
                controller: _price,
                label: l10n.substitutePriceFor(
                  CatalogLabels.unit(l10n, choice.unit),
                ),
                required: true,
                enabled: !change.isBusy,
              ),
              const SizedBox(height: 14),
              KitNoteField(
                fieldKey: 'substitute-note',
                controller: _note,
                label: l10n.actionNote,
                hint: l10n.askNotePlaceholder,
                enabled: !change.isBusy,
              ),
              const SizedBox(height: 14),
              KitNote(
                icon: Icons.info_outline,
                text: Text(
                  line.substitutionPolicy == SubstitutionPolicy.contactBefore
                      ? l10n.substituteInfoContact
                      : l10n.substituteInfoSimilar,
                ),
              ),
              // The replacement already authorized, above its bound: the
              // purchase is where its price is asked of the Customer.
              if (change.failure case ApiRefusal(
                code: 'customer_approval_required',
              ))
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: KitNote(
                    key: const ValueKey<String>('substitute-use-buy'),
                    icon: Icons.warning_amber_rounded,
                    tone: KitTone.amber,
                    text: Text(
                      l10n.substituteUseBuy,
                      style: const TextStyle(color: KitColors.warningDark),
                    ),
                  ),
                )
              else
                FailureMessage(change.failure),
              const SizedBox(height: 20),
              KitActionPair(
                secondary: OutlinedButton(
                  key: const ValueKey<String>('substitute-cancel'),
                  style: kitOutlined(),
                  onPressed: change.isBusy
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: Text(l10n.cancelButton),
                ),
                primary: FilledButton(
                  key: const ValueKey<String>('substitute-save'),
                  style: kitFilled(),
                  onPressed: change.isBusy ? null : _submit,
                  child: Text(l10n.substituteSave),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
