import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_localizations.dart';

/// Flutter's [GlobalMaterialLocalizations] does not include Somali (`so`).
/// Without [MaterialLocalizations], widgets such as [AppBar] throw at runtime.
/// This delegate supplies English Material strings while [AppLocalizations] stays Somali.
class KpmsSoMaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const KpmsSoMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(KpmsSoMaterialLocalizationsDelegate old) => false;
}

/// Same gap for Cupertino widgets — `so` is not in Flutter's Cupertino set.
class KpmsSoCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const KpmsSoCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'so';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(const Locale('en'));

  @override
  bool shouldReload(KpmsSoCupertinoLocalizationsDelegate old) => false;
}

/// KPMS ARB + Somali fallbacks for stock Flutter delegates + widgets.
List<LocalizationsDelegate<dynamic>> get kpmsLocalizationsDelegates => <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      const KpmsSoMaterialLocalizationsDelegate(),
      GlobalMaterialLocalizations.delegate,
      const KpmsSoCupertinoLocalizationsDelegate(),
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ];
