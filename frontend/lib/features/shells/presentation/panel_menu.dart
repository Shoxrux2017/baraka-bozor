import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/formatting/phone_format.dart';
import '../../../core/localization/app_language.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/role_labels.dart';
import '../../../core/routing/app_paths.dart';
import '../../../core/session/session_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';
import '../../../core/widgets/kit/kit_buttons.dart';
import '../../auth/domain/app_user.dart';
import '../../operations/application/board_controllers.dart';
import '../../operations/domain/board.dart';
import 'panel_shell.dart';

/// The red count beside the board's entry: what needs attention. Nothing when
/// there is none.
Widget panelAttentionBadge(int count) {
  if (count <= 0) {
    return const SizedBox.shrink();
  }
  return Container(
    key: const ValueKey<String>('panel-attention-badge'),
    constraints: const BoxConstraints(minWidth: 22),
    height: 22,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: KitColors.danger,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        fontFamily: appFontFamily,
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// The language control of the panel's menu: offers the same choices and makes
/// the same call as the language button of the other screens, drawn as a box
/// naming the current language, or as an icon alone when [compact].
class PanelLanguageButton extends ConsumerWidget {
  const PanelLanguageButton({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AppLanguage current =
        ref.watch(languageControllerProvider).value ??
        (l10n.localeName == 'ru' ? AppLanguage.ru : AppLanguage.uz);
    final String name = current == AppLanguage.ru
        ? l10n.languageRussian
        : l10n.languageUzbek;

    return PopupMenuButton<AppLanguage>(
      tooltip: l10n.languageLabel,
      initialValue: current,
      padding: EdgeInsets.zero,
      onSelected: (AppLanguage language) =>
          ref.read(languageControllerProvider.notifier).select(language),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<AppLanguage>>[
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.uz,
          checked: current == AppLanguage.uz,
          child: Text(l10n.languageUzbek),
        ),
        CheckedPopupMenuItem<AppLanguage>(
          value: AppLanguage.ru,
          checked: current == AppLanguage.ru,
          child: Text(l10n.languageRussian),
        ),
      ],
      child: Container(
        height: 38,
        width: compact ? 38 : null,
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
        alignment: compact ? Alignment.center : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KitColors.line),
        ),
        child: compact
            ? const Icon(Icons.language, size: 20, color: KitColors.ink2)
            : Row(
                children: <Widget>[
                  const Icon(Icons.language, size: 20, color: KitColors.ink2),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: KitColors.ink2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The panel's side menu: whole, 232 wide, or folded to icons, 76 wide.
class PanelMenu extends ConsumerWidget {
  const PanelMenu({
    required this.sections,
    required this.selected,
    required this.folded,
    required this.onSelect,
    super.key,
  });

  final List<PanelSection> sections;
  final int selected;
  final bool folded;
  final ValueChanged<int> onSelect;

  static const double fullWidth = 232;
  static const double foldedWidth = 76;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const ValueKey<String>('panel-rail'),
      width: folded ? foldedWidth : fullWidth,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: KitColors.line)),
      ),
      child: SafeArea(
        child: _MenuBody(
          sections: sections,
          selected: selected,
          folded: folded,
          onSelect: onSelect,
        ),
      ),
    );
  }
}

/// The same menu, whole, in the drawer of a narrow window; its × closes it.
class PanelDrawerMenu extends ConsumerWidget {
  const PanelDrawerMenu({
    required this.sections,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<PanelSection> sections;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      key: const ValueKey<String>('panel-drawer'),
      width: PanelMenu.fullWidth,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: _MenuBody(
          sections: sections,
          selected: selected,
          folded: false,
          onSelect: onSelect,
          onClose: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

class _MenuBody extends ConsumerWidget {
  const _MenuBody({
    required this.sections,
    required this.selected,
    required this.folded,
    required this.onSelect,
    this.onClose,
  });

  final List<PanelSection> sections;
  final int selected;
  final bool folded;
  final ValueChanged<int> onSelect;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final SessionState? state = ref.watch(sessionControllerProvider).value;
    final AppUser? user = state is SignedIn ? state.activeUser : null;
    final int attention = ref
        .watch(boardSummaryProvider)
        .maybeWhen(
          data: (BoardSummary summary) => summary.attentionCount,
          orElse: () => 0,
        );

    Widget item(int index) {
      final PanelSection section = sections[index];
      return _MenuItem(
        section: section,
        label: section.label(l10n),
        selected: index == selected,
        folded: folded,
        badge: section.path == AppPaths.operations ? attention : 0,
        onTap: () => onSelect(index),
      );
    }

    final Widget header = folded
        ? Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: KitColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'B',
              style: TextStyle(
                fontFamily: appFontFamily,
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const BrandWordmark(size: 19),
                    Text(
                      l10n.panelMenuLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: KitColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: KitColors.ink2),
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: onClose,
                ),
            ],
          );

    final double side = folded ? 14 : 16;
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(side, 20, side, 16),
          child: header,
        ),
        Expanded(
          child: ListView(
            padding: EdgeInsets.symmetric(horizontal: side),
            children: <Widget>[
              for (int i = 0; i < sections.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(height: 4),
                item(i),
              ],
            ],
          ),
        ),
        if (user != null)
          Padding(
            padding: EdgeInsets.fromLTRB(side, 8, side, 16),
            child: folded
                ? _FoldedFooter(
                    user: user,
                    onLogout: () => _logout(ref, state as SignedIn),
                  )
                : _UserFooter(
                    user: user,
                    onLogout: () => _logout(ref, state as SignedIn),
                  ),
          ),
      ],
    );
  }

  void _logout(WidgetRef ref, SignedIn state) =>
      ref.read(sessionControllerProvider.notifier).logout(state.activeMode);
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.section,
    required this.label,
    required this.selected,
    required this.folded,
    required this.badge,
    required this.onTap,
  });

  final PanelSection section;
  final String label;
  final bool selected;
  final bool folded;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget icon = Icon(
      section.icon,
      size: 22,
      color: selected ? KitColors.primaryDark : KitColors.muted,
    );
    final BorderRadius radius = BorderRadius.circular(12);
    final Color wash = selected ? KitColors.primaryWash : Colors.transparent;

    if (folded) {
      return Tooltip(
        message: label,
        child: Center(
          child: SizedBox.square(
            dimension: 48,
            child: Material(
              color: wash,
              borderRadius: radius,
              child: InkWell(
                key: ValueKey<String>('panel-section-${section.path}'),
                borderRadius: radius,
                onTap: onTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    icon,
                    if (badge > 0)
                      Positioned(
                        top: -2,
                        right: -6,
                        child: panelAttentionBadge(badge),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Material(
        color: wash,
        borderRadius: radius,
        child: InkWell(
          key: ValueKey<String>('panel-section-${section.path}'),
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                icon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected ? KitColors.primaryDark : KitColors.ink2,
                    ),
                  ),
                ),
                if (badge > 0) panelAttentionBadge(badge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(AppUser user) {
  final List<String> words = (user.fullName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((String word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) {
    final String phone = user.phone;
    return phone.length >= 2 ? phone.substring(phone.length - 2) : phone;
  }
  return words
      .take(2)
      .map((String word) => String.fromCharCode(word.runes.first))
      .join()
      .toUpperCase();
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.user);

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: KitColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials(user),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: KitColors.primaryDark,
        ),
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            _Avatar(user),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    user.fullName ?? formatPhone(user.phone),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: KitColors.ink,
                    ),
                  ),
                  Text(
                    roleLabel(l10n, user.role),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: KitColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const PanelLanguageButton(),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey<String>('logout-button'),
          style: kitOutlined(height: 38)
              .copyWith(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          icon: const Icon(Icons.logout, size: 18),
          label: Text(l10n.logoutButton),
          onPressed: onLogout,
        ),
      ],
    );
  }
}

class _FoldedFooter extends StatelessWidget {
  const _FoldedFooter({required this.user, required this.onLogout});

  final AppUser user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const PanelLanguageButton(compact: true),
        const SizedBox(height: 12),
        Tooltip(
          message:
              '${user.fullName ?? formatPhone(user.phone)}, '
              '${roleLabel(l10n, user.role)}',
          child: _Avatar(user),
        ),
        const SizedBox(height: 8),
        IconButton(
          key: const ValueKey<String>('logout-button'),
          icon: const Icon(Icons.logout, color: KitColors.ink2),
          tooltip: l10n.logoutButton,
          onPressed: onLogout,
        ),
      ],
    );
  }
}
