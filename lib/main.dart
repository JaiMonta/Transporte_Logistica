import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/env.dart';
import 'core/router.dart';
import 'core/supabase_client.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.estaConfigurado) {
    await initSupabase();
  }
  runApp(const ProviderScope(child: AppLogistica()));
}

class AppLogistica extends ConsumerWidget {
  const AppLogistica({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.estaConfigurado) return const _ConfigFaltante();

    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Logística',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      locale: const Locale('es'),
      supportedLocales: const [Locale('es'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

class _ConfigFaltante extends StatelessWidget {
  const _ConfigFaltante();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_suggest_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  'Falta la configuración',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Define SUPABASE_URL y SUPABASE_ANON_KEY al ejecutar:\n'
                  'flutter run --dart-define-from-file=env.json',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
