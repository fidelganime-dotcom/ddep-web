import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';
import 'tema.dart';

bool enRango(dynamic fecha, String d, String h) {
  final f = fecha.toString();
  return f.compareTo(d) >= 0 && f.compareTo(h) <= 0;
}

String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

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

  // Parámetros del formulario original (ids de reportes.html)
  bool _generado = false;
  DateTime _fechaVentaDiaria = DateTime.now();
  String _sucursal = '1';
  String _itemId = '';
  DateTime _fechaKardex = DateTime.now();
  DateTime _fechaResumenKardex = DateTime.now();
  int _anioInventario = DateTime.now().year;
  DateTime _fechaTomaInventario = DateTime.now();
  DateTime _fechaConsolidado = DateTime.now();
  DateTime _fechaInicioPedidos = DateTime.now();
  DateTime _fechaFinPedidos = DateTime.now();
  DateTime _fechaInicioAnul = DateTime.now();
  DateTime _fechaFinAnul = DateTime.now();
  DateTime _fechaInicioCierres = DateTime.now();
  DateTime _fechaFinCierres = DateTime.now();
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _cargarItems();
  }

  Future<void> _cargarItems() async {
    _items = await Api.raw('item_valorado',
        columns: 'id,codigo,descripcion,precio_unitario_vigente,activo',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);
    if (mounted) setState(() {});
  }

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

  /// Acción de los botones PDF/Excel de cada tarjeta: fija los parámetros
  /// del reporte y ejecuta el generador original.
  Future<void> _exportar(
      {String? tipo, DateTime? desde, DateTime? hasta}) async {
    if (_cargando) return;
    setState(() {
      if (tipo != null) _tipo = tipo;
      if (desde != null) _desde = desde;
      if (hasta != null) _hasta = hasta;
      _generado = true;
    });
    await _generar();
    if (mounted && _filas.isEmpty) {
      snack(context, 'Sin resultados en el período seleccionado');
    }
  }

  String _nombreTipo() {
    switch (_tipo) {
      case 'KARDEX_VALORIZADO':
        return 'Kardex valorado';
      case 'ENTRADAS_SALIDAS':
        return 'Entradas y salidas';
      case 'VENTAS':
        return 'Ventas del período';
      case 'TOMAS':
        return 'Inventario físico';
      default:
        return '';
    }
  }

  // ---------------------------------------------------------- tarjetas

  Widget _campoFecha(String etiqueta, DateTime valor,
      ValueChanged<DateTime> onChanged,
      {double ancho = 175}) {
    return _FechaCampo(
        etiqueta: etiqueta, valor: valor, ancho: ancho, onChanged: onChanged);
  }

  Widget _acciones(String textoPdf, String textoExcel,
      {required VoidCallback onPdf, required VoidCallback onExcel}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BtnPeligro(textoPdf, icon: Icons.picture_as_pdf,
          onPressed: _cargando ? null : onPdf),
      const SizedBox(width: 8),
      _BotonExito(textoExcel, icon: Icons.table_view,
          onPressed: _cargando ? null : onExcel),
    ]);
  }

  Widget _tarjeta(
      {required Color color,
      required IconData icon,
      required String titulo,
      required List<Widget> campos}) {
    return _TarjetaBorde(
      color: color,
      icon: icon,
      titulo: titulo,
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: campos,
      ),
    );
  }

  Widget _tarjetaVentaDiaria() => _tarjeta(
        color: const Color(0xFF3B82F6),
        icon: Icons.receipt,
        titulo: 'UAA.FORM. N°01 — Venta Diaria de Formularios',
        campos: [
          _campoFecha('Fecha', _fechaVentaDiaria,
              (d) => setState(() => _fechaVentaDiaria = d)),
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              value: _sucursal,
              decoration: const InputDecoration(labelText: 'Sucursal'),
              items: const [
                DropdownMenuItem(
                    value: '1', child: Text('Ventanilla Principal DDEP')),
              ],
              onChanged: (v) => setState(() => _sucursal = v ?? '1'),
            ),
          ),
          _acciones('Exportar PDF', 'Exportar Excel',
              onPdf: () => _exportar(
                  tipo: 'VENTAS',
                  desde: _fechaVentaDiaria,
                  hasta: _fechaVentaDiaria),
              onExcel: () => _exportar(
                  tipo: 'VENTAS',
                  desde: _fechaVentaDiaria,
                  hasta: _fechaVentaDiaria)),
        ],
      );

  Widget _tarjetaKardex() => _tarjeta(
        color: const Color(0xFF22C55E),
        icon: Icons.menu_book,
        titulo: 'UAA.FORM. N°02 — Kardex por Ítem',
        campos: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              value: _itemId,
              decoration: const InputDecoration(labelText: 'Ítem'),
              items: [
                const DropdownMenuItem(
                    value: '', child: Text('Seleccione un ítem...')),
                for (final i in _items)
                  DropdownMenuItem(
                      value: '${i['id']}',
                      child: Text('${i['codigo']} - ${i['descripcion']}')),
              ],
              onChanged: (v) => setState(() => _itemId = v ?? ''),
            ),
          ),
          _campoFecha('Fecha hasta', _fechaKardex,
              (d) => setState(() => _fechaKardex = d)),
          _acciones('PDF', 'Excel',
              onPdf: () =>
                  _exportar(tipo: 'KARDEX_VALORIZADO', hasta: _fechaKardex),
              onExcel: () =>
                  _exportar(tipo: 'KARDEX_VALORIZADO', hasta: _fechaKardex)),
        ],
      );

  Widget _tarjetaResumenKardex() => _tarjeta(
        color: const Color(0xFFF59E0B),
        icon: Icons.table_chart,
        titulo: 'UAA.FORM. N°02 — Resumen Kardex Valorado',
        campos: [
          _campoFecha('Fecha de corte', _fechaResumenKardex,
              (d) => setState(() => _fechaResumenKardex = d)),
          _acciones('PDF', 'Excel',
              onPdf: () => _exportar(
                  tipo: 'KARDEX_VALORIZADO', hasta: _fechaResumenKardex),
              onExcel: () => _exportar(
                  tipo: 'KARDEX_VALORIZADO', hasta: _fechaResumenKardex)),
        ],
      );

  Widget _tarjetaInventarioMensual() => _tarjeta(
        color: const Color(0xFF8B5CF6),
        icon: Icons.calendar_month,
        titulo: 'Reporte Entradas/Salidas Mensuales + Inventario Físico',
        campos: [
          SizedBox(
            width: 170,
            child: TextFormField(
              initialValue: '$_anioInventario',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Gestión (Año)'),
              onChanged: (v) {
                final a = int.tryParse(v.trim());
                if (a != null && a >= 2020 && a <= 2030) {
                  setState(() => _anioInventario = a);
                }
              },
            ),
          ),
          _campoFecha('Fecha toma física', _fechaTomaInventario,
              (d) => setState(() => _fechaTomaInventario = d)),
          _acciones('PDF', 'Excel',
              onPdf: () => _exportar(
                  tipo: 'ENTRADAS_SALIDAS',
                  desde: DateTime(_anioInventario, 1, 1),
                  hasta: _fechaTomaInventario),
              onExcel: () => _exportar(
                  tipo: 'ENTRADAS_SALIDAS',
                  desde: DateTime(_anioInventario, 1, 1),
                  hasta: _fechaTomaInventario)),
        ],
      );

  Widget _tarjetaConsolidado() => _tarjeta(
        color: const Color(0xFF0EA5E9),
        icon: Icons.collections,
        titulo: 'Resumen Diario Consolidado de Ventas',
        campos: [
          _campoFecha('Fecha', _fechaConsolidado,
              (d) => setState(() => _fechaConsolidado = d)),
          _acciones('Exportar PDF', 'Exportar Excel',
              onPdf: () => _exportar(
                  tipo: 'VENTAS',
                  desde: _fechaConsolidado,
                  hasta: _fechaConsolidado),
              onExcel: () => _exportar(
                  tipo: 'VENTAS',
                  desde: _fechaConsolidado,
                  hasta: _fechaConsolidado)),
        ],
      );

  Widget _tarjetaPedidos() => _tarjeta(
        color: const Color(0xFF14B8A6),
        icon: Icons.assignment,
        titulo: 'Estado de Pedidos de Reposicion',
        campos: [
          _campoFecha('Fecha inicio', _fechaInicioPedidos,
              (d) => setState(() => _fechaInicioPedidos = d)),
          _campoFecha('Fecha fin', _fechaFinPedidos,
              (d) => setState(() => _fechaFinPedidos = d)),
          _acciones('Exportar PDF', 'Exportar Excel',
              onPdf: () => _exportar(
                  desde: _fechaInicioPedidos, hasta: _fechaFinPedidos),
              onExcel: () => _exportar(
                  desde: _fechaInicioPedidos, hasta: _fechaFinPedidos)),
        ],
      );

  Widget _tarjetaAnulaciones() => _tarjeta(
        color: const Color(0xFFEF4444),
        icon: Icons.cancel,
        titulo: 'Anulaciones y Notas de Ajuste',
        campos: [
          _campoFecha('Fecha inicio', _fechaInicioAnul,
              (d) => setState(() => _fechaInicioAnul = d)),
          _campoFecha('Fecha fin', _fechaFinAnul,
              (d) => setState(() => _fechaFinAnul = d)),
          _acciones('Exportar PDF', 'Exportar Excel',
              onPdf: () => _exportar(desde: _fechaInicioAnul, hasta: _fechaFinAnul),
              onExcel: () =>
                  _exportar(desde: _fechaInicioAnul, hasta: _fechaFinAnul)),
        ],
      );

  Widget _tarjetaCierres() => _tarjeta(
        color: const Color(0xFFF97316),
        icon: Icons.lock,
        titulo: 'Cierres de Caja y Conciliacion',
        campos: [
          _campoFecha('Fecha inicio', _fechaInicioCierres,
              (d) => setState(() => _fechaInicioCierres = d)),
          _campoFecha('Fecha fin', _fechaFinCierres,
              (d) => setState(() => _fechaFinCierres = d)),
          _acciones('Exportar PDF', 'Exportar Excel',
              onPdf: () =>
                  _exportar(desde: _fechaInicioCierres, hasta: _fechaFinCierres),
              onExcel: () =>
                  _exportar(desde: _fechaInicioCierres, hasta: _fechaFinCierres)),
        ],
      );

  // ------------------------------------------------- vista previa

  Widget _tarjetaResultados(NumberFormat f) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: CardHeaderSection(
              icon: Icons.bar_chart,
              titulo: 'Vista previa — ${_nombreTipo()}',
              acciones: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${_filas.length}',
                    style: const TextStyle(
                        color: Color(0xFF4338CA),
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    value: _tipo,
                    decoration:
                        const InputDecoration(labelText: 'Tipo de reporte'),
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
                    onChanged: (v) =>
                        setState(() => _tipo = v ?? 'KARDEX_VALORIZADO'),
                  ),
                ),
                _campoFecha('Desde (yyyy-mm-dd)', _desde,
                    (d) => setState(() => _desde = d)),
                _campoFecha('Hasta (yyyy-mm-dd)', _hasta,
                    (d) => setState(() => _hasta = d)),
                BtnPrimario('Generar',
                    icon: Icons.play_arrow,
                    cargando: _cargando,
                    onPressed: () => _exportar()),
              ],
            ),
          ),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: LinearProgressIndicator(),
            )
          else if (_filas.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Text('Seleccione el período y genere el reporte',
                  style: TextStyle(color: T.texto2(context))),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: _tabla(f),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageTitle('Reportes'),
        const SizedBox(height: 4),
        Text('Generación de reportes oficiales — Exportar PDF y Excel',
            style: TextStyle(fontSize: 15, color: T.texto2(context))),
        const SizedBox(height: 16),
        _tarjetaVentaDiaria(),
        _tarjetaKardex(),
        _tarjetaResumenKardex(),
        _tarjetaInventarioMensual(),
        _tarjetaConsolidado(),
        _tarjetaPedidos(),
        _tarjetaAnulaciones(),
        _tarjetaCierres(),
        if (_generado) _tarjetaResultados(f),
      ],
    );
  }

  Widget _tabla(NumberFormat f) {
    switch (_tipo) {
      case 'KARDEX_VALORIZADO':
        return TablaModerna(columnas: const [
          'Código',
          'Descripción',
          'Movs. período',
          'Saldo',
          'Saldo Bs',
          'Movido Bs',
        ], filas: [
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
        return TablaModerna(columnas: const [
          'Fecha',
          'Ítem',
          'Tipo',
          'Doc.',
          'Cant',
          'Valor',
        ], filas: [
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
        return TablaModerna(columnas: const [
          'Fecha',
          'Recibo',
          'Trámite',
          'Cajero',
          'Estado',
          'Total',
        ], filas: [
          for (final r in _filas)
            DataRow(cells: [
              DataCell(Text('${r['fecha']}')),
              DataCell(Text('${r['numero_recibo']}')),
              DataCell(Text('${r['tramite']?['nombre'] ?? '—'}')),
              DataCell(Text('${r['cajero']?['nombre'] ?? '—'}')),
              DataCell(BadgeEstado('${r['estado']}')),
              DataCell(Text(f.format(r['total'] ?? 0))),
            ]),
        ]);
      case 'TOMAS':
        return TablaModerna(columnas: const [
          'Fecha',
          'Ítem',
          'Sistema',
          'Físico',
          'Diferencia',
          'Bs',
        ], filas: [
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

// ------------------------------------------------------------ widgets

/// .soft-card con el `border-left:4px solid` de cada tarjeta del HTML.
class _TarjetaBorde extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String titulo;
  final Widget child;
  const _TarjetaBorde(
      {required this.color,
      required this.icon,
      required this.titulo,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: T.tarjeta(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: T.esOscuro(context)
                ? Colors.transparent
                : const Color(0x0A000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(T.esOscuro(context) ? .3 : .06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 4))),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// .btn-success-custom (verde #22c55e) para "Exportar Excel".
class _BotonExito extends StatelessWidget {
  final String texto;
  final IconData? icon;
  final VoidCallback? onPressed;
  const _BotonExito(this.texto, {this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.check, size: 16),
      label: Text(texto,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: T.green1,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

/// `<input type="date">` del original.
class _FechaCampo extends StatefulWidget {
  final String etiqueta;
  final DateTime valor;
  final ValueChanged<DateTime> onChanged;
  final double ancho;
  const _FechaCampo(
      {required this.etiqueta,
      required this.valor,
      required this.onChanged,
      this.ancho = 175});

  @override
  State<_FechaCampo> createState() => _FechaCampoState();
}

class _FechaCampoState extends State<_FechaCampo> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: _iso(widget.valor));
  }

  @override
  void didUpdateWidget(covariant _FechaCampo old) {
    super.didUpdateWidget(old);
    final t = _iso(widget.valor);
    if (_ctrl.text != t) _ctrl.text = t;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _elegir() async {
    final f = await showDatePicker(
      context: context,
      initialDate: widget.valor,
      firstDate: DateTime(2015),
      lastDate: DateTime(2100),
    );
    if (f != null) widget.onChanged(f);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.ancho,
      child: TextFormField(
        controller: _ctrl,
        readOnly: true,
        onTap: _elegir,
        decoration: InputDecoration(
          labelText: widget.etiqueta,
          suffixIcon:
              const Icon(Icons.calendar_month, size: 16, color: T.accent),
        ),
      ),
    );
  }
}
