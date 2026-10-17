import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';

class CatalogosPage extends StatefulWidget {
  const CatalogosPage({super.key});
  @override
  State<CatalogosPage> createState() => _CatalogosPageState();
}

class _CatalogosPageState extends State<CatalogosPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TabBar(tabs: [Tab(text: 'Ítems'), Tab(text: 'Trámites')]),
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 180,
          child: TabBarView(
            controller: _tab,
            children: const [_ItemsTab(), _TramitesTab()],
          ),
        ),
      ],
    );
  }
}

class _ItemsTab extends StatefulWidget {
  const _ItemsTab();
  @override
  State<_ItemsTab> createState() => _ItemsTabState();
}

class _ItemsTabState extends State<_ItemsTab> {
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _items = await Api.raw('item_valorado',
        columns: '*', orderCol: 'codigo', asc: true);
    if (mounted) setState(() {});
  }

  Future<void> _editar([Map<String, dynamic>? item]) async {
    final codigo = TextEditingController(text: item?['codigo']?.toString() ?? '');
    final desc = TextEditingController(text: item?['descripcion']?.toString() ?? '');
    final precio = TextEditingController(
        text: item != null ? '${item['precio_unitario_vigente']}' : '');
    final um = TextEditingController(text: item?['unidad_medida']?.toString() ?? 'UND');
    bool activo = (item?['activo'] ?? true) as bool;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(item == null ? 'Nuevo ítem' : 'Editar ítem'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: codigo,
                    decoration: const InputDecoration(labelText: 'Código')),
                const SizedBox(height: 8),
                TextField(
                    controller: desc,
                    decoration: const InputDecoration(labelText: 'Descripción')),
                const SizedBox(height: 8),
                TextField(
                    controller: precio,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Precio vigente (Bs)')),
                const SizedBox(height: 8),
                TextField(
                    controller: um,
                    decoration:
                        const InputDecoration(labelText: 'Unidad de medida')),
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
      final data = {
        'codigo': codigo.text.trim(),
        'descripcion': desc.text.trim(),
        'precio_unitario_vigente': double.parse(precio.text),
        'unidad_medida': um.text.trim(),
        'activo': activo,
      };
      if (item == null) {
        await Api.c.from('item_valorado').insert(data);
      } else {
        await Api.c.from('item_valorado').update(data).eq('id', item['id']);
      }
      if (mounted) {
        snack(context, 'Ítem guardado (solo ADMIN puede modificar)');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final admin = rol == 'ADMIN';
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (admin)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _editar(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo ítem'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Código')),
                    DataColumn(label: Text('Descripción')),
                    DataColumn(label: Text('Precio')),
                    DataColumn(label: Text('U.M.')),
                    DataColumn(label: Text('Activo')),
                    DataColumn(label: Text('')),
                  ],
                  rows: [
                    for (final i in _items)
                      DataRow(cells: [
                        DataCell(Text('${i['codigo']}')),
                        DataCell(Text('${i['descripcion']}')),
                        DataCell(Text(f.format(i['precio_unitario_vigente'] ?? 0))),
                        DataCell(Text('${i['unidad_medida']}')),
                        DataCell(Icon(
                          i['activo'] == true ? Icons.check : Icons.close,
                          color: i['activo'] == true ? Colors.green : Colors.red,
                          size: 18,
                        )),
                        DataCell(admin
                            ? IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editar(i),
                              )
                            : const SizedBox.shrink()),
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

class _TramitesTab extends StatefulWidget {
  const _TramitesTab();
  @override
  State<_TramitesTab> createState() => _TramitesTabState();
}

class _TramitesTabState extends State<_TramitesTab> {
  List<Map<String, dynamic>> _tramites = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _tramites = await Api.raw('tramite',
        columns: '*', orderCol: 'nombre', asc: true);
    if (mounted) setState(() {});
  }

  Future<void> _editar([Map<String, dynamic>? t]) async {
    final nombre = TextEditingController(text: t?['nombre']?.toString() ?? '');
    final desc = TextEditingController(text: t?['descripcion']?.toString() ?? '');
    final tarifa = TextEditingController(
        text: t != null ? '${t['tarifa']}' : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t == null ? 'Nuevo trámite' : 'Editar trámite'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nombre,
                  decoration: const InputDecoration(labelText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(
                  controller: desc,
                  decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 8),
              TextField(
                  controller: tarifa,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tarifa (Bs)')),
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
    );
    if (ok != true) return;
    try {
      final data = {
        'nombre': nombre.text.trim(),
        'descripcion': desc.text.trim(),
        'tarifa': double.tryParse(tarifa.text) ?? 0,
        'activo': true,
      };
      if (t == null) {
        await Api.c.from('tramite').insert(data);
      } else {
        await Api.c.from('tramite').update(data).eq('id', t['id']);
      }
      if (mounted) {
        snack(context, 'Trámite guardado');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = sesionOf(context).perfil?.rol == 'ADMIN';
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (admin)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => _editar(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nuevo trámite'),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: [
                  for (final t in _tramites)
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: Text('${t['nombre']}'),
                      subtitle: Text('${t['descripcion'] ?? ''}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bs ${f.format(t['tarifa'] ?? 0)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          if (admin)
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              onPressed: () => _editar(t),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
