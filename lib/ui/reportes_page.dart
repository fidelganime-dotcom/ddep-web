import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';

bool enRango(dynamic fecha, String d, String h) {
  final f = fecha.toString();
  return f.compareTo(d) >= 0 && f.compareTo(h) <= 0;
}

class ReportesPage extends StatefulWidget {
  const ReportesPage({super.key});
  @override
  State<ReportesPage> createState() => _ReportesPageState();
}

class _ReportesPageState extends State<ReportesPage> {
  DateTime _desde = DateTime.now().subtract(const Duration(days: 7));
  DateTime _hasta = DateTime.now();
  String _tipo = 'KARDEX_VALORIZADO';
  List<Map<String, dynamic>> _filas = [];
  bool _cargando = false;

  Future<void> _generar() async {
    setState(() => _cargando = true);
    try {
      final d = _desde.toIso8601String().substring(0, 10);
      final h = _hasta.toIso8601String().substring(0, 10);
      switch (_tipo) {
        case 'KARDEX_VALORIZADO':
          final items = await Api.raw('item_valorado',
              columns: 'id,codigo,descripcion,precio_unitario_vigente',
              orderCol: 'codigo',
              asc: true);
          final movs = await Api.raw('movimiento_inventario',
              columns: '*', orderCol: 'id');
          _filas = [
            for (final i in items)
              {
                'codigo': i['codigo'],
                'descripcion': i['descripcion'],
                'detalle': movs
                    .where((m) =>
                        m['item_id'] == i['id'] && enRango(m['fecha'], d, h))
                    .length,
                'saldo': movs
                    .where((m) => m['item_id'] == i['id'])
                    .fold<num>(0, (a, m) => a),
                'total': movs
                    .where((m) =>
                        m['item_id'] == i['id'] && enRango(m['fecha'], d, h))
                    .fold<num>(0, (a, m) => a + ((m['valor'] as num?) ?? 0)),
                'ultimo': movs
                    .where((m) => m['item_id'] == i['id'])
                    .isEmpty
                    ? null
                    : movs.lastWhere((m) => m['item_id'] == i['id']),
              }
          ];
          // fix saldo from last movement
          for (final f in _filas) {
            final u = f['ultimo'];
            f['saldo'] = u != null ? (u['saldo_cantidad'] ?? 0) : 0;
            f['saldo_v'] = u != null ? (u['saldo_valor'] ?? 0) : 0;
            f.remove('ultimo');
          }
          break;
        case 'ENTRADAS_SALIDAS':
          final movs = await Api.raw('movimiento_inventario',
              columns:
                  '*, item:item_valorado(codigo,descripcion), numero_documento, tipo, cantidad, valor, fecha',
              orderCol: 'id');
          _filas = movs
              .where((m) => enRango(m['fecha'], d, h))
              .toList()
              .reversed
              .toList();
          break;
        case 'VENTAS':
          final ventas = await Api.raw('venta',
              columns:
                  '*, tramite(nombre), cajero:usuario_sistema(nombre)', orderCol: 'id');
          _filas = ventas
              .where((v) =>
                  enRango(v['fecha'], d, h) && v['estado'] != 'ANULADA')
              .toList()
              .reversed
              .toList();
          break;
        case 'TOMAS':
          _filas = (await Api.raw('toma_inventario_fisico',
                  columns: '*, item:item_valorado(codigo,descripcion)',
                  orderCol: 'id'))
              .reversed
              .toList();
          break;
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    value: _tipo,
                    decoration: const InputDecoration(labelText: 'Tipo de reporte'),
                    items: const [
                      DropdownMenuItem(
                          value: 'KARDEX_VALORIZADO',
                          child: Text('Kardex valorado')),
                      DropdownMenuItem(
                          value: 'ENTRADAS_SALIDAS',
                          child: Text('Entradas y salidas')),
                      DropdownMenuItem(
                          value: 'VENTAS', child: Text('Ventas del período')),
                      DropdownMenuItem(
                          value: 'TOMAS', child: Text('Inventario físico')),
                    ],
                    onChanged: (v) => setState(() => _tipo = v ?? 'KARDEX_VALORIZADO'),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    initialValue: _desde.toIso8601String().substring(0, 10),
                    decoration: const InputDecoration(labelText: 'Desde (yyyy-mm-dd)'),
                    onFieldSubmitted: (v) {
                      final dt = DateTime.tryParse(v);
                      if (dt != null) setState(() => _desde = dt);
                    },
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: TextFormField(
                    initialValue: _hasta.toIso8601String().substring(0, 10),
                    decoration: const InputDecoration(labelText: 'Hasta (yyyy-mm-dd)'),
                    onFieldSubmitted: (v) {
                      final dt = DateTime.tryParse(v);
                      if (dt != null) setState(() => _hasta = dt);
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _cargando ? null : _generar,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Generar'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_cargando) const LinearProgressIndicator(),
            Expanded(
              child: _filas.isEmpty && !_cargando
                  ? const Center(
                      child: Text('Seleccione el período y genere el reporte'))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _tabla(f),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabla(NumberFormat f) {
    switch (_tipo) {
      case 'KARDEX_VALORIZADO':
        return DataTable(columns: const [
          DataColumn(label: Text('Código')),
          DataColumn(label: Text('Descripción')),
          DataColumn(label: Text('Movs. período')),
          DataColumn(label: Text('Saldo')),
          DataColumn(label: Text('Saldo Bs')),
          DataColumn(label: Text('Movido Bs')),
        ], rows: [
          for (final r in _filas)
            DataRow(cells: [
              DataCell(Text('${r['codigo']}')),
              DataCell(Text('${r['descripcion']}')),
              DataCell(Text('${r['detalle']}')),
              DataCell(Text('${r['saldo']}')),
              DataCell(Text(f.format(r['saldo_v'] ?? 0))),
              DataCell(Text(f.format(r['total'] ?? 0))),
            ]),
        ]);
      case 'ENTRADAS_SALIDAS':
        return DataTable(columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Ítem')),
          DataColumn(label: Text('Tipo')),
          DataColumn(label: Text('Doc.')),
          DataColumn(label: Text('Cant')),
          DataColumn(label: Text('Valor')),
        ], rows: [
          for (final r in _filas)
            DataRow(cells: [
              DataCell(Text('${r['fecha']}')),
              DataCell(Text(
                  '${r['item']?['codigo'] ?? ''} ${r['item']?['descripcion'] ?? ''}')),
              DataCell(Text('${r['tipo']}')),
              DataCell(Text('${r['numero_documento'] ?? '—'}')),
              DataCell(Text('${r['cantidad']}')),
              DataCell(Text(f.format(r['valor'] ?? 0))),
            ]),
        ]);
      case 'VENTAS':
        return DataTable(columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Recibo')),
          DataColumn(label: Text('Trámite')),
          DataColumn(label: Text('Cajero')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Total')),
        ], rows: [
          for (final r in _filas)
            DataRow(cells: [
              DataCell(Text('${r['fecha']}')),
              DataCell(Text('${r['numero_recibo']}')),
              DataCell(Text('${r['tramite']?['nombre'] ?? '—'}')),
              DataCell(Text('${r['cajero']?['nombre'] ?? '—'}')),
              DataCell(Text('${r['estado']}')),
              DataCell(Text(f.format(r['total'] ?? 0))),
            ]),
        ]);
      case 'TOMAS':
        return DataTable(columns: const [
          DataColumn(label: Text('Fecha')),
          DataColumn(label: Text('Ítem')),
          DataColumn(label: Text('Sistema')),
          DataColumn(label: Text('Físico')),
          DataColumn(label: Text('Diferencia')),
          DataColumn(label: Text('Bs')),
        ], rows: [
          for (final r in _filas)
            DataRow(cells: [
              DataCell(Text('${r['fecha']}')),
              DataCell(Text(
                  '${r['item']?['codigo'] ?? ''} ${r['item']?['descripcion'] ?? ''}')),
              DataCell(Text('${r['cantidad_sistema']}')),
              DataCell(Text('${r['cantidad_fisica']}')),
              DataCell(Text('${r['diferencia']}')),
              DataCell(Text(f.format(r['bs_diferencia'] ?? 0))),
            ]),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}
