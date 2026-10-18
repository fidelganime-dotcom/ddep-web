import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/sesion.dart';
import 'ui/login_page.dart';
import 'ui/shell.dart';
import 'ui/tema.dart';
import 'ui/cambiar_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  runApp(const DdepApp());
}

class DdepApp extends StatelessWidget {
  const DdepApp({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = Sesion();
    return SesionScope(
      sesion: sesion,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: modoTema,
        builder: (_, modo, __) => MaterialApp(
          title: 'DDEP',
          debugShowCheckedModeBanner: false,
          theme: temaClaro(),
          darkTheme: temaOscuro(),
          themeMode: modo,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('es', 'BO')],
          locale: const Locale('es', 'BO'),
          home: const Puerta(),
        ),
      ),
    );
  }
}

class Puerta extends StatefulWidget {
  const Puerta({super.key});
  @override
  State<Puerta> createState() => _PuertaState();
}

class _PuertaState extends State<Puerta> {
  late final Stream<AuthState> _stream;

  @override
  void initState() {
    super.initState();
    _stream = Supabase.instance.client.auth.onAuthStateChange;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Supabase.instance.client.auth.currentSession != null &&
        sesionOf(context).perfil == null) {
      sesionOf(context).cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _stream,
      builder: (context, snap) {
        final sesion = sesionOf(context);
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          sesion.perfil = null;
          return const LoginPage();
        }
        if (sesion.perfil == null) {
          sesion.cargar();
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (sesion.perfil!.debeCambiarPassword) {
          return const CambiarPasswordPage();
        }
        return const Shell();
      },
    );
  }
}
