import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../widgets/snack.dart';
import 'tema.dart';

/// Réplica de la "Página Principal" (index.html original): cabecera con
/// buscador global, filtro de periodo, reloj y ubicación DDEP; KPIs, gráficos
/// (líneas y dona), tabla consolidada, gauges y treemap por categoría.
class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // ===== Lógica de datos (idéntica al original) =====
  Map<String, dynamic> _hoy = {};
  Map<String, dynamic> _mes = {};
  List<Map<String, dynamic>> _stock = [];
  List<Map<String, dynamic>> _ventas = [];
  bool _cargando = true;

  // ===== Estado de presentación =====
  String _periodo = 'dia';
  DateTime? _customDesde;
  DateTime? _customHasta;
  DateTime _ahora = DateTime.now();
  Timer? _relojTimer;
  Timer? _debounce;
  final TextEditingController _buscadorCtrl = TextEditingController();
  String _textoBusqueda = '';
  List<Map<String, String>> _resultados = [];
  String _actualizado = '--:--:--';

  static const List<String> _paleta = [
    '#06B6D4', '#D97706', '#10B981', '#3B82F6',
    '#8B5CF6', '#F472B6', '#FACC15', '#2DD4BF',
  ];

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    _customDesde = hoy.subtract(const Duration(days: 30));
    _customHasta = hoy;
    _relojTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _ahora = DateTime.now());
    });
    _cargar();
  }

  @override
  void dispose() {
    _relojTimer?.cancel();
    _debounce?.cancel();
    _buscadorCtrl.dispose();
    super.dispose();
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
      _ventas = ventas;
      _actualizado = DateFormat('HH:mm:ss').format(DateTime.now());
    } catch (e) {
      if (mounted) snack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ===== Utilidades de formato =====
  NumberFormat get _fbs => NumberFormat('#,##0.00', 'es_BO');
  NumberFormat get _fnum => NumberFormat('0.0', 'es_BO');

  String _bs(num v) => 'Bs ${_fbs.format(v)}';

  String _capitalizar(String s) {
    if (s.isEmpty) return s;
    return s
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  // ===== Rango del periodo (replica DashboardService.java) =====
  (DateTime, DateTime) _rangoPeriodo() {
    final hoy = DateTime.now();
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    switch (_periodo) {
      case 'semana':
        return (h.subtract(Duration(days: h.weekday - 1)), h);
      case 'mes':
        return (DateTime(h.year, h.month, 1), h);
      case 'trimestre':
        final m = ((h.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(h.year, m, 1), h);
      case 'custom':
        var d = _customDesde ?? h.subtract(const Duration(days: 30));
        var hh = _customHasta ?? h;
        if (hh.isAfter(h)) hh = h;
        d = DateTime(d.year, d.month, d.day);
        hh = DateTime(hh.year, hh.month, hh.day);
        if (d.isAfter(hh)) d = hh;
        return (d, hh);
      default:
        return (h, h);
    }
  }

  String _f(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _enRango(dynamic fecha, DateTime d, DateTime h) {
    final s = fecha.toString();
    return s.compareTo(_f(d)) >= 0 && s.compareTo(_f(h)) <= 0;
  }

  List<Map<String, dynamic>> _ventasEn(DateTime d, DateTime h) => _ventas
      .where((v) => v['estado'] != 'ANULADA' && _enRango(v['fecha'], d, h))
      .toList();

  double _sumaTotal(Iterable<Map<String, dynamic>> rows) =>
      rows.fold<double>(0, (a, v) => a + ((v['total'] as num?) ?? 0).toDouble());

  double _sumaEfectivo(Iterable<Map<String, dynamic>> rows) => rows
      .where((v) => v['forma_pago'] == 'EFECTIVO')
      .fold<double>(0, (a, v) => a + ((v['total'] as num?) ?? 0).toDouble());

  double? _variacion(double actual, double anterior) {
    if (anterior == 0) return null;
    return (actual - anterior) * 100 / anterior;
  }

  String _fechaCorta(String fecha) {
    final p = fecha.split('-');
    if (p.length != 3) return fecha;
    return '${int.parse(p[2])}/${int.parse(p[1])}';
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _ventas.isEmpty) {
      return const Center(
          child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(),
      ));
    }
    final (desde, hasta) = _rangoPeriodo();
    final periodo = _ventasEn(desde, hasta);
    final dias = hasta.difference(desde).inDays + 1;
    final antHasta = desde.subtract(const Duration(days: 1));
    final antDesde = antHasta.subtract(Duration(days: dias - 1));
    final anterior = _ventasEn(antDesde, antHasta);

    final rec = _sumaTotal(periodo);
    final recAnt = _sumaTotal(anterior);
    final efectivo = _sumaEfectivo(periodo);
    final custodia = _stock.fold<num>(0, (a, s) => a + ((s['valor'] as num?) ?? 0));

    final mesDesde = DateTime(_ahora.year, _ahora.month, 1);
    final ventasMes = _ventasEn(mesDesde, _ahora);
    final efectivoMes = _sumaEfectivo(ventasMes);
    final totalMes = ((_mes['recaudacion'] as num?) ?? 0).toDouble();
    final liquidez = totalMes > 0
        ? (efectivoMes * 100 / totalMes).clamp(0.0, 100.0).toDouble()
        : 0.0;
    final recaudacionHoy = ((_hoy['recaudacion'] as num?) ?? 0).toDouble();
    double mejorDia = 0;
    final porFecha = <String, double>{};
    for (final v in ventasMes) {
      final f = v['fecha'].toString();
      porFecha[f] = (porFecha[f] ?? 0) + ((v['total'] as num?) ?? 0).toDouble();
    }
    for (final m in porFecha.values) {
      if (m > mejorDia) mejorDia = m;
    }
    final avanceMetas = mejorDia > 0
        ? (recaudacionHoy * 100 / mejorDia).clamp(0.0, 100.0).toDouble()
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cabecera(),
        const SizedBox(height: 20),
        _tituloPagina(),
        const SizedBox(height: 16),
        _kpis(rec, recAnt, efectivo, custodia),
        const SizedBox(height: 16),
        _graficos(periodo),
        const SizedBox(height: 16),
        _tablaTransacciones(periodo),
        const SizedBox(height: 16),
        _filaGaugesTreemap(0.0, liquidez, avanceMetas, periodo),
      ],
    );
  }

  // ===== Cabecera: buscador, periodos, ubicación y reloj =====
  Widget _cabecera() {
    final oscuro = T.esOscuro(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: T.tarjeta(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: T.borde(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(oscuro ? .3 : .05),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buscadorGlobal(),
          _chipsPeriodo(),
          if (_periodo == 'custom') ...[
            _chipFecha('Desde', _customDesde, (d) => setState(() {
                  _customDesde = d;
                })),
            Text('—', style: TextStyle(color: T.texto2(context))),
            _chipFecha('Hasta', _customHasta, (d) => setState(() {
                  _customHasta = d;
                })),
          ],
          const SizedBox(width: 8),
          _ubicacionDdep(),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(DateFormat.Hms().format(_ahora),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: T.cyan1,
                      letterSpacing: .5,
                      fontFeatures: [FontFeature.tabularFigures()])),
              Text(
                  _capitalizar(DateFormat('EEEE d MMMM yyyy', 'es_BO')
                      .format(_ahora)),
                  style: TextStyle(fontSize: 11, color: T.texto2(context))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buscadorGlobal() {
    final oscuro = T.esOscuro(context);
    return SizedBox(
      width: 320,
      child: LayoutBuilder(builder: (ctx, c) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            TextField(
              controller: _buscadorCtrl,
              onChanged: _onBusqueda,
              style: TextStyle(fontSize: 13.5, color: T.texto(context)),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar facturas, trámites, ítems…',
                hintStyle: TextStyle(fontSize: 13, color: T.texto2(context)),
                prefixIcon: Icon(Icons.search, size: 18, color: T.texto2(context)),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 40, minHeight: 36),
                filled: true,
                fillColor: oscuro ? T.darkBg : T.bgPrimary,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                      color: T.accent.withOpacity(.25)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: T.cyan1, width: 1.4),
                ),
              ),
            ),
            if (_resultados.isNotEmpty ||
                (_textoBusqueda.length >= 2 && _resultados.isEmpty))
              Positioned(
                top: 48,
                left: 0,
                right: 0,
                child: _panelResultados(c.maxWidth),
              ),
          ],
        );
      }),
    );
  }

  Widget _panelResultados(double ancho) {
    return Material(
      elevation: 12,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: ancho,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          borderRadius: BorderRadius.circular(14),
          border: Border.fromBorderSide(
              const BorderSide(color: Color(0x1AFFFFFF))),
        ),
        child: _resultados.isEmpty
            ? Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                    'Sin resultados para "${_textoBusqueda.trim()}"',
                    style: const TextStyle(
                        fontSize: 12.5, color: Color(0xFF94A3B8))),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                children: [
                  for (final r in _resultados)
                    InkWell(
                      onTap: () {
                        _buscadorCtrl.text = r['etiqueta'] ?? '';
                        setState(() => _resultados = []);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: Color(0x0DFFFFFF))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0x1F06B6D4),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(r['tipo'] ?? '',
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: T.cyan1,
                                      letterSpacing: .4)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(r['etiqueta'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFFE2E8F0))),
                            ),
                            const SizedBox(width: 8),
                            Text(r['detalle'] ?? '',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  void _onBusqueda(String valor) {
    _textoBusqueda = valor;
    _debounce?.cancel();
    final q = valor.trim().toLowerCase();
    if (q.length < 2) {
      setState(() => _resultados = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      final res = <Map<String, String>>[];
      for (final v in _ventas) {
        final codigo = 'VTA-${((v['id'] as num?) ?? 0).toInt().toString().padLeft(5, '0')}';
        if (codigo.toLowerCase().contains(q) ||
            v['id'].toString().contains(q)) {
          res.add({
            'tipo': 'Recibo',
            'etiqueta': codigo,
            'detalle': _bs((v['total'] as num?) ?? 0),
          });
        }
        if (res.length >= 8) break;
      }
      for (final s in _stock) {
        final cod = '${s['codigo']}';
        final desc = '${s['descripcion']}';
        if (cod.toLowerCase().contains(q) || desc.toLowerCase().contains(q)) {
          res.add({
            'tipo': 'Ítem',
            'etiqueta': '$cod · $desc',
            'detalle': _bs((s['saldo'] as num?) ?? 0),
          });
        }
        if (res.length >= 8) break;
      }
      setState(() => _resultados = res.take(8).toList());
    });
  }

  Widget _chipsPeriodo() {
    const periodos = [
      ('dia', 'Día'),
      ('semana', 'Semana'),
      ('mes', 'Mes'),
      ('trimestre', 'Trimestre'),
      ('custom', 'Personalizado'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: T.esOscuro(context) ? T.darkBg : T.bgPrimary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: T.borde(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, label) in periodos) ...[
            _chipPeriodoItem(id, label),
            if (id != 'custom') const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Widget _chipPeriodoItem(String id, String label) {
    final activo = _periodo == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => setState(() => _periodo = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            gradient: activo
                ? const LinearGradient(
                    colors: [T.cyan1, T.cyan2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)
                : null,
            color: activo ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: activo
                ? [BoxShadow(color: T.cyan1.withOpacity(.35), blurRadius: 10)]
                : null,
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: activo ? const Color(0xFF041016) : T.texto2(context))),
        ),
      ),
    );
  }

  Widget _chipFecha(
      String etiqueta, DateTime? fecha, ValueChanged<DateTime> onOk) {
    final txt = fecha == null
        ? '—'
        : DateFormat('yyyy-MM-dd').format(fecha);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () async {
          final hoy = DateTime.now();
          final d = await showDatePicker(
            context: context,
            initialDate: fecha ?? hoy,
            firstDate: DateTime(2020),
            lastDate: hoy,
          );
          if (d != null) onOk(d);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: T.esOscuro(context) ? T.darkBg : T.bgPrimary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: T.borde(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 13, color: T.texto2(context)),
              const SizedBox(width: 6),
              Text('$etiqueta: $txt',
                  style: TextStyle(fontSize: 12, color: T.texto(context))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ubicacionDdep() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1710B981),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0x4710B981)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, size: 16, color: Color(0xFF34D399)),
          SizedBox(width: 7),
          Text('DDEP · Cobija, Pando',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF34D399))),
        ],
      ),
    );
  }

  // ===== Título de página + actualización =====
  Widget _tituloPagina() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle('Página Principal'),
              const SizedBox(height: 4),
              Text(
                'Dirección Departamental de Educación de Pando · Resumen ejecutivo',
                style: TextStyle(fontSize: 13, color: T.texto2(context)),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Actualizado: $_actualizado',
                style: TextStyle(fontSize: 12, color: T.texto2(context))),
            const SizedBox(width: 10),
            Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Actualizar datos',
                child: InkWell(
                  borderRadius: BorderRadius.circular(9),
                  onTap: _cargar,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: T.esOscuro(context) ? T.darkBg : T.bgPrimary,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: T.borde(context)),
                    ),
                    child:
                        Icon(Icons.refresh, size: 16, color: T.texto(context)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ===== KPIs =====
  Widget _kpis(double rec, double recAnt, double efectivo, num custodia) {
    final varRec = _variacion(rec, recAnt);
    final sparkRec = _sparkUltimos7((d, h) => _sumaTotal(_ventasEn(d, h)));
    final sparkEfe = _sparkUltimos7((d, h) => _sumaEfectivo(_ventasEn(d, h)));
    final custodiaF = custodia.toDouble();
    return LayoutBuilder(builder: (ctx, c) {
      final cols = c.maxWidth < 700
          ? 1
          : c.maxWidth < 1100
              ? 2
              : 4;
      final ancho = (c.maxWidth - (cols - 1) * 12) / cols;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: ancho,
            child: _KpiCard(
              etiqueta: 'Recaudación Neta',
              valor: _bs(rec),
              icono: Icons.currency_exchange,
              color1: const Color(0xFF06B6D4),
              color2: const Color(0xFF22D3EE),
              fondoIcono: const Color(0x2406B6D4),
              variacion: varRec,
              sufijoVariacion: 'vs periodo previo',
              spark: sparkRec,
              colorSpark: const Color(0xFF06B6D4),
            ),
          ),
          SizedBox(
            width: ancho,
            child: _KpiCard(
              etiqueta: 'Margen Operativo',
              valor: '${_fnum.format(0)}%',
              icono: Icons.percent,
              color1: const Color(0xFFD97706),
              color2: const Color(0xFFF59E0B),
              fondoIcono: const Color(0x24D97706),
              variacion: null,
              sufijoVariacion: '',
              spark: const [],
              colorSpark: const Color(0xFFD97706),
            ),
          ),
          SizedBox(
            width: ancho,
            child: _KpiCard(
              etiqueta: 'Activos en Custodia',
              valor: _bs(custodiaF),
              icono: Icons.savings,
              color1: const Color(0xFF10B981),
              color2: const Color(0xFF34D399),
              fondoIcono: const Color(0x2410B981),
              variacion: null,
              etiquetaPlana: 'Inventario valorado',
              spark: const [],
              colorSpark: const Color(0xFF10B981),
            ),
          ),
          SizedBox(
            width: ancho,
            child: _KpiCard(
              etiqueta: 'Flujo de Caja',
              valor: _bs(efectivo),
              icono: Icons.account_balance_wallet,
              color1: const Color(0xFF3B82F6),
              color2: const Color(0xFF60A5FA),
              fondoIcono: const Color(0x243B82F6),
              variacion: null,
              etiquetaPlana: 'Saldo disponible',
              spark: sparkEfe,
              colorSpark: const Color(0xFF3B82F6),
            ),
          ),
        ],
      );
    });
  }

  /// Serie diaria de los últimos 7 días para las sparklines.
  List<double> _sparkUltimos7(
      double Function(DateTime d, DateTime h) calc) {
    final hoy = DateTime.now();
    final h = DateTime(hoy.year, hoy.month, hoy.day);
    return [
      for (var i = 6; i >= 0; i--)
        calc(h.subtract(Duration(days: i)), h.subtract(Duration(days: i))),
    ];
  }

  // ===== Gráficos: financiero + dona =====
  Widget _graficos(List<Map<String, dynamic>> periodo) {
    final (desde, hasta) = _rangoPeriodo();
    final inicioSerie = hasta.subtract(const Duration(days: 13)).isAfter(desde)
        ? hasta.subtract(const Duration(days: 13))
        : desde;
    final etiquetas = <String>[];
    final ingresos = <double>[];
    final efectivo = <double>[];
    for (var i = 0; i <= hasta.difference(inicioSerie).inDays; i++) {
      final d = inicioSerie.add(Duration(days: i));
      final rows = _ventasEn(d, d);
      etiquetas.add(_fechaCorta(_f(d)));
      ingresos.add(_sumaTotal(rows));
      efectivo.add(_sumaEfectivo(rows));
    }
    final utilidad = [
      for (var i = 0; i < ingresos.length; i++) ingresos[i] - efectivo[i]
    ];

    final dona = <Map<String, dynamic>>[];
    final agrupado = <String, Map<String, dynamic>>{};
    for (final v in periodo) {
      final cat = (v['forma_pago'] == null || '${v['forma_pago']}'.isEmpty)
          ? 'Otro'
          : '${v['forma_pago']}';
      final g = agrupado.putIfAbsent(
          cat, () => {'categoria': cat, 'operaciones': 0, 'monto': 0.0});
      g['operaciones'] = ((g['operaciones'] as int) + 1);
      g['monto'] = ((g['monto'] as double) + ((v['total'] as num?) ?? 0).toDouble());
    }
    dona.addAll(agrupado.values
        .where((d) => (d['monto'] as double) > 0)
        .toList()
      ..sort((a, b) => (b['monto'] as double).compareTo(a['monto'] as double)));

    return LayoutBuilder(builder: (ctx, c) {
      final apilado = c.maxWidth < 900;
      final anchoDona = apilado
          ? c.maxWidth
          : (c.maxWidth / 3 * 1.05).clamp(280.0, 400.0).toDouble();
      final anchoFin = apilado ? c.maxWidth : c.maxWidth - anchoDona - 12;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: anchoFin,
            child: SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelHeader(
                    icono: Icons.trending_up,
                    color: const Color(0xFF06B6D4),
                    titulo: 'Desempeño Financiero',
                    subtitulo:
                        'Ingresos vs. Egresos vs. Utilidad neta · últimos 14 días con actividad',
                  ),
                  const SizedBox(height: 12),
                  _leyendaGrafico(const [
                    (Color(0xFF06B6D4), 'Ingresos'),
                    (Color(0xFFD97706), 'Egresos'),
                    (Color(0xFF10B981), 'Utilidad Neta'),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: ingresos.every((v) => v == 0)
                        ? Center(
                            child: Text('Sin actividad en el período',
                                style: TextStyle(
                                    fontSize: 12.5, color: T.texto2(context))),
                          )
                        : CustomPaint(
                            painter: _LineasPainter(
                              etiquetas: etiquetas,
                              series: [
                                (ingresos, const Color(0xFF06B6D4), false),
                                (efectivo, const Color(0xFFD97706), false),
                                (utilidad, const Color(0xFF10B981), true),
                              ],
                              colorGrid: T.borde(context),
                              colorTexto: T.texto2(context),
                              colorFondo: T.fondo(context),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: anchoDona,
            child: SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelHeader(
                    icono: Icons.pie_chart,
                    color: const Color(0xFFD97706),
                    titulo: 'Distribución de Ingresos',
                    subtitulo: 'Ventas por categoría de trámite',
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: dona.isEmpty
                        ? Center(
                            child: Text('Sin datos',
                                style: TextStyle(
                                    fontSize: 12.5, color: T.texto2(context))),
                          )
                        : CustomPaint(
                            painter: _DonaPainter(
                              valores: [
                                for (final d in dona)
                                  (d['monto'] as double).toDouble()
                              ],
                              colores: [
                                for (var i = 0; i < dona.length; i++)
                                  Color(int.parse(
                                      _paleta[i % _paleta.length]
                                          .replaceAll('#', 'FF'),
                                      radix: 16))
                              ],
                              colorFondo: T.fondo(context),
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  for (var i = 0; i < dona.length && i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(int.parse(
                                  _paleta[i % _paleta.length]
                                      .replaceAll('#', 'FF'),
                                  radix: 16)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${dona[i]['categoria']}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5, color: T.texto(context))),
                          ),
                          Text(_bs(dona[i]['monto'] as double),
                              style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: T.texto2(context))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _leyendaGrafico(List<(Color, String)> items) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (c, l) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c),
              ),
              const SizedBox(width: 6),
              Text(l,
                  style: TextStyle(fontSize: 11.5, color: T.texto2(context))),
            ],
          ),
      ],
    );
  }

  // ===== Tabla consolidada =====
  Widget _tablaTransacciones(List<Map<String, dynamic>> periodo) {
    final filas = periodo.reversed.take(8).toList();
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PanelHeader(
            icono: Icons.show_chart,
            color: const Color(0xFF10B981),
            titulo: 'Registro Consolidado de Transacciones',
            subtitulo: 'Últimos movimientos del período seleccionado',
          ),
          const SizedBox(height: 8),
          if (filas.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text('Sin transacciones en el período seleccionado',
                    style: TextStyle(fontSize: 12.5, color: T.texto2(context))),
              ),
            )
          else
            TablaModerna(
              anchoTotal: 980,
              columnas: const [
                'Fecha y Hora',
                'ID Transacción',
                'Entidad / Cliente',
                'Categoría',
                'Tipo de Movimiento',
                'Monto (Bs)',
                'Estado',
              ],
              filas: [
                for (final t in filas)
                  DataRow(cells: [
                    DataCell(Text('${t['fecha']}')),
                    DataCell(Text(
                      'VTA-${((t['id'] as num?) ?? 0).toInt().toString().padLeft(5, '0')}',
                      style: const TextStyle(
                          color: T.cyan1, fontWeight: FontWeight.w700),
                    )),
                    const DataCell(Text('Consumidor Final')),
                    const DataCell(Text('—')),
                    DataCell(Text(
                        'Ingreso · ${t['forma_pago'] == null || '${t['forma_pago']}'.isEmpty ? 'Pago' : '${t['forma_pago']}'}')),
                    DataCell(Text(_bs((t['total'] as num?) ?? 0),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: T.texto(context)))),
                    DataCell(_chipEstado('${t['estado']}')),
                  ]),
              ],
            ),
        ],
      ),
    );
  }

  Widget _chipEstado(String estado) {
    final e = estado.toUpperCase();
    late final Color color;
    late final String texto;
    if (e == 'CONFIRMADA') {
      color = const Color(0xFF34D399);
      texto = 'Completado';
    } else if (e == 'PENDIENTE') {
      color = const Color(0xFFFBBF24);
      texto = 'Pendiente';
    } else {
      color = const Color(0xFFF87171);
      texto = 'Alerta';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color)),
    );
  }

  // ===== Gauges + treemap =====
  Widget _filaGaugesTreemap(double presupuesto, double liquidez,
      double avanceMetas, List<Map<String, dynamic>> periodo) {
    final treemap = <Map<String, dynamic>>[];
    final agrupado = <String, Map<String, dynamic>>{};
    for (final v in periodo) {
      final cat = (v['forma_pago'] == null || '${v['forma_pago']}'.isEmpty)
          ? 'Otro'
          : '${v['forma_pago']}';
      final g = agrupado.putIfAbsent(
          cat, () => {'categoria': cat, 'operaciones': 0, 'monto': 0.0});
      g['operaciones'] = ((g['operaciones'] as int) + 1);
      g['monto'] = ((g['monto'] as double) + ((v['total'] as num?) ?? 0).toDouble());
    }
    treemap.addAll(agrupado.values
        .where((d) => (d['monto'] as double) > 0)
        .toList()
      ..sort((a, b) => (b['operaciones'] as int).compareTo(a['operaciones'] as int)));

    return LayoutBuilder(builder: (ctx, c) {
      final apilado = c.maxWidth < 900;
      final anchoGauges = apilado
          ? c.maxWidth
          : (c.maxWidth * 0.42).clamp(300.0, 480.0).toDouble();
      final anchoTreemap = apilado ? c.maxWidth : c.maxWidth - anchoGauges - 12;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: anchoGauges,
            child: Column(
              children: [
                SoftCard(
                  padding: const EdgeInsets.all(10),
                  margin: EdgeInsets.zero,
                  child: LayoutBuilder(builder: (ctx, cc) {
                    final gAncho = (cc.maxWidth - 20) / 3;
                    return Row(
                      children: [
                        SizedBox(
                            width: gAncho,
                            child: _Gauge(
                                valor: presupuesto,
                                color: const Color(0xFFD97706),
                                etiqueta: 'Presupuesto Consumido')),
                        SizedBox(
                            width: gAncho,
                            child: _Gauge(
                                valor: liquidez,
                                color: const Color(0xFF10B981),
                                etiqueta: 'Liquidez de Caja')),
                        SizedBox(
                            width: gAncho,
                            child: _Gauge(
                                valor: avanceMetas,
                                color: const Color(0xFF06B6D4),
                                etiqueta: 'Avance de Metas')),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          SizedBox(
            width: anchoTreemap,
            child: SoftCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PanelHeader(
                    icono: Icons.grid_on,
                    color: const Color(0xFF3B82F6),
                    titulo: 'Demanda por Categoría',
                    subtitulo:
                        'Volumen proporcional de operaciones por tipo de trámite',
                  ),
                  const SizedBox(height: 8),
                  if (treemap.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                            'Sin demanda registrada en el período',
                            style: TextStyle(
                                fontSize: 12.5, color: T.texto2(context))),
                      ),
                    )
                  else
                    LayoutBuilder(
                        builder: (ctx, cc) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _treemapFilas(treemap, cc.maxWidth))),
                ],
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Reparto tipo treemap: filas de tiles con ancho proporcional a operaciones.
  List<Widget> _treemapFilas(
      List<Map<String, dynamic>> bloques, double anchoDisponible) {
    final totalOps = bloques.fold<int>(
        0, (a, b) => a + (((b['operaciones'] as num?) ?? 1).toInt()));
    final filas = <List<Map<String, dynamic>>>[];
    var fila = <Map<String, dynamic>>[];
    var opsFila = 0;
    for (final b in bloques) {
      final ops = (((b['operaciones'] as num?) ?? 1).toInt()).clamp(1, 1 << 30);
      if (fila.isNotEmpty && opsFila + ops > totalOps * 0.5 && anchoDisponible > 0) {
        filas.add(fila);
        fila = [];
        opsFila = 0;
      }
      fila.add(b);
      opsFila += ops;
    }
    if (fila.isNotEmpty) filas.add(fila);

    final widgets = <Widget>[];
    for (final f in filas) {
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            for (var i = 0; i < f.length; i++) ...[
              Expanded(
                flex: (((f[i]['operaciones'] as num?) ?? 1).toInt())
                    .clamp(1, 1 << 30),
                child: _TileTreemap(
                  nombre: '${f[i]['categoria']}',
                  operaciones: (f[i]['operaciones'] as num?)?.toInt() ?? 0,
                  monto: (f[i]['monto'] as num?) ?? 0,
                  color: Color(int.parse(
                      _paleta[bloques.indexOf(f[i]) % _paleta.length]
                          .replaceAll('#', 'FF'),
                      radix: 16)),
                ),
              ),
              if (i < f.length - 1) const SizedBox(width: 6),
            ],
          ],
        ),
      ));
    }
    return widgets;
  }
}

// ===== Widgets privados de presentación =====

class _KpiCard extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final IconData icono;
  final Color color1;
  final Color color2;
  final Color fondoIcono;
  final double? variacion;
  final String sufijoVariacion;
  final String? etiquetaPlana;
  final List<double> spark;
  final Color colorSpark;

  const _KpiCard({
    required this.etiqueta,
    required this.valor,
    required this.icono,
    required this.color1,
    required this.color2,
    required this.fondoIcono,
    this.variacion,
    this.sufijoVariacion = '',
    this.etiquetaPlana,
    this.spark = const [],
    required this.colorSpark,
  });

  @override
  Widget build(BuildContext context) {
    final fnum = NumberFormat('0.0', 'es_BO');
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color1, color2]),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(etiqueta.toUpperCase(),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .6,
                        color: T.texto2(context))),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: fondoIcono,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icono, size: 19, color: color1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valor,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                    color: T.texto(context))),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (variacion != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (variacion! >= 0
                            ? const Color(0xFF34D399)
                            : const Color(0xFFF87171))
                        .withOpacity(.13),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    variacion! > 0
                        ? '▲ ${fnum.format(variacion!)}% $sufijoVariacion'
                        : variacion! < 0
                            ? '▼ ${fnum.format(variacion!.abs())}% $sufijoVariacion'
                            : '0.0%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: variacion! > 0
                            ? const Color(0xFF34D399)
                            : variacion! < 0
                                ? const Color(0xFFF87171)
                                : T.texto2(context)),
                  ),
                )
              else
                Text(etiquetaPlana ?? 'sin dato previo',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: T.texto2(context))),
              const Spacer(),
              if (spark.isNotEmpty)
                SizedBox(
                  width: 96,
                  height: 34,
                  child: CustomPaint(
                    painter: _SparkPainter(
                        datos: spark, color: colorSpark),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  const _PanelHeader(
      {required this.icono,
      required this.color,
      required this.titulo,
      required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icono, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: T.texto(context))),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitulo,
            style: TextStyle(fontSize: 11, color: T.texto2(context))),
      ],
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> datos;
  final Color color;
  _SparkPainter({required this.datos, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final minV = datos.reduce((a, b) => a < b ? a : b);
    final maxV = datos.reduce((a, b) => a > b ? a : b);
    final rango = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final pts = <Offset>[
      for (var i = 0; i < datos.length; i++)
        Offset(
          i * size.width / (datos.length - 1).clamp(1, 1 << 30),
          size.height - 4 - ((datos[i] - minV) / rango) * (size.height - 8),
        ),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final g = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [color.withOpacity(.35), color.withOpacity(0)],
    ).createShader(Offset.zero & size);
    canvas.drawPath(fill, Paint()..shader = g);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) =>
      old.datos != datos || old.color != color;
}

class _LineasPainter extends CustomPainter {
  final List<String> etiquetas;
  final List<(List<double>, Color, bool)> series;
  final Color colorGrid;
  final Color colorTexto;
  final Color colorFondo;
  _LineasPainter({
    required this.etiquetas,
    required this.series,
    required this.colorGrid,
    required this.colorTexto,
    required this.colorFondo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final izq = 44.0, der = 8.0, arr = 10.0, aba = 22.0;
    final w = size.width - izq - der;
    final h = size.height - arr - aba;
    if (w <= 0 || h <= 0) return;

    double maxV = 0;
    for (final (datos, _, _) in series) {
      for (final v in datos) {
        if (v > maxV) maxV = v;
      }
    }
    if (maxV == 0) maxV = 1;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = colorGrid.withOpacity(.6);
    for (var i = 0; i <= 4; i++) {
      final y = arr + h - (h * i / 4);
      canvas.drawLine(Offset(izq, y), Offset(izq + w, y), gridPaint);
      final lbl = 'Bs ${(maxV * i / 4).round()}';
      final tp = TextPainter(
          text: TextSpan(
              text: lbl,
              style: TextStyle(fontSize: 9.5, color: colorTexto)),
          textDirection: ui.TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(izq - tp.width - 6, y - tp.height / 2));
    }
    final step = w / (etiquetas.length).clamp(1, 1 << 30);
    for (var i = 0; i < etiquetas.length; i++) {
      if (etiquetas.length > 8 && i % 2 == 1) continue;
      final tp = TextPainter(
          text: TextSpan(
              text: etiquetas[i],
              style: TextStyle(fontSize: 9.5, color: colorTexto)),
          textDirection: ui.TextDirection.ltr)
        ..layout();
      tp.paint(canvas,
          Offset(izq + step * i + step / 2 - tp.width / 2, size.height - tp.height - 2));
    }

    for (final (datos, color, punteada) in series) {
      if (datos.isEmpty) continue;
      final pts = <Offset>[
        for (var i = 0; i < datos.length; i++)
          Offset(izq + step * i + step / 2,
              arr + h - (datos[i] / maxV) * h),
      ];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (!punteada) {
        final fill = Path.from(path)
          ..lineTo(pts.last.dx, arr + h)
          ..lineTo(pts.first.dx, arr + h)
          ..close();
        final g = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(.25), color.withOpacity(0)],
        ).createShader(Offset.zero & size);
        canvas.drawPath(fill, Paint()..shader = g);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = punteada ? 1.8 : 2.2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = color);
      if (punteada) {
        // Línea punteada estilo "Utilidad Neta" del original.
        final dashed = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..color = color;
        for (var i = 0; i < pts.length - 1; i++) {
          final a = pts[i], b = pts[i + 1];
          const seg = 6.0, gap = 4.0;
          final dist = (b - a).distance;
          if (dist == 0) continue;
          final dir = (b - a) / dist;
          var t = 0.0;
          while (t < dist) {
            final t2 = (t + seg).clamp(0.0, dist);
            canvas.drawLine(a + dir * t, a + dir * t2, dashed);
            t = t2 + gap;
          }
        }
      } else {
        for (final p in pts) {
          canvas.drawCircle(
              p,
              3,
              Paint()
                ..color = color
                ..style = PaintingStyle.fill);
          canvas.drawCircle(
              p,
              3,
              Paint()
                ..color = colorFondo
                ..strokeWidth = 1.5
                ..style = PaintingStyle.stroke);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineasPainter old) => old.series != series;
}

class _DonaPainter extends CustomPainter {
  final List<double> valores;
  final List<Color> colores;
  final Color colorFondo;
  _DonaPainter(
      {required this.valores, required this.colores, required this.colorFondo});

  @override
  void paint(Canvas canvas, Size size) {
    if (valores.isEmpty) return;
    final total = valores.fold<double>(0, (a, v) => a + v);
    if (total <= 0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radio = size.shortestSide / 2 - 4;
    const cutout = .62;
    var start = -math.pi / 2;
    for (var i = 0; i < valores.length; i++) {
      final sweep = valores[i] / total * 2 * math.pi;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radio);
      final path = Path()
        ..addArc(rect, start, sweep)
        ..arcTo(
            Rect.fromCircle(
                center: Offset(cx, cy), radius: radio * cutout),
            start + sweep,
            -sweep,
            false)
        ..close();
      canvas.drawPath(path, Paint()..color = colores[i % colores.length]);
      // Bordes entre segmentos (3px, color de fondo) como el original.
      for (final ang in [start, start + sweep]) {
        final p1 = Offset(cx + radio * math.cos(ang), cy + radio * math.sin(ang));
        final p2 = Offset(cx + radio * cutout * math.cos(ang),
            cy + radio * cutout * math.sin(ang));
        canvas.drawLine(
            p1,
            p2,
            Paint()
              ..color = colorFondo
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonaPainter old) => old.valores != valores;
}

class _Gauge extends StatelessWidget {
  final double valor;
  final Color color;
  final String etiqueta;
  const _Gauge(
      {required this.valor, required this.color, required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final fnum = NumberFormat('0.0', 'es_BO');
    final p = valor.clamp(0.0, 100.0).toDouble();
    return Column(
      children: [
        SizedBox(
          width: 108,
          height: 62,
          child: CustomPaint(
            painter: _GaugePainter(valor: p, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(etiqueta.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: .4,
                color: T.texto2(context))),
        const SizedBox(height: 2),
        Text('${fnum.format(p)}%',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: T.texto(context))),
      ],
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double valor;
  final Color color;
  _GaugePainter({required this.valor, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const w = 108.0;
    final r = 44.0;
    final cx = w / 2, cy = 54.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    final fondo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x2494A3B8);
    canvas.drawArc(rect, 3.141592653589793, 3.141592653589793, false, fondo);
    final avance = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(.9);
    canvas.drawArc(rect, 3.141592653589793, 3.141592653589793 * valor / 100,
        false, avance);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.valor != valor || old.color != color;
}

class _TileTreemap extends StatelessWidget {
  final String nombre;
  final int operaciones;
  final num monto;
  final Color color;
  const _TileTreemap(
      {required this.nombre,
      required this.operaciones,
      required this.monto,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final fnum = NumberFormat('0.00', 'es_BO');
    final corto = nombre.length > 28 ? '${nombre.substring(0, 28)}…' : nombre;
    return Container(
      height: 84,
      constraints: const BoxConstraints(minWidth: 90),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(.87), color.withOpacity(.4)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(corto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFF8FAFC))),
          Text('$operaciones ops · Bs ${fnum.format(monto)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9.5, color: const Color(0xFFF8FAFC).withOpacity(.85))),
        ],
      ),
    );
  }
}
