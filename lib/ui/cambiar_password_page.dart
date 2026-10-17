import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';
import 'tema.dart';

/// Réplica de cambiar-password.html: aviso de seguridad, formulario con
/// contraseña actual / nueva / repetición y reglas visibles de la contraseña.
class CambiarPasswordPage extends StatefulWidget {
  const CambiarPasswordPage({super.key});
  @override
  State<CambiarPasswordPage> createState() => _CambiarPasswordPageState();
}

class _CambiarPasswordPageState extends State<CambiarPasswordPage> {
  final _actual = TextEditingController();
  final _n1 = TextEditingController();
  final _n2 = TextEditingController();
  String? _error;
  bool _busy = false;

  void _falla(String msg, {bool error = true}) {
    setState(() => _error = msg);
    snack(context, msg, error: error);
  }

  Future<void> _guardar() async {
    if (_actual.text.isEmpty || _n1.text.isEmpty || _n2.text.isEmpty) {
      _falla('Complete los tres campos', error: false);
      return;
    }
    if (_n1.text.length < 6) {
      _falla('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (_n1.text != _n2.text) {
      _falla('Las contraseñas no coinciden');
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
      if (mounted) snack(context, 'Contraseña actualizada. Redirigiendo...');
    } catch (e) {
      final msg = Api.err(e);
      if (mounted) {
        setState(() => _error = msg);
        snack(context, msg, error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SoftCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _TituloSeccion(
                      icon: Icons.lock,
                      color: Color(0xFFF59E0B),
                      titulo: 'Cambiar mi contraseña'),
                  // alert-warning
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF59E0B),
                      border: Border.all(color: const Color(0x33F59E0B)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber,
                            size: 16, color: Color(0xFFD97706)),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Por seguridad debe definir una contraseña propia antes de continuar usando el sistema.',
                            style: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Color(0xFFD97706)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Contraseña actual
                  const _EtiquetaCampo(
                      icon: Icons.lock,
                      color: Color(0xFFEF4444),
                      texto: 'Contraseña actual'),
                  TextField(
                    controller: _actual,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  // Nueva contraseña
                  const _EtiquetaCampo(
                      icon: Icons.lock,
                      color: Color(0xFF3B82F6),
                      texto: 'Nueva contraseña'),
                  TextField(
                    controller: _n1,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(),
                  ),
                  const SizedBox(height: 16),
                  // Repetir nueva contraseña
                  const _EtiquetaCampo(
                      icon: Icons.lock,
                      color: Color(0xFF10B981),
                      texto: 'Repetir nueva contraseña'),
                  TextField(
                    controller: _n2,
                    obscureText: true,
                    autofillHints: const [AutofillHints.newPassword],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _guardar(),
                    decoration: const InputDecoration(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!,
                        style:
                            const TextStyle(fontSize: 12.5, color: T.red1)),
                  ],
                  const SizedBox(height: 16),
                  // Reglas visibles
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('La contraseña debe:',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B))),
                        const SizedBox(height: 4),
                        for (final r in const [
                          'Tener entre 8 y 64 caracteres.',
                          'Incluir al menos una letra y un número.',
                          'No contener espacios ni ser igual a su usuario.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(
                                  width: 16,
                                  child: Text('•',
                                      style: TextStyle(
                                          fontSize: 13.5,
                                          color: Color(0xFF64748B))),
                                ),
                                Expanded(
                                  child: Text(r,
                                      style: const TextStyle(
                                          fontSize: 13.5,
                                          height: 1.4,
                                          color: Color(0xFF64748B))),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BtnPrimario('Guardar contraseña',
                          icon: Icons.check,
                          cargando: _busy,
                          onPressed: _guardar),
                      const SizedBox(width: 12),
                      BtnSecundario('Salir sin cambiar',
                          icon: Icons.logout,
                          onPressed: () => sesionOf(context).salir()),
                    ],
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

// ------------------------------------------------------------ widgets

/// `.card-header-section` de cambiar-password.html.
class _TituloSeccion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  const _TituloSeccion(
      {required this.icon, required this.color, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.borde(context)))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: T.texto(context))),
          ),
        ],
      ),
    );
  }
}

/// `.form-label` con ícono de color exacto del HTML.
class _EtiquetaCampo extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;
  const _EtiquetaCampo(
      {required this.icon, required this.color, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: T.texto(context))),
          ),
        ],
      ),
    );
  }
}
