import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';

class VentasPage extends StatefulWidget {
  const VentasPage({super.key});
  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _Linea {
  Map<String, dynamic> item;
  int cantidad;
  _Linea(this.item, this.cantidad);
}

class _VentasPageState extends State<VentasPage>
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
        TabBar(
          controller: _tab,
          tabs: const [Tab(text: 'Nueva venta'), Tab(text: 'Ventas de hoy')],
        ),
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 180,
          child: TabBarView(
            controller: _tab,
            children: const [_NuevaVenta(), _ListaVentas()],
          ),
        ),
      ],
    );
  }
}

class _NuevaVenta extends StatefulWidget {
  const _NuevaVenta();
  @override
  State<_NuevaVenta> createState() => _NuevaVentaState();
}

class _NuevaVentaState extends State<_NuevaVenta> {
  List<Map<String, dynamic>> _tramites = [];
  List<Map<String, dynamic>> _items = [];
  int? _tramiteId;
  String _forma = 'EFECTIVO';
  final _cliente = TextEditingController();
  final _ci = TextEditingController();
  final _lineas = <_Linea>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _tramites = await Api.raw('tramite',
        columns: 'id,nombre,tarifa,activo', eqField: 'activo', eqVal: true);
    _items = await Api.raw('item_valorado',
        columns: 'id,codigo,descripcion,precio_unitario_vigente,activo',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);
    if (mounted) setState(() {});
  }

  double get _total => _lineas.fold(
      0, (a, l) => a + l.cantidad * ((l.item['precio_unitario_vigente'] as num?) ?? 0));

  Future<void> _registrar() async {
    if (_lineas.isEmpty) {
      snack(context, 'Agregue al menos un ítem');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_registrar_venta', {
        'p_tramite_id': _tramiteId,
        'p_items': [
          for (final l in _lineas)
            {
              'item_id': l.item['id'],
              'cantidad': l.cantidad,
            }
        ],
        'p_forma_pago': _forma,
        'p_cliente_nombre': _cliente.text.trim().isEmpty ? null : _cliente.text.trim(),
        'p_cliente_ci': _ci.text.trim().isEmpty ? null : _ci.text.trim(),
      });
      if (mounted) {
        snack(context,
            'Venta registrada ${res['numero_recibo']} — Bs ${res['total']}');
        setState(() {
          _lineas.clear();
          _cliente.clear();
          _ci.clear();
          _tramiteId = null;
        });
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<int>(
                    value: _tramiteId,
                    decoration: const InputDecoration(labelText: 'Trámite (opcional)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Ninguno —')),
                      ..._tramites.map((t) => DropdownMenuItem(
                          value: (t['id'] as num).toInt(),
                          child: Text('${t['nombre']}'))),
                    ],
                    onChanged: (v) => setState(() => _tramiteId = v),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _forma,
                    decoration: const InputDecoration(labelText: 'Forma de pago'),
                    items: const [
                      DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                      DropdownMenuItem(value: 'QR', child: Text('QR')),
                      DropdownMenuItem(value: 'DEPOSITO', child: Text('Depósito')),
                    ],
                    onChanged: (v) => setState(() => _forma = v ?? 'EFECTIVO'),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: _cliente,
                    decoration: const InputDecoration(labelText: 'Cliente'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _ci,
                    decoration: const InputDecoration(labelText: 'CI'),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(labelText: 'Ítem'),
                    items: _items
                        .map((i) => DropdownMenuItem(
                            value: i,
                            child: Text(
                                '${i['codigo']} — ${i['descripcion']} (Bs ${i['precio_unitario_vigente']})')))
                        .toList(),
                    onChanged: (i) {
                      if (i == null) return;
                      setState(() {
                        final ex = _lineas.where((l) => l.item['id'] == i['id']);
                        if (ex.isEmpty) {
                          _lineas.add(_Linea(i, 1));
                        } else {
                          ex.first.cantidad++;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                const Text('← seleccione para agregar'),
              ],
            ),
            const SizedBox(height: 12),
            if (_lineas.isNotEmpty)
              Card(
                color: const Color(0xFFF8F9FC),
                child: Column(
                  children: [
                    for (var k = 0; k < _lineas.length; k++)
                      ListTile(
                        dense: true,
                        title: Text(
                            '${_lineas[k].item['codigo']} — ${_lineas[k].item['descripcion']}'),
                        subtitle: Text(
                            'Bs ${_lineas[k].item['precio_unitario_vigente']} c/u'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => setState(() {
                                if (_lineas[k].cantidad > 1) {
                                  _lineas[k].cantidad--;
                                } else {
                                  _lineas.removeAt(k);
                                }
                              }),
                            ),
                            Text('${_lineas[k].cantidad}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () =>
                                  setState(() => _lineas[k].cantidad++),
                            ),
                            const SizedBox(width: 8),
                            Text(
                                'Bs ${(_lineas[k].cantidad * (_lineas[k].item['precio_unitario_vigente'] as num)).toStringAsFixed(2)}'),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () =>
                                  setState(() => _lineas.removeAt(k)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Total: Bs ${_total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : _registrar,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: const Text('Registrar venta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListaVentas extends StatefulWidget {
  const _ListaVentas();
  @override
  State<_ListaVentas> createState() => _ListaVentasState();
}

class _ListaVentasState extends State<_ListaVentas> {
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final rows = await Api.raw('venta',
          columns: '*, tramite(nombre), cajero:usuario_sistema(nombre)',
          orderCol: 'id');
      _ventas = rows.where((v) => v['fecha'] == hoy).toList().reversed.toList();
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _anular(Map<String, dynamic> v) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Anular venta ${v['numero_recibo']}'),
        content: TextField(
          controller: motivo,
          decoration: const InputDecoration(labelText: 'Motivo'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Anular')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.rpc('sp_anular_venta', {
        'p_venta_id': v['id'],
        'p_motivo': motivo.text.trim().isEmpty ? 'Sin motivo' : motivo.text.trim(),
      });
      snack(context, 'Venta anulada');
      _cargar();
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    final rol = sesionOf(context).perfil?.rol ?? '';
    if (_cargando) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(),
      ));
    }
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Recibo')),
            DataColumn(label: Text('Hora')),
            DataColumn(label: Text('Trámite')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Estado')),
            DataColumn(label: Text('')),
          ],
          rows: [
            for (final v in _ventas)
              DataRow(cells: [
                DataCell(Text('${v['numero_recibo']}')),
                DataCell(Text('${v['hora']}'.substring(11, 16))),
                DataCell(Text('${v['tramite']?['nombre'] ?? '—'}')),
                DataCell(Text('Bs ${f.format((v['total'] as num?) ?? 0)}')),
                DataCell(Chip(
                  label: Text('${v['estado']}',
                      style: const TextStyle(fontSize: 11)),
                  backgroundColor: v['estado'] == 'CONFIRMADA'
                      ? const Color(0xFFD8F0E3)
                      : v['estado'] == 'ANULADA'
                          ? const Color(0xFFFDE2E2)
                          : const Color(0xFFDCE9F7),
                  visualDensity: VisualDensity.compact,
                )),
                DataCell(v['estado'] == 'CONFIRMADA' &&
                        (rol == 'ADMIN' || rol == 'CAJERA')
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                        tooltip: 'Anular',
                        onPressed: () => _anular(v),
                      )
                    : const SizedBox.shrink()),
              ]),
          ],
        ),
      ),
    );
  }
}
