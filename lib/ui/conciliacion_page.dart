import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';
import 'tema.dart';

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

  double _n(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: _TituloModal(
          gradiente: const LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF1E3A5F)]),
          icon: Icons.account_balance,
          texto: 'Conciliar depósito ${dep['numero_deposito'] ?? dep['id']}',
        ),
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
          BtnSecundario('Cancelar',
              onPressed: () => Navigator.pop(ctx, false)),
          BtnPrimario('Conciliar',
              icon: Icons.swap_horiz,
              onPressed: () => Navigator.pop(ctx, true)),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.swap_horiz, color: T.accent, size: 26),
            const SizedBox(width: 10),
            Text('Conciliación Bancaria',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: T.texto(context))),
          ],
        ),
        const SizedBox(height: 4),
        Text('Control de depósitos y movimientos bancarios',
            style: TextStyle(fontSize: 14, color: T.texto2(context))),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, c) {
          final ancho = c.maxWidth;
          final w = ancho >= 1100 ? (ancho - 12) / 2 : ancho;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: w,
                child: SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardHeaderSection(
                          icon: Icons.receipt_long,
                          titulo: 'Ventas por Depósito'),
                      TablaModerna(
                        anchoTotal: 560,
                        columnas: const [
                          'N° Comprobante',
                          'Fecha',
                          'Monto',
                          'Estado'
                        ],
                        filas: _concis.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('Sin datos disponibles')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]),
                              ]
                            : [
                                for (final c in _concis.reversed)
                                  DataRow(cells: [
                                    DataCell(Text(
                                        '${c['numero_comprobante_contable'] ?? '—'}')),
                                    DataCell(
                                        Text('${c['fecha_conciliacion'] ?? '—'}')),
                                    DataCell(Text(
                                        'Bs ${f.format(_n(c['monto_extracto']))}')),
                                    DataCell(c['coincide'] == true
                                        ? const _BadgeColor(
                                            texto: 'COINCIDE',
                                            bg: Color(0xFFDCFCE7),
                                            fg: Color(0xFF16A34A))
                                        : const _BadgeColor(
                                            texto: 'DIFERENCIA',
                                            bg: Color(0xFFFEE2E2),
                                            fg: Color(0xFFDC2626))),
                                  ]),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: w,
                child: SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardHeaderSection(
                          icon: Icons.account_balance,
                          titulo: 'Depósitos Registrados'),
                      TablaModerna(
                        anchoTotal: 560,
                        columnas: const [
                          'N° Depósito',
                          'Fecha',
                          'Monto',
                          'Conciliado'
                        ],
                        filas: _depositos.isEmpty
                            ? [
                                const DataRow(cells: [
                                  DataCell(Text('Sin datos disponibles')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                  DataCell(Text('')),
                                ]),
                              ]
                            : [
                                for (final d in _depositos)
                                  DataRow(cells: [
                                    DataCell(
                                        Text('${d['numero_deposito'] ?? '—'}')),
                                    DataCell(
                                        Text('${d['fecha_deposito'] ?? '—'}')),
                                    DataCell(Text(
                                        'Bs ${f.format(_n(d['monto']))}')),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        conciIds.contains(d['id'])
                                            ? const _BadgeColor(
                                                texto: 'CONCILIADO',
                                                bg: Color(0xFFDCFCE7),
                                                fg: Color(0xFF16A34A))
                                            : const _BadgeColor(
                                                texto: 'PENDIENTE',
                                                bg: Color(0xFFFEF3C7),
                                                fg: Color(0xFFD97706)),
                                        if (!conciIds.contains(d['id'])) ...[
                                          const SizedBox(width: 6),
                                          Tooltip(
                                            message: 'Conciliar',
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              onTap: () => _conciliar(d),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(4),
                                                child: Icon(Icons.swap_horiz,
                                                    size: 16, color: T.accent),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    )),
                                  ]),
                              ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}

class _BadgeColor extends StatelessWidget {
  final String texto;
  final Color bg;
  final Color fg;
  const _BadgeColor(
      {required this.texto, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11.2,
              fontWeight: FontWeight.w700,
              color: fg,
              letterSpacing: .2)),
    );
  }
}

class _TituloModal extends StatelessWidget {
  final LinearGradient gradiente;
  final IconData icon;
  final String texto;
  const _TituloModal(
      {required this.gradiente, required this.icon, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          gradient: gradiente, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
