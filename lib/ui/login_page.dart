import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api.dart';
import '../services/sesion.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPass = false;

  Future<void> _entrar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _user.text.trim().contains('@')
          ? _user.text.trim()
          : '${_user.text.trim()}@ddep.bo';
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _pass.text,
      );
      await sesionOf(context).cargar();
    } catch (e) {
      setState(() => _error = 'Credenciales inválidas');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance,
                        size: 56, color: Color(0xFF1F3864)),
                    const SizedBox(height: 12),
                    Text('DDEP Pando',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1F3864))),
                    Text('Venta de Valores y Control de Caja',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person),
                        hintText: 'admin',
                      ),
                      onSubmitted: (_) => _entrar(),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: !_showPass,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_showPass
                              ? Icons.visibility_off
                              : Icons.visibility),
                          onPressed: () =>
                              setState(() => _showPass = !_showPass),
                        ),
                      ),
                      onSubmitted: (_) => _entrar(),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: FilledButton(
                        onPressed: _busy ? null : _entrar,
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Ingresar'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Universidad Amazónica de Pando — Gestión 2026',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
