import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';

class ConciliacionPage extends StatefulWidget {
  const ConciliacionPage({super.key});
  @override
  State<ConciliacionPage> createState() => _ConciliacionPageState();
}

class _ConciliacionPageState extends State<ConciliacionPage> {
  List<Map<String, dynamic>> _depositos = [];
  List<Map<String, dynamic>> _concis = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _depositos = await Api.raw('deposito_bancario', columns: '*', orderCol: 'id');
    _concis = await Api.raw('conciliacion_bancaria',
        columns: '*, dep:deposito_bancario(monto,numero_deposito)', orderCol: 'id');
    if (mounted) setState(() {});
  }

  Future<void> _conciliar(Map<String, dynamic> dep) async {
    final monto = TextEditingController(text: '${dep['monto']}');
    final comp = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Conciliar depósito ${dep['numero_deposito'] ?? dep['id']}'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: monto,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Monto según extracto'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: comp,
                decoration: const InputDecoration(
                    labelText: 'N° comprobante contable'),
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
              child: const Text('Conciliar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final m = double.parse(monto.text);
      await Api.c.from('conciliacion_bancaria').insert({
        'deposito_id': dep['id'],
        'monto_extracto': m,
        'coincide': (m - (dep['monto'] as num)).abs() < 0.01,
        'observacion': (m - (dep['monto'] as num)).abs() < 0.01
            ? 'Cuadra con el depósito'
            : 'Diferencia de Bs ${(m - (dep['monto'] as num)).abs().toStringAsFixed(2)}',
        'numero_comprobante_contable': comp.text.trim(),
        'fecha_conciliacion':
            DateTime.now().toIso8601String().substring(0, 10),
      });
      if (mounted) {
        snack(context, 'Conciliación registrada');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    final conciIds = _concis.map((c) => c['deposito_id']).toSet();
    final pendientes =
        _depositos.where((d) => !conciIds.contains(d['id'])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Depósitos pendientes de conciliar',
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
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Cuenta')),
                DataColumn(label: Text('N° Depósito')),
                DataColumn(label: Text('Monto')),
                DataColumn(label: Text('')),
              ],
              rows: [
                for (final d in pendientes)
                  DataRow(cells: [
                    DataCell(Text('${d['fecha_deposito']}')),
                    DataCell(Text('${d['numero_cuenta']}')),
                    DataCell(Text('${d['numero_deposito'] ?? '—'}')),
                    DataCell(Text('Bs ${f.format(d['monto'] ?? 0)}')),
                    DataCell(TextButton(
                      onPressed: () => _conciliar(d),
                      child: const Text('Conciliar'),
                    )),
                  ]),
                if (pendientes.isEmpty)
                  const DataRow(cells: [
                    DataCell(Text('—')),
                    DataCell(Text('Sin depósitos pendientes')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Conciliaciones registradas',
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
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Depósito')),
                DataColumn(label: Text('Extracto')),
                DataColumn(label: Text('Coincide')),
                DataColumn(label: Text('Comprobante')),
              ],
              rows: [
                for (final c in _concis.reversed)
                  DataRow(cells: [
                    DataCell(Text('${c['fecha_conciliacion']}')),
                    DataCell(Text(
                        'Bs ${f.format(c['dep']?['monto'] ?? 0)} ${c['dep']?['numero_deposito'] ?? ''}')),
                    DataCell(Text('Bs ${f.format(c['monto_extracto'] ?? 0)}')),
                    DataCell(Icon(
                      c['coincide'] == true ? Icons.check : Icons.close,
                      color:
                          c['coincide'] == true ? Colors.green : Colors.red,
                      size: 18,
                    )),
                    DataCell(Text('${c['numero_comprobante_contable'] ?? '—'}')),
                  ]),
                if (_concis.isEmpty)
                  const DataRow(cells: [
                    DataCell(Text('—')),
                    DataCell(Text('Sin conciliaciones')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                    DataCell(Text('')),
                  ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
