import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic> _hoy = {};
  Map<String, dynamic> _mes = {};
  List<Map<String, dynamic>> _stock = [];
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
      final desde = '${hoy.substring(0, 8)}01';
      final ventas = await Api.raw('venta',
          columns: 'id,total,estado,fecha,forma_pago', orderCol: 'id');
      final hoyRows =
          ventas.where((v) => v['fecha'] == hoy && v['estado'] != 'ANULADA');
      final mesRows = ventas.where(
          (v) => v['fecha'].toString().compareTo(desde) >= 0 && v['estado'] != 'ANULADA');
      final items = await Api.raw('item_valorado',
          columns: 'id,codigo,descripcion,precio_unitario_vigente,activo',
          orderCol: 'codigo',
          asc: true);
      final movs = await Api.raw('movimiento_inventario',
          columns: 'item_id,saldo_cantidad,saldo_valor,id', orderCol: 'id');
      final saldos = <int, Map<String, dynamic>>{};
      for (final m in movs) {
        saldos[(m['item_id'] as num).toInt()] = m;
      }
      _hoy = {
        'recaudacion': hoyRows.fold<num>(
            0, (a, v) => a + ((v['total'] as num?) ?? 0)),
        'comprobantes': hoyRows.length,
      };
      _mes = {
        'recaudacion': mesRows.fold<num>(
            0, (a, v) => a + ((v['total'] as num?) ?? 0)),
        'comprobantes': mesRows.length,
      };
      _stock = items.where((i) => i['activo'] == true).map((i) {
        final s = saldos[(i['id'] as num).toInt()];
        return {
          'codigo': i['codigo'],
          'descripcion': i['descripcion'],
          'saldo': (s?['saldo_cantidad'] as num?) ?? 0,
          'valor': (s?['saldo_valor'] as num?) ?? 0,
        };
      }).toList();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    if (_cargando) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Panel',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _tarjeta(context, 'Recaudación de hoy',
                'Bs ${f.format(_hoy['recaudacion'] ?? 0)}', Icons.today),
            _tarjeta(context, 'Comprobantes de hoy',
                '${_hoy['comprobantes'] ?? 0}', Icons.receipt_long),
            _tarjeta(context, 'Recaudación del mes',
                'Bs ${f.format(_mes['recaudacion'] ?? 0)}', Icons.calendar_month),
            _tarjeta(context, 'Comprobantes del mes',
                '${_mes['comprobantes'] ?? 0}', Icons.summarize),
          ],
        ),
        const SizedBox(height: 20),
        Text('Existencias por ítem',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Código')),
                DataColumn(label: Text('Descripción')),
                DataColumn(label: Text('Saldo')),
                DataColumn(label: Text('Valor (Bs)')),
              ],
              rows: [
                for (final s in _stock)
                  DataRow(cells: [
                    DataCell(Text('${s['codigo']}')),
                    DataCell(Text('${s['descripcion']}')),
                    DataCell(Text('${s['saldo']}')),
                    DataCell(Text(f.format((s['valor'] as num?) ?? 0))),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _tarjeta(BuildContext ctx, String t, String v, IconData i) {
    return Card(
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(i, color: const Color(0xFFC9A227)),
            const SizedBox(height: 8),
            Text(t, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(v,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F3864))),
          ],
        ),
      ),
    );
  }
}
