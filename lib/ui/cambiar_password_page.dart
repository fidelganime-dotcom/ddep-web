import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api.dart';
import '../services/sesion.dart';

class CambiarPasswordPage extends StatefulWidget {
  const CambiarPasswordPage({super.key});
  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage> {
  final _n1 = TextEditingController();
  final _n2 = TextEditingController();
  String? _error;
  bool _busy = false;

  Future<void> _guardar() async {
    if (_n1.text.length < 6) {
      setState(() => _error = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (_n1.text != _n2.text) {
      setState(() => _error = 'Las contraseñas no coinciden');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _n1.text),
      );
      await Api.rpc('sp_password_cambiado');
      await sesionOf(context).cargar();
    } catch (e) {
      setState(() => _error = Api.err(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_reset,
                      size: 48, color: Color(0xFF1F3864)),
                  const SizedBox(height: 12),
                  Text('Cambiar contraseña',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _n1,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Nueva contraseña'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _n2,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: 'Repetir contraseña'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _guardar,
                      child: const Text('Guardar'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => sesionOf(context).salir(),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
