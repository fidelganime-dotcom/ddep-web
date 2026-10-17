import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';

class UsuariosPage extends StatefulWidget {
  const UsuariosPage({super.key});
  @override
  State<UsuariosPage> createState() => _UsuariosPageState();
}

class _UsuariosPageState extends State<UsuariosPage> {
  List<Map<String, dynamic>> _usuarios = [];
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _usuarios = await Api.raw('usuario_sistema',
        columns: '*, rol(nombre), sucursal(nombre)', orderCol: 'id');
    _roles = await Api.raw('rol', columns: '*', orderCol: 'nombre', asc: true);
    if (mounted) setState(() {});
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
          title: Text(u == null ? 'Nuevo usuario' : 'Editar usuario'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre completo')),
                const SizedBox(height: 8),
                TextField(
                    controller: usuario,
                    enabled: u == null,
                    decoration: const InputDecoration(
                        labelText: 'Usuario (login sin @ddep.bo)')),
                const SizedBox(height: 8),
                TextField(
                  controller: pass,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: u == null
                        ? 'Contraseña (mín. 6)'
                        : 'Nueva contraseña (opcional)',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: rolId,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: _roles
                      .map((r) => DropdownMenuItem(
                          value: (r['id'] as num).toInt(),
                          child: Text('${r['nombre']}')))
                      .toList(),
                  onChanged: (v) => setD(() => rolId = v),
                ),
                CheckboxListTile(
                  value: activo,
                  title: const Text('Activo'),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setD(() => activo = v ?? true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      if (u == null) {
        await Api.rpc('sp_crear_usuario', {
          'p_nombre': nombre.text.trim(),
          'p_usuario': usuario.text.trim(),
          'p_password': pass.text,
          'p_rol_id': rolId,
        });
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

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: () => _editar(),
                icon: const Icon(Icons.person_add),
                label: const Text('Nuevo usuario'),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Nombre')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Rol')),
                    DataColumn(label: Text('Activo')),
                    DataColumn(label: Text('Último acceso')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final u in _usuarios)
                      DataRow(cells: [
                        DataCell(Text('${u['id']}')),
                        DataCell(Text('${u['nombre']}')),
                        DataCell(Text('${u['usuario']}')),
                        DataCell(Text('${u['rol']?['nombre'] ?? '—'}')),
                        DataCell(Icon(
                          u['activo'] == true ? Icons.check : Icons.close,
                          color: u['activo'] == true ? Colors.green : Colors.red,
                          size: 18,
                        )),
                        DataCell(Text(u['ultimo_acceso'] != null
                            ? f.format(DateTime.parse(
                                '${u['ultimo_acceso']}'.replaceAll(' ', 'T')))
                            : '—')),
                        DataCell(IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          onPressed: () => _editar(u),
                        )),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
