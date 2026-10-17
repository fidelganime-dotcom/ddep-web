import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});
  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    final rol = sesionOf(context).perfil?.rol ?? '';
    final n = rol == 'AUDITOR' ? 2 : 4;
    _tab = TabController(length: n, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final soloLectura = rol == 'AUDITOR';
    final tabs = <Widget>[
      const Tab(text: 'Kardex'),
      const Tab(text: 'Arqueo físico'),
      if (!soloLectura) const Tab(text: 'Pedidos'),
      if (!soloLectura) const Tab(text: 'Apertura inv.'),
    ];
    final views = <Widget>[
      const _KardexTab(),
      const _ArqueoTab(),
      if (!soloLectura) const _PedidosTab(),
      if (!soloLectura) const _AperturaTab(),
    ];
    return Column(
      children: [
        TabBar(controller: _tab, tabs: tabs),
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 180,
          child: TabBarView(controller: _tab, children: views),
        ),
      ],
    );
  }
}

Future<List<Map<String, dynamic>>> cargarCatalogoItems() =>
    Api.raw('item_valorado',
        columns: 'id,codigo,descripcion,precio_unitario_vigente,activo',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);

class _KardexTab extends StatefulWidget {
  const _KardexTab();
  @override
  State<_KardexTab> createState() => _KardexTabState();
}

class _KardexTabState extends State<_KardexTab> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _sel;
  List<Map<String, dynamic>> _movs = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarItems();
  }

  Future<void> _cargarItems() async {
    _items = await cargarCatalogoItems();
    if (mounted) setState(() {});
  }

  Future<void> _ver(Map<String, dynamic> item) async {
    setState(() {
      _sel = item;
      _cargando = true;
    });
    _movs = await Api.raw('movimiento_inventario',
        columns: '*, referencia_venta:venta(numero_recibo)',
        eqField: 'item_id',
        eqVal: item['id'],
        orderCol: 'id');
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 420,
              child: DropdownButtonFormField<Map<String, dynamic>>(
                decoration:
                    const InputDecoration(labelText: 'Ítem — ver Kardex'),
                items: _items
                    .map((i) => DropdownMenuItem(
                        value: i, child: Text('${i['codigo']} — ${i['descripcion']}')))
                    .toList(),
                onChanged: (i) => i == null ? null : _ver(i),
              ),
            ),
            const SizedBox(height: 12),
            if (_cargando) const LinearProgressIndicator(),
            if (_sel != null && !_cargando)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Fecha')),
                      DataColumn(label: Text('Tipo')),
                      DataColumn(label: Text('Doc.')),
                      DataColumn(label: Text('Cant')),
                      DataColumn(label: Text('Valor')),
                      DataColumn(label: Text('Saldo C')),
                      DataColumn(label: Text('Saldo V')),
                      DataColumn(label: Text('Motivo')),
                    ],
                    rows: [
                      for (final m in _movs)
                        DataRow(cells: [
                          DataCell(Text('${m['fecha']}')),
                          DataCell(Text('${m['tipo']}',
                              style: TextStyle(
                                  color: '${m['tipo']}'.startsWith('ENTRADA')
                                      ? Colors.green.shade800
                                      : Colors.red.shade700))),
                          DataCell(Text('${m['numero_documento'] ?? '—'}')),
                          DataCell(Text('${m['cantidad']}')),
                          DataCell(Text(f.format((m['valor'] as num?) ?? 0))),
                          DataCell(Text('${m['saldo_cantidad'] ?? '—'}')),
                          DataCell(Text('${m['saldo_valor'] != null ? f.format(m['saldo_valor']) : '—'}')),
                          DataCell(Text('${m['motivo'] ?? ''}', maxLines: 1)),
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

class _ArqueoTab extends StatefulWidget {
  const _ArqueoTab();
  @override
  State<_ArqueoTab> createState() => _ArqueoTabState();
}

class _ArqueoTabState extends State<_ArqueoTab> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _sel;
  final _fisica = TextEditingController();
  final _obs = TextEditingController();
  List<Map<String, dynamic>> _tomas = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _items = await cargarCatalogoItems();
    _tomas = await Api.raw('toma_inventario_fisico',
        columns: '*, item:item_valorado(descripcion,codigo)',
        orderCol: 'id');
    if (mounted) setState(() {});
  }

  Future<void> _registrar() async {
    if (_sel == null || _fisica.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_toma_fisica', {
        'p_item_id': _sel!['id'],
        'p_fisica': int.parse(_fisica.text),
        'p_obs': _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      });
      if (mounted) {
        snack(context,
            'Toma registrada — sistema ${res['sistema']}, físico ${res['fisica']}, ${res['tipo']} Bs ${res['bs']}');
        _fisica.clear();
        _obs.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final puede = rol == 'ADMIN' || rol == 'CAJERA' || rol == 'TESORERIA';
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (puede) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 380,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(labelText: 'Ítem'),
                      items: _items
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i['codigo']} — ${i['descripcion']}')))
                          .toList(),
                      onChanged: (i) => setState(() => _sel = i),
                    ),
                  ),
                  SizedBox(
                    width: 140,
                    child: TextField(
                      controller: _fisica,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cant. física'),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: TextField(
                      controller: _obs,
                      decoration: const InputDecoration(labelText: 'Observaciones'),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _registrar,
                    child: const Text('Registrar toma'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Ítem')),
                    DataColumn(label: Text('Sistema')),
                    DataColumn(label: Text('Físico')),
                    DataColumn(label: Text('Dif.')),
                    DataColumn(label: Text('Tipo')),
                    DataColumn(label: Text('Bs')),
                  ],
                  rows: [
                    for (final t in _tomas.reversed)
                      DataRow(cells: [
                        DataCell(Text('${t['fecha']}')),
                        DataCell(Text(
                            '${t['item']?['codigo'] ?? ''} ${t['item']?['descripcion'] ?? ''}')),
                        DataCell(Text('${t['cantidad_sistema']}')),
                        DataCell(Text('${t['cantidad_fisica']}')),
                        DataCell(Text('${t['diferencia']}')),
                        DataCell(Text('${t['tipo_diferencia']}',
                            style: TextStyle(
                                color: t['tipo_diferencia'] == 'OK'
                                    ? Colors.green
                                    : Colors.red))),
                        DataCell(Text(f.format((t['bs_diferencia'] as num?) ?? 0))),
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

class _PedidosTab extends StatefulWidget {
  const _PedidosTab();
  @override
  State<_PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<_PedidosTab> {
  List<Map<String, dynamic>> _pedidos = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _itemSel;
  final _cant = TextEditingController();
  final _doc = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _items = await cargarCatalogoItems();
    _pedidos = await Api.raw('pedido_reposicion',
        columns: '*, item:item_valorado(descripcion,codigo), reg:usuario_sistema!pedido_reposicion_registrado_por_fkey(nombre), apr:usuario_sistema!pedido_reposicion_aprobado_por_fkey(nombre)',
        orderCol: 'id');
    if (mounted) setState(() {});
  }

  Future<void> _emitir() async {
    if (_itemSel == null || _cant.text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_emitir_pedido', {
        'p_item_id': _itemSel!['id'],
        'p_cantidad': int.parse(_cant.text),
        'p_doc': _doc.text.trim().isEmpty ? null : _doc.text.trim(),
      });
      if (mounted) {
        snack(context, 'Pedido ${res['numero_pedido']} emitido');
        _cant.clear();
        _doc.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recepcionar(Map<String, dynamic> p) async {
    final c = TextEditingController(text: '${p['cantidad']}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recepción ${p['numero_pedido']}'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad recibida'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.rpc('sp_recepcionar_pedido', {
        'p_pedido_id': p['id'],
        'p_cantidad_recibida': int.parse(c.text),
      });
      if (mounted) {
        snack(context, 'Recepción registrada');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _aprobar(Map<String, dynamic> p) async {
    try {
      final res = await Api.rpc('sp_aprobar_pedido', {'p_pedido_id': p['id']});
      if (mounted) {
        snack(context, 'Pedido ${res['estado']} — entrada en Kardex');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (rol == 'ADMIN' || rol == 'CAJERA' || rol == 'TESORERIA') ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 380,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(labelText: 'Ítem a pedir'),
                      items: _items
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i['codigo']} — ${i['descripcion']}')))
                          .toList(),
                      onChanged: (i) => setState(() => _itemSel = i),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _cant,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cantidad'),
                    ),
                  ),
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _doc,
                      decoration: const InputDecoration(
                          labelText: 'Doc. respaldo (opcional)'),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _emitir,
                    child: const Text('Emitir pedido'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('N°')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Ítem')),
                    DataColumn(label: Text('Cant')),
                    DataColumn(label: Text('Recibida')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Registró')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: [
                    for (final p in _pedidos.reversed)
                      DataRow(cells: [
                        DataCell(Text('${p['numero_pedido']}')),
                        DataCell(Text('${p['fecha']}')),
                        DataCell(Text(
                            '${p['item']?['codigo'] ?? ''} ${p['item']?['descripcion'] ?? ''}')),
                        DataCell(Text('${p['cantidad']}')),
                        DataCell(Text('${p['cantidad_recibida'] ?? '—'}')),
                        DataCell(Chip(
                          label: Text('${p['estado']}',
                              style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: p['estado'] == 'COMPLETO'
                              ? const Color(0xFFD8F0E3)
                              : p['estado'] == 'PARCIAL'
                                  ? const Color(0xFFFDEBD3)
                                  : p['estado'] == 'ANULADO'
                                      ? const Color(0xFFFDE2E2)
                                      : const Color(0xFFDCE9F7),
                        )),
                        DataCell(Text('${p['reg']?['nombre'] ?? '—'}')),
                        DataCell(Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p['estado'] == 'EMITIDO' ||
                                p['estado'] == 'PARCIAL') ...[
                              IconButton(
                                icon: const Icon(Icons.inventory,
                                    size: 18, color: Colors.orange),
                                tooltip: 'Recepcionar',
                                onPressed: () => _recepcionar(p),
                              ),
                              if (p['cantidad_recibida'] != null)
                                IconButton(
                                  icon: const Icon(Icons.verified,
                                      size: 18, color: Colors.green),
                                  tooltip: 'Aprobar (doble firma)',
                                  onPressed: () => _aprobar(p),
                                ),
                            ],
                          ],
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

class _AperturaTab extends StatefulWidget {
  const _AperturaTab();
  @override
  State<_AperturaTab> createState() => _AperturaTabState();
}

class _AperturaTabState extends State<_AperturaTab> {
  List<Map<String, dynamic>> _aps = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _aps = await Api.raw('apertura_inventario',
        columns: '*, reg:usuario_sistema(nombre)', orderCol: 'id');
    if (mounted) setState(() {});
  }

  Future<void> _abrir() async {
    setState(() => _busy = true);
    try {
      final uid = sesionOf(context).perfil?.id;
      await Api.c.from('apertura_inventario').insert({
        'sucursal_id': 1,
        'fecha': DateTime.now().toIso8601String().substring(0, 10),
        'estado': 'ACTIVO',
        'registrado_por': uid,
      });
      if (mounted) {
        snack(context, 'Apertura de inventario registrada');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: _busy ? null : _abrir,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Registrar apertura de inventario'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final a in _aps.reversed)
                    ListTile(
                      leading: const Icon(Icons.fact_check),
                      title: Text('${a['fecha']} — ${a['estado']}'),
                      subtitle: Text('Registrado por: ${a['reg']?['nombre'] ?? a['registrado_por']}'),
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

