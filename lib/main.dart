import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/catalog.dart';
import 'core/i18n.dart';
import 'core/theme.dart';
import 'screens/onboarding.dart';
import 'screens/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([I18n.load(), Catalog.load()]);
  for (final l in I18n.langs.values) {
    await initializeDateFormatting(l.$2);
  }
  final state = AppState();
  await state.load();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(ChangeNotifierProvider.value(value: state, child: const CoachlessApp()));
}

class CoachlessApp extends StatelessWidget {
  const CoachlessApp({super.key});
  @override
  Widget build(BuildContext context) {
    final st = context.watch<AppState>();
    final theme = st.profile?.theme ?? 'm';
    return MaterialApp(
      title: 'Coachless',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(theme),
      home: st.registered ? const Shell() : const OnboardingScreen(),
    );
  }
}
