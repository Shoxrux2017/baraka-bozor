import 'package:flutter/material.dart';

import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/localization/language_menu.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/kit_colors.dart';
import '../../../core/widgets/brand_wordmark.dart';

/// The frame of every screen outside a role shell (`kit/01-vhod`): a white
/// page with 24 px sides, the language switch top-right, the wordmark, a
/// title and a subtitle, then the screen's own content. One column that stays
/// readable on a phone and in a browser window alike, and scrolls rather than
/// overflows on a small screen or with large text.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.child,
    this.subtitle,
    this.onBack,
    this.footer,
    this.wordmark = true,
    this.card = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Shows a back arrow top-left that calls this.
  final VoidCallback? onBack;

  /// Pinned to the bottom of the page when there is room, else below the
  /// content.
  final Widget? footer;

  final bool wordmark;

  /// Puts the title and the content on a white card over a light page, as
  /// the kit's modal screens do. The wordmark is left out.
  final bool card;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: card ? _cardPage : Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _ScrollingPage(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              spread: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _TopBar(onBack: onBack),
                    if (card)
                      _Card(
                        child: _Header(
                          title: title,
                          subtitle: subtitle,
                          spaced: false,
                          child: child,
                        ),
                      )
                    else ...<Widget>[
                      if (wordmark) ...<Widget>[
                        const SizedBox(height: 8),
                        const Center(child: BrandWordmark(size: 26)),
                      ],
                      SizedBox(height: wordmark ? 36 : 28),
                      _Header(title: title, subtitle: subtitle, child: child),
                    ],
                  ],
                ),
                if (footer != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: footer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A page column that is at least as tall as the screen, so its [spread]
/// can pin a footer to the bottom, and that scrolls when its content is
/// taller: a small screen or large text never overflows.
class _ScrollingPage extends StatelessWidget {
  const _ScrollingPage({
    required this.padding,
    required this.spread,
    required this.children,
  });

  final EdgeInsets padding;
  final MainAxisAlignment spread;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: padding,
              child: Column(
                mainAxisAlignment: spread,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The outlined green button of the sign-in screens: the filled button's
/// size and shape, a green outline and green text.
final ButtonStyle authOutlinedButtonStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 56),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
  foregroundColor: KitColors.primary,
  side: const BorderSide(color: KitColors.primary),
);

/// A status screen of the kit: a green halo with an icon, a title, a line of
/// text and one button (`kit/01-vhod` screens 09 and 10).
class AuthStatusScaffold extends StatelessWidget {
  const AuthStatusScaffold({
    required this.icon,
    required this.title,
    required this.body,
    required this.button,
    this.bodyKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget button;
  final Key? bodyKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _ScrollingPage(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              spread: MainAxisAlignment.center,
              children: <Widget>[
                Center(child: StatusHalo(icon: icon)),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: appFontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      height: 1.25,
                      color: KitColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  key: bodyKey,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: KitColors.muted,
                  ),
                ),
                const SizedBox(height: 32),
                button,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 130 px soft-green circle with a 90 px green circle and a white icon.
class StatusHalo extends StatelessWidget {
  const StatusHalo({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 130,
        height: 130,
        decoration: const BoxDecoration(
          color: KitColors.primaryWash,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(
            color: KitColors.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 44, color: Colors.white),
        ),
      ),
    );
  }
}

const Color _cardPage = Color(0xFFF3F4F3);

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 30,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The title, the subtitle and the content of a sign-in screen.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.child,
    this.spaced = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final bool spaced;

  @override
  Widget build(BuildContext context) {
    final String? subtitle = this.subtitle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: appFontFamily,
              fontWeight: FontWeight.w700,
              fontSize: 24,
              height: 1.25,
              color: KitColors.ink,
            ),
          ),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: KitColors.muted,
            ),
          ),
        ],
        SizedBox(height: spaced ? 32 : 24),
        child,
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onBack = this.onBack;
    return Row(
      children: <Widget>[
        if (onBack != null)
          _CircleButton(
            child: IconButton(
              key: const ValueKey<String>('auth-back-button'),
              onPressed: onBack,
              tooltip: AppLocalizations.of(context).back,
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
          ),
        const Spacer(),
        const _CircleButton(child: LanguageMenuButton()),
      ],
    );
  }
}

/// A 40 px circle with a hairline border around one icon button.
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: KitColors.line),
      ),
      child: ClipOval(child: Center(child: child)),
    );
  }
}
