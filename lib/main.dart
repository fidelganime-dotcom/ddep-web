import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/sesion.dart';
import 'ui/login_page.dart';
import 'ui/shell.dart';
import 'ui/cambiar_password_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      child: MaterialApp(
        title: 'DDEP Pando',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1F3864),
            primary: const Color(0xFF1F3864),
            secondary: const Color(0xFFC9A227),
          ),
          scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            isDense: true,
          ),
          cardTheme: const CardThemeData(
            elevation: 1,
            margin: EdgeInsets.symmetric(vertical: 6),
          ),
        ),
        home: const Puerta(),
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
