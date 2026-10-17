import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';
import 'tema.dart';

/// Réplica de admin-usuarios.html: listado de usuarios con badges de estado,
/// modal de creación/edición y modal de contraseña temporal.
class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _roles = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _cargando = true;
    try {
      _usuarios = await Api.raw('usuario_sistema',
          columns: '*, rol(nombre), sucursal(nombre)', orderCol: 'id');
      _roles = await Api.raw('rol',
          columns: '*', orderCol: 'nombre', asc: true);
    } finally {
      _cargando = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _editar([Map<String, dynamic>? u]) async {
    final nombre = TextEditingController(text: u?['nombre']?.toString() ?? '');
    final usuario = TextEditingController(text: u?['usuario']?.toString() ?? '');
    final pass = TextEditingController();
    int? rolId = (u?['rol_id'] as num?)?.toInt();
    bool activo = (u?['activo'] ?? true) as bool;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E3A5F)]),
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
            child: Row(
              children: [
                Icon(u == null ? Icons.person : Icons.manage_accounts,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(u == null ? 'Nuevo usuario' : 'Editar usuario',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          content: SizedBox(
            width: 380,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _EtiquetaCampo(
                      icon: Icons.person,
                      color: Color(0xFF3B82F6),
                      texto: 'Nombre completo'),
                  TextField(
                      controller: nombre,
                      decoration: const InputDecoration(
                          hintText: 'Ej: Maria Lopez')),
                  const SizedBox(height: 16),
                  const _EtiquetaCampo(
                      icon: Icons.alternate_email,
                      color: Color(0xFF10B981),
                      texto: 'Usuario (login)'),
                  TextField(
                    controller: usuario,
                    enabled: u == null,
                    maxLength: 30,
                    decoration: const InputDecoration(
                        hintText: 'minusculas, numeros, punto o guion',
                        counterText: ''),
                  ),
                  const SizedBox(height: 16),
                  const _EtiquetaCampo(
                      icon: Icons.key,
                      color: Color(0xFFF59E0B),
                      texto: 'Rol'),
                  DropdownButtonFormField<int>(
                    value: rolId,
                    items: _roles
                        .map((r) => DropdownMenuItem(
                            value: (r['id'] as num).toInt(),
                            child: Text('${r['nombre']}')))
                        .toList(),
                    onChanged: (v) => setD(() => rolId = v),
                  ),
                  if (u == null) ...[
                    const SizedBox(height: 16),
                    const _EtiquetaCampo(
                        icon: Icons.lock,
                        color: Color(0xFF8B5CF6),
                        texto: 'Contraseña inicial (opcional)'),
                    TextField(
                      controller: pass,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Vacío: se genera una contraseña temporal',
                        helperMaxLines: 3,
                        helperStyle: TextStyle(
                            fontSize: 12.5, color: T.texto2(context)),
                        helperText:
                            'Mínimo 8 caracteres, con letra y número. El usuario deberá cambiarla al iniciar sesión.',
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: activo,
                        visualDensity: VisualDensity.compact,
                        onChanged: (v) => setD(() => activo = v ?? true),
                      ),
                      const Icon(Icons.check_circle,
                          color: Color(0xFF10B981), size: 16),
                      const SizedBox(width: 6),
                      const Text('Usuario activo',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            BtnSecundario('Cancelar',
                onPressed: () => Navigator.pop(ctx, false)),
            BtnPrimario('Guardar', icon: Icons.check,
                onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (u == null) {
        final res = await Api.rpc('sp_crear_usuario', {
          'p_nombre': nombre.text.trim(),
          'p_usuario': usuario.text.trim(),
          'p_password': pass.text,
          'p_rol_id': rolId,
        });
        final temp = res['passwordTemporal'] ?? res['password_temporal'];
        if (temp is String && temp.isNotEmpty && mounted) {
          _mostrarPasswordTemporal(temp);
        }
      } else {
        await Api.c.from('usuario_sistema').update({
          'nombre': nombre.text.trim(),
          'rol_id': rolId,
          'activo': activo,
        }).eq('id', u['id']);
        if (pass.text.isNotEmpty && u['auth_uid'] != null) {
          // cambio vía SQL directo no disponible desde cliente con anon;
          // se usa RPC si existe; si no, el usuario cambia su password en sesión.
          snack(context,
              'Usuario guardado. Para cambiar su contraseña, que él inicie sesión y use "Cambiar contraseña".');
        }
      }
      if (mounted) {
        snack(context, 'Usuario guardado');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  void _restablecer(Map<String, dynamic> u) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restablecer contraseña'),
        content: Text(
            'Se generará una contraseña temporal para ${u['usuario']}. Deberá cambiarla al iniciar sesión. ¿Continuar?'),
        actions: [
          BtnSecundario('Cancelar', onPressed: () => Navigator.pop(ctx)),
          BtnPrimario('Confirmar', icon: Icons.key, onPressed: () {
            Navigator.pop(ctx);
            snack(context, 'Restablecer contraseña no disponible en la versión web',
                error: true);
          }),
        ],
      ),
    );
  }

  void _mostrarPasswordTemporal(String pw) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: const Row(
            children: [
              Icon(Icons.key, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Contraseña temporal',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 13, color: T.texto2(context), height: 1.5),
                  children: [
                    const TextSpan(
                        text:
                            'Entregue esta contraseña al usuario. Se muestra '),
                    const TextSpan(
                        text: 'una sola vez',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const TextSpan(
                        text: ' y no vuelve a estar disponible.'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: T.tableHover,
                  border: Border.all(color: const Color(0xFF94A3B8)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectableText(
                  pw,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      color: T.texto(context)),
                ),
              ),
            ],
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          BtnSecundario('Copiar',
              icon: Icons.copy,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: pw));
                if (ctx.mounted) {
                  snack(ctx, 'Contraseña copiada al portapapeles');
                }
              }),
          BtnPrimario('Entendido', icon: Icons.check,
              onPressed: () => Navigator.pop(ctx)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera de página
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.people,
                          color: Color(0xFF3B82F6), size: 30),
                      const SizedBox(width: 10),
                      Text('Usuarios',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: T.texto(context))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.badge,
                          color: Color(0xFF94A3B8), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                            'Gestión de cuentas, roles y restablecimiento de contraseñas',
                            style: TextStyle(
                                fontSize: 16, color: T.texto2(context))),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            BtnSecundario('Actualizar', icon: Icons.refresh, onPressed: _cargar),
            const SizedBox(width: 8),
            BtnPrimario('Nuevo usuario',
                icon: Icons.person_add, onPressed: () => _editar()),
          ],
        ),
        const SizedBox(height: 16),
        // Listado
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: _CabeceraSeccion(
                  icon: Icons.table_chart,
                  color: const Color(0xFF10B981),
                  titulo: 'Listado de usuarios',
                  acciones: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: const BoxDecoration(
                        color: Color(0xFFEEF2FF),
                        borderRadius:
                            BorderRadius.all(Radius.circular(20))),
                    child: Text('${_usuarios.length}',
                        style: const TextStyle(
                            color: Color(0xFF4338CA),
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                  ),
                ),
              ),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('Cargando usuarios...',
                          style: TextStyle(color: T.textSecondary))),
                )
              else if (_usuarios.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                      child: Text('Sin usuarios',
                          style: TextStyle(color: T.textSecondary))),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: TablaModerna(
                    anchoTotal: 1050,
                    columnas: const [
                      'Usuario',
                      'Nombre',
                      'Rol',
                      'Estado',
                      'Último acceso',
                      'Acciones'
                    ],
                    filas: [
                      for (final u in _usuarios)
                        DataRow(cells: [
                          DataCell(Text('${u['usuario']}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          DataCell(Text('${u['nombre']}')),
                          DataCell(_BadgeColor(
                            texto: '${u['rol']?['nombre'] ?? '—'}',
                            bg: const Color(0xFFEEF2FF),
                            color: const Color(0xFF4338CA),
                          )),
                          DataCell(Row(
                            children: [
                              if (u['activo'] == true)
                                const _BadgeColor(
                                  texto: 'Activo',
                                  bg: Color(0xFFDCFCE7),
                                  color: Color(0xFF16A34A),
                                )
                              else
                                const _BadgeColor(
                                  texto: 'Inactivo',
                                  bg: Color(0xFFFEE2E2),
                                  color: Color(0xFFDC2626),
                                ),
                              if (u['debe_cambiar_password'] == true) ...[
                                const SizedBox(width: 6),
                                const _BadgeColor(
                                  texto: 'Cambiar contraseña',
                                  bg: Color(0xFFFEF3C7),
                                  color: Color(0xFFB45309),
                                ),
                              ],
                            ],
                          )),
                          DataCell(u['ultimo_acceso'] != null
                              ? Text(f.format(DateTime.parse(
                                  '${u['ultimo_acceso']}'
                                      .replaceAll(' ', 'T'))))
                              : Text('Nunca',
                                  style: TextStyle(color: T.texto2(context)))),
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _BotonIcono(
                                icon: Icons.edit,
                                tooltip: 'Editar',
                                onPressed: () => _editar(u),
                              ),
                              const SizedBox(width: 6),
                              _BotonIcono(
                                icon: Icons.key,
                                tooltip: 'Restablecer contraseña',
                                onPressed: () => _restablecer(u),
                              ),
                            ],
                          )),
                        ]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------ widgets

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

/// `.card-header-section` con el color de ícono exacto del HTML.
class _CabeceraSeccion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final Widget? acciones;
  const _CabeceraSeccion(
      {required this.icon,
      required this.color,
      required this.titulo,
      this.acciones});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          if (acciones != null) acciones!,
        ],
      ),
    );
  }
}

/// `.badge` con los colores exactos del HTML.
class _BadgeColor extends StatelessWidget {
  final String texto;
  final Color bg;
  final Color color;
  const _BadgeColor(
      {required this.texto, required this.bg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.all(Radius.circular(20))),
      child: Text(texto,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: .2)),
    );
  }
}

/// `.btn-outline-custom.btn-sm` con solo ícono (acciones de la tabla).
class _BotonIcono extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const _BotonIcono(
      {required this.icon, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: T.accent.withOpacity(.45)),
            color: T.accent.withOpacity(.08),
          ),
          child: Icon(icon, size: 16, color: T.accent),
        ),
      ),
    );
  }
}
