import 'package:flutter/widgets.dart';

import 'app_language.dart';

/// The interface language of [context], for names and money.
AppLanguage interfaceLanguage(BuildContext context) =>
    AppLanguage.tryParse(Localizations.localeOf(context).languageCode) ??
    AppLanguage.uz;
