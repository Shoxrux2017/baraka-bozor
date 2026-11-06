import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/layout/text_width.dart';
import '../../../core/legal/legal_document_kind.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/platform/phone_calls.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/fold.dart';
import '../../../core/widgets/skeleton_bar.dart';
import '../../addresses/application/delivery_address.dart';
import '../../addresses/domain/addresses.dart';
import '../../legal/application/legal_providers.dart';
import '../../legal/domain/legal.dart';
import '../domain/profile.dart';
import 'delete_account_sheets.dart';
import 'language_sheet.dart';

/// The rows under the profile's header, in the groups «Аккаунт», «Приложение»
/// and «Помощь», then the red rows «Выйти» and «Удалить аккаунт» (kit drawing
/// 32, `DL-135`). They stand from the first frame: support and the two
/// documents show a skeleton while their data is still coming, and fold away
/// if it never comes. A row says what is inside it (the address, the language,
/// the number to call). [onLogout] runs when the logout row is tapped.
class ProfileRows extends ConsumerWidget {
  const ProfileRows({required this.profile, required this.onLogout, super.key});

  final AsyncValue<CustomerProfile> profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool large = textScaleAt(MediaQuery.textScalerOf(context), 16) > 1.3;
    final Address? address = ref.watch(deliveryAddressProvider).value;
    final AppLanguage? language = ref.watch(languageControllerProvider).value;
    final AsyncValue<LegalIndex> index = ref.watch(legalIndexProvider);
    final SessionState? session = ref.watch(sessionControllerProvider).value;

    final String? addressLabel = address == null
        ? null
        : (address.label?.trim().isNotEmpty ?? false)
        ? address.label!.trim()
        : address.streetLine;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _Heading(
            rowKey: 'profile-group-account',
            text: l10n.profileGroupAccount,
            first: true,
          ),
          _Row(
            rowKey: 'profile-addresses',
            icon: Icons.location_on,
            title: l10n.addressesTitle,
            value: addressLabel,
            large: large,
            line: false,
            onTap: () => context.push(AppPaths.customerAddresses),
          ),
          _Heading(rowKey: 'profile-group-app', text: l10n.profileGroupApp),
          _Row(
            rowKey: 'profile-language',
            icon: Icons.translate,
            title: l10n.profileLanguage,
            value: switch (language) {
              AppLanguage.uz => l10n.languageUzbek,
              AppLanguage.ru => l10n.languageRussian,
              null => null,
            },
            large: large,
            line: false,
            onTap: () => showLanguageSheet(context),
          ),
          FoldingColumn<_HelpItem>(
            items: _helpItems(context, ref, l10n, large, index),
            keyOf: (_HelpItem item) => item.id,
            itemBuilder: (BuildContext context, _HelpItem item) => item.child,
          ),
          if (session is SignedIn) ...<Widget>[
            const SizedBox(height: 24),
            _Row(
              rowKey: 'logout-button',
              title: l10n.logoutButton,
              centered: true,
              chevron: false,
              color: KitColors.danger,
              large: large,
              line: false,
              onTap: onLogout,
            ),
          ],
          // Hidden while the phone also holds a staff session, whose sign-in
          // shares the phone (`DL-96` item 6).
          if (session is SignedIn && session.staffUser == null) ...<Widget>[
            const SizedBox(height: 24),
            _Row(
              rowKey: 'profile-delete',
              icon: Icons.delete,
              title: l10n.profileDeleteAccount,
              hint: l10n.profileDeleteHint,
              color: KitColors.danger,
              large: large,
              chevron: false,
              line: false,
              onTap: () => showDeleteAccountSheet(context),
            ),
          ],
        ],
      ),
    );
  }

  /// The «Помощь» group: its heading and the rows that exist or wait. A row
  /// whose data is not there and not coming is left out and folds away.
  List<_HelpItem> _helpItems(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    bool large,
    AsyncValue<LegalIndex> index,
  ) {
    final String? support = profile.value?.supportPhone;
    final bool hasSupport = support != null && support.isNotEmpty;
    final bool supportWaits = profile.value == null && profile.isLoading;

    final LegalIndex? documents = index.value;
    final bool documentsWait = documents == null && index.isLoading;

    // Each slot: its id, whether it waits, and how to draw it with or
    // without the line under it.
    final List<(String, bool, Widget Function(bool))> slots =
        <(String, bool, Widget Function(bool))>[
          if (hasSupport)
            (
              'support',
              false,
              (bool line) => _Row(
                rowKey: 'profile-support',
                icon: Icons.support_agent,
                title: l10n.profileCallSupport,
                value: formatPhone(support),
                valueUnder: true,
                callMark: true,
                large: large,
                chevron: false,
                line: line,
                onTap: () => _call(context, ref, support),
              ),
            )
          else if (supportWaits)
            (
              'support',
              true,
              (bool line) =>
                  _SkeletonRow(rowKey: 'profile-support-skeleton', line: line),
            ),
          if (documents?.privacy != null)
            (
              'privacy',
              false,
              (bool line) => _Row(
                rowKey: 'profile-privacy',
                icon: Icons.verified_user,
                title: l10n.profilePrivacy,
                large: large,
                line: line,
                onTap: () =>
                    context.push(AppPaths.legal(LegalDocumentKind.privacy)),
              ),
            )
          else if (documentsWait)
            (
              'privacy',
              true,
              (bool line) =>
                  _SkeletonRow(rowKey: 'profile-privacy-skeleton', line: line),
            ),
          if (documents?.terms != null)
            (
              'terms',
              false,
              (bool line) => _Row(
                rowKey: 'profile-terms',
                icon: Icons.description,
                title: l10n.legalTerms,
                large: large,
                line: line,
                onTap: () =>
                    context.push(AppPaths.legal(LegalDocumentKind.terms)),
              ),
            )
          else if (documentsWait)
            (
              'terms',
              true,
              (bool line) =>
                  _SkeletonRow(rowKey: 'profile-terms-skeleton', line: line),
            ),
        ];

    if (slots.isEmpty) {
      return const <_HelpItem>[];
    }
    return <_HelpItem>[
      _HelpItem(
        'heading',
        _Heading(rowKey: 'profile-group-help', text: l10n.profileGroupHelp),
      ),
      for (int i = 0; i < slots.length; i++)
        _HelpItem(
          slots[i].$1,
          _Arrival(
            waiting: slots[i].$2,
            child: slots[i].$3(i < slots.length - 1),
          ),
        ),
    ];
  }

  Future<void> _call(BuildContext context, WidgetRef ref, String phone) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AppLocalizations l10n = AppLocalizations.of(context);
    final bool opened = await ref.read(phoneCallsProvider).call(phone);
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.callFailed(formatPhone(phone)))),
      );
    }
  }
}

/// One entry of the «Помощь» group: the heading or a row, with its drawing.
class _HelpItem {
  const _HelpItem(this.id, this.child);

  final String id;
  final Widget child;
}

/// A group heading, a semantics header.
class _Heading extends StatelessWidget {
  const _Heading({
    required this.rowKey,
    required this.text,
    this.first = false,
  });

  final String rowKey;
  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: ValueKey<String>(rowKey),
      header: true,
      child: Padding(
        padding: EdgeInsets.only(top: first ? 0 : 24, bottom: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: KitColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Fades [child] in over 260 ms when it replaces a waiting skeleton; one that
/// stood from the first frame, or with reduced motion, does not fade.
class _Arrival extends StatefulWidget {
  const _Arrival({required this.waiting, required this.child});

  final bool waiting;
  final Widget child;

  @override
  State<_Arrival> createState() => _ArrivalState();
}

class _ArrivalState extends State<_Arrival>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  @override
  void didUpdateWidget(_Arrival oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.waiting &&
        !widget.waiting &&
        !MediaQuery.disableAnimationsOf(context)) {
      _fade.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _fade, curve: Curves.easeOut),
      child: widget.child,
    );
  }
}

/// A row that waits for its data: a square and a bar.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow({required this.rowKey, required this.line});

  final String rowKey;
  final bool line;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey<String>(rowKey),
      decoration: BoxDecoration(
        border: line
            ? const Border(bottom: BorderSide(color: KitColors.line))
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Row(
          children: <Widget>[
            const SkeletonBar(width: 24, height: 24, radius: 7),
            const SizedBox(width: 16),
            Expanded(
              child: FractionallySizedBox(
                widthFactor: 0.55,
                alignment: Alignment.centerLeft,
                child: const SkeletonBar(width: double.infinity, height: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of the profile: [icon], [title], the [value] at the end (or under
/// the title when [valueUnder] or at large text), a call mark or a chevron.
/// Read out as one button, "title, value".
class _Row extends StatelessWidget {
  const _Row({
    required this.rowKey,
    required this.title,
    required this.large,
    required this.line,
    required this.onTap,
    this.icon,
    this.value,
    this.valueUnder = false,
    this.callMark = false,
    this.chevron = true,
    this.centered = false,
    this.color = KitColors.ink,
    this.hint,
  });

  final String rowKey;
  final IconData? icon;
  final String title;
  final String? value;
  final bool valueUnder;
  final bool callMark;
  final bool chevron;
  final bool centered;
  final Color color;
  final String? hint;
  final bool large;
  final bool line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool under = value != null && (valueUnder || large);
    final bool atEnd = value != null && !under;
    final TextStyle titleStyle = TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: centered ? FontWeight.w600 : FontWeight.w500,
      color: color,
    );

    final Widget text = Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          textAlign: centered ? TextAlign.center : TextAlign.start,
          maxLines: large ? null : 2,
          overflow: large ? TextOverflow.visible : TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (under) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            value!,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: KitColors.muted,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      key: ValueKey<String>(rowKey),
      button: true,
      excludeSemantics: true,
      label: value == null ? title : '$title, $value',
      hint: hint,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: line
                ? const Border(bottom: BorderSide(color: KitColors.line))
                : null,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: <Widget>[
                  if (icon != null) ...<Widget>[
                    Icon(icon, size: 24, color: color),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: text),
                  if (atEnd) ...<Widget>[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Text(
                        value!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          color: KitColors.muted,
                        ),
                      ),
                    ),
                  ],
                  if (callMark) ...<Widget>[
                    const SizedBox(width: 16),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: KitColors.primaryWash,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(
                          Icons.call,
                          size: 20,
                          color: KitColors.primary,
                        ),
                      ),
                    ),
                  ],
                  if (chevron) ...<Widget>[
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.chevron_right,
                      size: 22,
                      color: KitColors.muted,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
