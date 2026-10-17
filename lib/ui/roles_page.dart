import 'package:flutter/material.dart';
import '../services/api.dart';
import '../widgets/snack.dart';
import 'tema.dart';

/// Réplica de admin-roles.html: tabla de roles + modal de edición con
/// permisos (checkboxes), validaciones y acciones de sistema.
class RolesPage extends StatefulWidget {
  const RolesPage({super.key});
  @override
  State<RolesPage> createState() => _RolesPageState();
}

class _RolesPageState extends State<RolesPage> {
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _permisos = [];
  Map<int, List<int>> _rolPermisos = {};
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final roles = await Api.raw('rol', orderCol: 'id');
      final perms = await Api.raw('permiso', orderCol: 'id');
      final rp = await Api.raw('rol_permiso');
      final mapa = <int, List<int>>{};
      for (final r in rp) {
        mapa.putIfAbsent((r['rol_id'] as num).toInt(), () => [])
            .add((r['permiso_id'] as num).toInt());
      }
      setState(() {
        _roles = roles;
        _permisos = perms;
        _rolPermisos = mapa;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = Api.err(e);
        _cargando = false;
      });
    }
  }

  String _detallePermiso(List<int> ids) {
    final nombres = [
      for (final id in ids)
        _permisos
            .firstWhere((p) => p['id'] == id,
                orElse: () => {'nombre': '#$id'})['nombre']
            .toString(),
    ];
    final d = nombres.join(', ');
    return d.isEmpty ? 'Sin permisos' : d;
  }

  void _abrirModal({Map<String, dynamic>? rol}) {
    final id = rol?['id'] as int?;
    final nombreCtrl = TextEditingController(text: rol?['nombre'] ?? '');
    final descCtrl = TextEditingController(text: rol?['descripcion'] ?? '');
    final sel = <int>{...?_rolPermisos[id]};
    final soloLectura = rol?['nombre'] == 'ADMIN';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [T.purple1, Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(id != null ? Icons.edit : Icons.key,
                    color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(id != null ? 'Editar rol' : 'Nuevo rol',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          content: SizedBox(
            width: 620,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: nombreCtrl,
                        enabled: id == null,
                        maxLength: 40,
                        decoration: const InputDecoration(
                          labelText: 'Nombre (rol)',
                          hintText: 'Ej: SUPERVISOR',
                          counterText: '',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 7,
                      child: TextFormField(
                        controller: descCtrl,
                        maxLength: 200,
                        decoration: const InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Que hace este rol',
                          counterText: '',
                        ),
                      ),
                    ),
                  ]),
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(Icons.shield, color: T.green1, size: 16),
                      const SizedBox(width: 6),
                      const Expanded(
                          child: Text('Permisos del rol',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700))),
                      OutlinedButton(
                        onPressed: soloLectura
                            ? null
                            : () => setD(() => sel
                                .addAll(_permisos.map((p) => p['id'] as int))),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6)),
                        child: const Text('Todos',
                            style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton(
                        onPressed: soloLectura
                            ? null
                            : () => setD(() => sel.clear()),
                        style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6)),
                        child: const Text('Ninguno',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 320),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: T.tableHover,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.border),
                    ),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final p in _permisos)
                            SizedBox(
                              width: 300,
                              child: CheckboxListTile(
                                dense: true,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                value: sel.contains(p['id']),
                                onChanged: (soloLectura)
                                    ? null
                                    : (v) => setD(() {
                                          if (v == true) {
                                            sel.add(p['id'] as int);
                                          } else {
                                            sel.remove(p['id']);
                                          }
                                        }),
                                title: Text(p['nombre'].toString(),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                                subtitle: Text(
                                    (p['descripcion'] ?? '').toString(),
                                    style: const TextStyle(fontSize: 11)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'El rol ADMIN siempre mantiene la totalidad de los permisos.',
                    style: TextStyle(fontSize: 11, color: T.texto2(context)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            BtnPrimario('Guardar', icon: Icons.check, onPressed: () async {
              try {
                if (id == null && nombreCtrl.text.trim().isEmpty) {
                  snack(ctx, 'Ingrese el nombre del rol', error: true);
                  return;
                }
                if (id == null && sel.isEmpty) {
                  snack(ctx, 'Seleccione al menos un permiso', error: true);
                  return;
                }
                await Api.rpc('sp_guardar_rol', {
                  'p_id': id,
                  'p_nombre': nombreCtrl.text.trim(),
                  'p_descripcion': descCtrl.text.trim(),
                  'p_permiso_ids': sel.toList(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _cargar();
                if (mounted) {
                  snack(context, id != null ? 'Rol actualizado' : 'Rol creado');
                }
              } catch (e) {
                snack(ctx, Api.err(e), error: true);
              }
            }),
          ],
        ),
      ),
    );
  }

  void _eliminar(Map<String, dynamic> rol) {
    final id = rol['id'] as int;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar rol'),
        content: const Text(
            'El rol será eliminado permanentemente. Solo puede eliminarse si no tiene usuarios asignados. ¿Continuar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          BtnPeligro('Confirmar', onPressed: () async {
            try {
              await Api.rpc('sp_eliminar_rol', {'p_id': id});
              if (ctx.mounted) Navigator.pop(ctx);
              _cargar();
              if (mounted) snack(context, 'Rol eliminado');
            } catch (e) {
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) snack(context, Api.err(e), error: true);
            }
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      const Icon(Icons.key, color: T.purple1, size: 26),
                      const SizedBox(width: 10),
                      Text('Roles y permisos',
                          style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: T.texto(context))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.shield,
                          color: T.darkText2, size: 16),
                      const SizedBox(width: 8),
                      Text(
                          'Defina qué puede hacer cada rol en el sistema',
                          style: TextStyle(
                              fontSize: 16, color: T.texto2(context))),
                    ],
                  ),
                ],
              ),
            ),
            BtnSecundario('Actualizar',
                icon: Icons.refresh, onPressed: _cargar),
            const SizedBox(width: 8),
            BtnPrimario('Nuevo rol',
                icon: Icons.add, onPressed: () => _abrirModal()),
          ],
        ),
        const SizedBox(height: 16),
        // Tabla
        SoftCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: CardHeaderSection(
                  icon: Icons.account_tree,
                  titulo: 'Roles registrados',
                  acciones: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_roles.length}',
                        style: const TextStyle(
                            color: Color(0xFF4338CA),
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                  ),
                ),
              ),
              if (_cargando)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(_error!,
                      style: const TextStyle(color: T.red1)),
                )
              else if (_roles.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('Sin roles',
                      style: TextStyle(color: T.texto2(context))),
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: TablaModerna(
                    anchoTotal: 950,
                    columnas: const [
                      'Rol',
                      'Descripción',
                      'Permisos',
                      'Tipo',
                      'Acciones'
                    ],
                    filas: [
                      for (final r in _roles)
                        DataRow(cells: [
                          DataCell(Text(r['nombre'].toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold))),
                          DataCell(SizedBox(
                              width: 260,
                              child: Text(
                                  (r['descripcion'] ?? '—').toString(),
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius:
                                        BorderRadius.circular(20)),
                                child: Text(
                                    '${_rolPermisos[r['id']]?.length ?? 0}',
                                    style: const TextStyle(
                                        color: T.green2,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12)),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 260,
                                child: Text(
                                  _detallePermiso(_rolPermisos[r['id']] ??
                                      const []),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: T.texto2(context)),
                                ),
                              ),
                            ],
                          )),
                          DataCell(Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: r['es_sistema'] == true
                                  ? const Color(0xFFEEF2FF)
                                  : T.tableHover,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                                r['es_sistema'] == true
                                    ? 'Sistema'
                                    : 'Personalizado',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: r['es_sistema'] == true
                                        ? const Color(0xFF4338CA)
                                        : const Color(0xFF475569))),
                          )),
                          DataCell(Row(children: [
                            IconButton(
                              tooltip: 'Editar',
                              icon: Icon(Icons.edit,
                                  size: 17, color: T.texto2(context)),
                              onPressed: () => _abrirModal(rol: r),
                            ),
                            if (r['es_sistema'] != true)
                              IconButton(
                                tooltip: 'Eliminar',
                                icon: const Icon(Icons.delete,
                                    size: 17, color: T.red1),
                                onPressed: () => _eliminar(r),
                              ),
                          ])),
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
