import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api.dart';
import '../services/exportar.dart';
import '../widgets/snack.dart';
import 'tema.dart';

String _fLarga(DateTime d) => '${d.day}/${d.month}/${d.year}';

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<List<Map<String, dynamic>>> cargarCatalogoItems() => Api.raw('item_valorado',
    columns: 'id,codigo,descripcion,unidad_medida,precio_unitario_vigente,activo',
    eqField: 'activo',
    eqVal: true,
    orderCol: 'codigo',
    asc: true);

/// Movimientos de sucursal 1 hasta la fecha de corte, ordenados como Java
/// (fecha asc, id asc).
List<Map<String, dynamic>> _movsHasta(List<Map<String, dynamic>> movs, String iso) =>
    movs.where((m) {
      final suc = ((m['sucursal_id'] as num?)?.toInt()) ?? 0;
      return suc == 1 && '${m['fecha']}'.compareTo(iso) <= 0;
    }).toList()
      ..sort((a, b) {
        final c = '${a['fecha']}'.compareTo('${b['fecha']}');
        if (c != 0) return c;
        return (((a['id'] as num?) ?? 0).toInt())
            .compareTo(((b['id'] as num?) ?? 0).toInt());
      });

// ===========================================================================
// PAGINA
// ===========================================================================

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});
  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DateTime _fecha = DateTime.now();
  final _resumenKey = GlobalKey<_ResumenTabState>();
  final _arqueoKey = GlobalKey<_ArqueoTabState>();
  final _tabKey = GlobalKey();
  double _tabH = 460;
  double _ultVh = 0;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 6, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _medirTab());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final vh = MediaQuery.sizeOf(context).height;
    if (_ultVh == 0) _ultVh = vh;
    if ((vh - _ultVh).abs() > 1) {
      _ultVh = vh;
      WidgetsBinding.instance.addPostFrameCallback((_) => _medirTab());
    }
  }

  void _medirTab() {
    if (!mounted) return;
    final box = _tabKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final dy = box.localToGlobal(Offset.zero).dy;
    if (dy <= 0) return;
    final mq = MediaQuery.sizeOf(context);
    final pad = mq.width < 900 ? 12.0 : 24.0;
    final h = mq.height - (dy + box.size.height) - pad;
    if (!h.isFinite || h < 200) return;
    if ((h - _tabH).abs() > 1) setState(() => _tabH = h);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _irResumen() {
    _resumenKey.currentState?.cargar(_fecha);
    _tab.animateTo(0);
  }

  void _irArqueo() {
    _arqueoKey.currentState?.cargar(_fecha);
    _tab.animateTo(2);
  }

  void _recargarResumen() => _resumenKey.currentState?.cargar(_fecha);

  Future<void> _exportarGral(bool pdf) async {
    final iso = _iso(_fecha);
    try {
      final filas = await calcularResumenKardex(iso);
      if (pdf) {
        await exportarResumenKardexPdf(filas, iso);
      } else {
        await exportarResumenKardexXlsx(filas, iso);
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _exportarArqueo(bool pdf) async {
    final iso = _iso(_fecha);
    try {
      final filas = await calcularInventarioMensual(iso);
      if (pdf) {
        await exportarInventarioMensualPdf(filas, iso);
      } else {
        await exportarInventarioMensualXlsx(filas, iso);
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            const Icon(Icons.inventory_2, color: Color(0xFF8B5CF6), size: 26),
            const SizedBox(width: 10),
            Text('KARDEX INVENTARIO CAJA',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: T.texto(context))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 150,
                child: InputDecorator(
                  decoration:
                      const InputDecoration(labelText: 'Sucursal', isDense: true),
                  child: DropdownButton<String>(
                    value: '1',
                    isDense: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                          value: '1',
                          child: Text('PRINCIPAL',
                              style: TextStyle(fontSize: 13))),
                    ],
                    onChanged: (_) {},
                  ),
                ),
              ),
              SizedBox(
                width: 170,
                child: InputDecorator(
                  decoration: const InputDecoration(
                      labelText: 'Fecha de corte',
                      isDense: true,
                      suffixIcon: Icon(Icons.calendar_month, size: 18)),
                  child: GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                          context: context,
                          initialDate: _fecha,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100));
                      if (d != null) setState(() => _fecha = d);
                    },
                    child: Text(_fIso(_fecha),
                        style:
                            TextStyle(fontSize: 13, color: T.texto(context))),
                  ),
                ),
              ),
              _BtnBarra(
                  texto: 'Resumen General (GRAL)',
                  icon: Icons.table_chart,
                  color: const Color(0xFF1E3A5F),
                  onPressed: _irResumen),
              _BtnBarra(
                  texto: 'Arqueo de Caja',
                  icon: Icons.assignment_turned_in,
                  color: const Color(0xFF8B5CF6),
                  onPressed: _irArqueo),
              _BtnBarra(
                  texto: 'GRAL PDF',
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => _exportarGral(true)),
              _BtnBarra(
                  texto: 'GRAL Excel',
                  icon: Icons.table_view,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => _exportarGral(false)),
              _BtnBarra(
                  texto: 'ARQUEO PDF',
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => _exportarArqueo(true)),
              _BtnBarra(
                  texto: 'ARQUEO Excel',
                  icon: Icons.table_view,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => _exportarArqueo(false)),
            ],
          ),
        ),
        TabBar(controller: _tab, key: _tabKey, tabs: const [
          Tab(text: 'HOJA GRAL (25 items)'),
          Tab(text: 'KARDEX POR ITEM'),
          Tab(text: 'ARQUEO DE CAJA'),
          Tab(text: 'REGISTRAR'),
          Tab(text: 'APERTURA'),
          Tab(text: 'PEDIDOS'),
        ]),
        SizedBox(
          height: _tabH,
          child: TabBarView(controller: _tab, children: [
            _ResumenTab(key: _resumenKey, fecha: _fecha),
            _KardexTab(fecha: _fecha),
            _ArqueoTab(key: _arqueoKey, fecha: _fecha),
            const _RegistrarTab(),
            _AperturaTab(onResumen: _recargarResumen),
            _PedidosTab(onResumen: _recargarResumen),
          ]),
        ),
      ],
    );
  }
}

String _fIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ===========================================================================
// HOJA GRAL (resumen valorado) - Java: GET /api/inventario/resumen
// ===========================================================================

class _FilaResumen {
  final int itemId;
  final int num;
  final String codigo;
  final String descripcion;
  final String unidad;
  final double pu;
  final int iniC;
  final double iniV;
  final int entC;
  final double entV;
  final int salC;
  final double salV;
  final int finC;
  final double finV;
  const _FilaResumen({
    required this.itemId,
    required this.num,
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.pu,
    required this.iniC,
    required this.iniV,
    required this.entC,
    required this.entV,
    required this.salC,
    required this.salValoR,
    required this.finC,
    required this.finV,
  }) : salV = salValoR;
  final double salValoR;
}

Future<List<_FilaResumen>> _calcularResumen(DateTime fecha) async {
  final iso = _iso(fecha);
  final items = await Api.raw('item_valorado',
      columns: 'id,codigo,descripcion,unidad_medida,precio_unitario_vigente',
      eqField: 'activo',
      eqVal: true,
      orderCol: 'id',
      asc: true);
  final movs = await Api.raw('movimiento_inventario',
      columns: '*', orderCol: 'id', asc: true);
  final filtrados = _movsHasta(movs, iso);
  final porItem = <int, List<Map<String, dynamic>>>{};
  for (final m in filtrados) {
    final iid = ((m['item_id'] as num?)?.toInt()) ?? -1;
    (porItem[iid] ??= []).add(m);
  }

  final out = <_FilaResumen>[];
  var n = 0;
  for (final it in items) {
    final iid = ((it['id'] as num?)?.toInt()) ?? -1;
    var ent = 0, sal = 0;
    var vEnt = 0.0, vSal = 0.0;
    var finC = 0;
    var finV = 0.0;
    var pu = ((it['precio_unitario_vigente'] as num?) ?? 0).toDouble();
    for (final m in porItem[iid] ?? const <Map<String, dynamic>>[]) {
      ent += ((m['cantidad_entradas'] as num?) ?? 0).toInt();
      sal += ((m['cantidad_salidas'] as num?) ?? 0).toInt();
      vEnt += ((m['valor_entradas'] as num?) ?? 0).toDouble();
      vSal += ((m['valor_salidas'] as num?) ?? 0).toDouble();
      finC = ((m['saldo_cantidad'] as num?) ?? 0).toInt();
      finV = ((m['saldo_valor'] as num?) ?? 0).toDouble();
      final mp = m['precio_unitario'];
      if (mp is num) pu = mp.toDouble();
    }
    final iniC = finC + sal - ent;
    out.add(_FilaResumen(
      itemId: iid,
      num: ++n,
      codigo: '${it['codigo'] ?? ''}',
      descripcion: '${it['descripcion'] ?? ''}',
      unidad: '${it['unidad_medida'] ?? ''}',
      pu: pu,
      iniC: iniC,
      iniV: pu * iniC,
      entC: ent,
      entV: vEnt,
      salC: sal,
      salValoR: vSal,
      finC: finC,
      finV: finV,
    ));
  }
  return out;
}

class _ResumenTab extends StatefulWidget {
  final DateTime fecha;
  const _ResumenTab({super.key, required this.fecha});
  @override
  State<_ResumenTab> createState() => _ResumenTabState();
}

class _ResumenTabState extends State<_ResumenTab> {
  List<_FilaResumen> _filas = [];
  String _fechaTxt = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fechaTxt = _fLarga(widget.fecha);
    cargar(widget.fecha);
  }

  Future<void> cargar(DateTime fecha) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final filas = await _calcularResumen(fecha);
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _fechaTxt = _iso(fecha);
      });
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final alto = c.maxHeight < 200 ? 480.0 : c.maxHeight;
      return SizedBox(
        height: alto,
        child: SingleChildScrollView(
          child: SoftCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF1E3A5F),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('REPORTE DE KARDEX POR ITEM - VALORADO',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                      SizedBox(height: 2),
                    ],
                  ),
                  const Text('UAA. FORM. N°02',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF1E3A5F),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                  'Al $_fechaTxt (Expresado en Bolivianos)',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(builder: (context, c) {
                final e = (c.maxWidth / _ResumenTabla._suma).clamp(1.0, 3.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _ResumenTabla(filas: _filas, esc: e),
                );
              }),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  });
}
}

class _FilaTabla extends StatefulWidget {
  final Widget child;
  final int i;
  const _FilaTabla({required this.child, required this.i});
  @override
  State<_FilaTabla> createState() => _FilaTablaState();
}

class _FilaTablaState extends State<_FilaTabla> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final bg = _h
        ? const Color(0xFFF8FAFC)
        : (widget.i.isOdd ? const Color(0xFFFBFBFB) : Colors.white);
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: Container(color: bg, child: widget.child),
    );
  }
}

class _ResumenTabla extends StatelessWidget {
  final List<_FilaResumen> filas;
  final double esc;
  const _ResumenTabla({required this.filas, this.esc = 1.0});

  static const _navy = Color(0xFF1E3A5F);
  static const _hdrBdr = Color(0xFF4A90D9);
  static const _cellBdr = Color(0xFFD1D5DB);
  static const _neg = Color(0xFFDC2626);
  static const _txt = Color(0xFF1E293B);
  static const _anchos = <double>[
    50.4, 109.7, 447.0, 34.6, 34.6, 73.1, 77.4, 58.3, 77.2, 62.4, 68.4, 88.5,
    96.4, 77.4, 101.8
  ];
  static const _izq = 826.8;
  static const _suma = 1457.2;

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    double w(double x) => x * esc;

    Widget thSpan(String t, double x) => Container(
        width: w(x),
        height: 75.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget thGroup(String t, double x) => Container(
        width: w(x),
        height: 28.2,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.2)));

    Widget thSub(String t, double x) => Container(
        width: w(x),
        height: 47.4,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget cell(double x, String t,
        {AlignmentGeometry align = Alignment.centerLeft,
        bool neg = false,
        bool bold = false,
        bool wrap = false}) {
      final st = TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: neg ? _neg : _txt);
      return Container(
          width: w(x),
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _cellBdr))),
          child: wrap
              ? Text(t, style: st)
              : Text(t,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: align == Alignment.center
                      ? TextAlign.center
                      : align == Alignment.centerRight
                          ? TextAlign.right
                          : TextAlign.left,
                  style: st));
    }

    var totSI = 0, totE = 0, totS = 0, totSF = 0;
    num totVI = 0, totVE = 0, totVS = 0, totVF = 0;

    final filasWidgets = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      final r = filas[i];
      final neg = r.finC < 0;
      totSI += r.iniC;
      totE += r.entC;
      totS += r.salC;
      totSF += r.finC;
      totVI += r.iniV;
      totVE += r.entV;
      totVS += r.salV;
      totVF += r.finV;
      filasWidgets.add(_FilaTabla(
        i: i,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          cell(_anchos[0], '${r.num}', neg: neg),
          cell(_anchos[1], r.codigo, neg: neg),
          cell(_anchos[2], r.descripcion, neg: neg, wrap: true),
          cell(_anchos[3], '', align: Alignment.center, neg: neg),
          cell(_anchos[4], '', align: Alignment.center, neg: neg),
          cell(_anchos[5], r.unidad, align: Alignment.center, neg: neg),
          cell(_anchos[6], f.format(r.pu),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[7], '${r.iniC}', align: Alignment.center, neg: neg),
          cell(_anchos[8], '${r.entC}', align: Alignment.center, neg: neg),
          cell(_anchos[9], '${r.salC}', align: Alignment.center, neg: neg),
          cell(_anchos[10], '${r.finC}',
              align: Alignment.center, neg: neg, bold: true),
          cell(_anchos[11], f.format(r.iniV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[12], f.format(r.entV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[13], f.format(r.salV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[14], f.format(r.finV),
              align: Alignment.centerRight, neg: neg, bold: true),
        ]),
      ));
    }

    Widget footCell(double x, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w(x),
            height: 21,
            alignment: align,
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border:
                    Border.fromBorderSide(BorderSide(color: Color(0xFF999999)))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        thSpan('N°', _anchos[0]),
        thSpan('CODIGO', _anchos[1]),
        thSpan('DESCRIPCION (ITEM)', _anchos[2]),
        thSpan('DEL', _anchos[3]),
        thSpan('AL', _anchos[4]),
        thSpan('UNIDAD\nDE\nMEDIDA', _anchos[5]),
        thSpan('PRECIO\nUNITARIO', _anchos[6]),
        thGroup('CANTIDAD', 266.3),
        thGroup('VALORES', 364.1),
      ]),
      Row(children: [
        SizedBox(width: w(_izq)),
        thSub('SALDO\nINICIAL', _anchos[7]),
        thSub('ENTRADAS', _anchos[8]),
        thSub('SALIDAS', _anchos[9]),
        thSub('SALDO\nFINAL', _anchos[10]),
        thSub('SALDO\nINICIAL', _anchos[11]),
        thSub('ENTRADAS', _anchos[12]),
        thSub('SALIDAS', _anchos[13]),
        thSub('SALDO\nFINAL', _anchos[14]),
      ]),
      ...filasWidgets,
      Row(children: [
        footCell(_izq, 'TOTALES:', align: Alignment.centerRight),
        footCell(_anchos[7], '$totSI', align: Alignment.center),
        footCell(_anchos[8], '$totE', align: Alignment.center),
        footCell(_anchos[9], '$totS', align: Alignment.center),
        footCell(_anchos[10], '$totSF', align: Alignment.center),
        footCell(_anchos[11], f.format(totVI), align: Alignment.centerRight),
        footCell(_anchos[12], f.format(totVE), align: Alignment.centerRight),
        footCell(_anchos[13], f.format(totVS), align: Alignment.centerRight),
        footCell(_anchos[14], f.format(totVF), align: Alignment.centerRight),
      ]),
    ]);
  }
}

// ===========================================================================
// KARDEX POR ITEM
// ===========================================================================

class _KardexTab extends StatefulWidget {
  final DateTime fecha;
  const _KardexTab({required this.fecha});
  @override
  State<_KardexTab> createState() => _KardexTabState();
}

class _KardexTabState extends State<_KardexTab> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _drop;
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

  Future<List<Map<String, dynamic>>> _fetchMovs(int itemId) async {
    final movs = await Api.raw('movimiento_inventario',
        columns: '*', eqField: 'item_id', eqVal: itemId, orderCol: 'id');
    return _movsHasta(movs, _iso(widget.fecha));
  }

  Future<void> _ver(Map<String, dynamic> item) async {
    setState(() {
      _sel = item;
      _cargando = true;
    });
    _movs = await _fetchMovs(((item['id'] as num?)?.toInt()) ?? 0);
    if (mounted) setState(() => _cargando = false);
  }

  void _verSeleccionado() {
    final item = _drop;
    if (item == null) {
      snack(context, 'Seleccione un item');
      return;
    }
    _ver(item);
  }

  Future<void> _exportar(bool pdf) async {
    final item = _drop;
    if (item == null) {
      snack(context, 'Seleccione un item');
      return;
    }
    setState(() => _cargando = true);
    try {
      final movs = await _fetchMovs(((item['id'] as num?)?.toInt()) ?? 0);
      final filas = filasKardexItem(movs, _iso(widget.fecha),
          unidad: '${item['unidad_medida'] ?? ''}');
      if (pdf) {
        await exportarKardexItemPdf(item, filas, _iso(widget.fecha));
      } else {
        await exportarKardexItemXlsx(item, filas, _iso(widget.fecha));
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final alto = c.maxHeight < 200 ? 480.0 : c.maxHeight;
      return SizedBox(
        height: alto,
        child: SingleChildScrollView(
          child: SoftCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: const Color(0xFF1E3A5F),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('KARDEX POR ITEM',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  SizedBox(
                    width: 260,
                    height: 34,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      isDense: true,
                      hint: const Text('Seleccione item...',
                          style: TextStyle(fontSize: 12)),
                      items: _items
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i['codigo']} - ${i['descripcion']}',
                                  style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (i) => setState(() => _drop = i),
                      dropdownColor: T.tarjeta(context),
                      style: TextStyle(fontSize: 12, color: T.texto(context)),
                    ),
                  ),
                  _BtnBarra(
                      texto: 'Ver Kardex',
                      icon: Icons.search,
                      color: const Color(0xFF8B5CF6),
                      onPressed: _verSeleccionado),
                  _BtnBarra(
                      texto: 'PDF',
                      icon: Icons.picture_as_pdf,
                      color: Colors.white,
                      outline: true,
                      onPressed: () => _exportar(true)),
                  _BtnBarra(
                      texto: 'Excel',
                      icon: Icons.table_view,
                      color: Colors.white,
                      outline: true,
                      onPressed: () => _exportar(false)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(children: [
                Text('ITEM: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: T.texto(context))),
                Text(_sel?['descripcion']?.toString() ?? '—',
                    style: TextStyle(fontSize: 12, color: T.texto(context))),
                const SizedBox(width: 16),
                Text('CODIGO: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: T.texto(context))),
                Text(_sel?['codigo']?.toString() ?? '—',
                    style: TextStyle(fontSize: 12, color: T.texto(context))),
              ]),
            ),
            if (_cargando) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(builder: (context, c) {
                final e = (c.maxWidth / _KardexTabla._suma).clamp(1.0, 3.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _KardexTabla(movs: _movs, esc: e),
                );
              }),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0)))),
              child: const Text(
                  'Nota: La informacion expuesta en el presente cuadro cuenta con la documentacion de soporte correspondiente, en el marco de las Normas Basicas del Sistema de Contabilidad Integrada.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('Firma Responsable',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
                    Text('Firma UAA',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
                    Text('Firma VoBo',
                        style: TextStyle(fontSize: 11, color: Color(0xFF1E293B))),
                  ]),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  });
}
}

class _KardexTabla extends StatelessWidget {
  final List<Map<String, dynamic>> movs;
  final double esc;
  const _KardexTabla({required this.movs, this.esc = 1.0});

  static const _navy = Color(0xFF1E3A5F);
  static const _hdrBdr = Color(0xFF4A90D9);
  static const _cellBdr = Color(0xFFD1D5DB);
  static const _neg = Color(0xFFDC2626);
  static const _txt = Color(0xFF1E293B);
  static const _anchoIzq = 799.7;
  static const _anchos = <double>[
    44.1, 113.7, 197.9, 224.4, 35.9, 35.9, 75.8, 72.0, 68.7, 77.8, 62.5, 70.9,
    99.9, 99.9, 72.0, 105.6
  ];
  static const _suma = 1457.0;

  static String _tipoLabel(String tipo) {
    switch (tipo) {
      case 'APERTURA':
        return 'SALDO ANTERIOR';
      case 'VENTA':
        return 'VENTAS - CAJA';
      case 'ENTRADA_INICIAL':
        return 'INGRESO PEDIDO';
      case 'ENTRADA_REPOSICION':
        return 'PEDIDO';
      case 'AJUSTE':
        return 'AJUSTE';
      case 'REVERSA':
        return 'REVERSA';
    }
    return tipo;
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    double w(double x) => x * esc;

    Widget thSpan(String t, double x) => Container(
        width: w(x),
        height: 73.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget thGroup(String t, double x) => Container(
        width: w(x),
        height: 28.2,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.2)));

    Widget thSub(String t, double x) => Container(
        width: w(x),
        height: 45.4,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(3),
        decoration:
            BoxDecoration(color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget cell(double x, String t,
        {AlignmentGeometry align = Alignment.center,
        bool neg = false,
        bool bold = false,
        bool wrap = false}) {
      final st = TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: neg ? _neg : _txt);
      return Container(
          width: w(x),
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _cellBdr))),
          child: wrap
              ? Text(t, style: st)
              : Text(t,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: align == Alignment.center
                      ? TextAlign.center
                      : align == Alignment.centerRight
                          ? TextAlign.right
                          : TextAlign.left,
                  style: st));
    }

    final filas = <Widget>[];
    num totEnt = 0, totSal = 0;
    var finC = '0';
    var finV = '0.00';
    for (var idx = 0; idx < movs.length; idx++) {
      final m = movs[idx];
      final tipo = '${m['tipo'] ?? ''}';
      final cant = (m['cantidad'] as num?) ?? 0;
      final valor = (m['valor'] as num?) ?? 0;
      final esEntrada = tipo.startsWith('ENTRADA') || tipo == 'APERTURA';
      final ent = (m['cantidad_entradas'] as num?) ?? (esEntrada ? cant : 0);
      final sal =
          (m['cantidad_salidas'] as num?) ?? (!esEntrada ? cant : 0);
      final vEnt = (m['valor_entradas'] as num?) ?? (esEntrada ? valor : 0);
      final vSal = (m['valor_salidas'] as num?) ?? (!esEntrada ? valor : 0);
      num salIniC;
      if (idx > 0) {
        salIniC = (movs[idx - 1]['saldo_cantidad'] as num?) ?? 0;
      } else if (tipo == 'APERTURA') {
        salIniC = ((m['saldo_cantidad'] as num?) ?? 0) -
            ((m['cantidad_entradas'] as num?) ?? 0) +
            ((m['cantidad_salidas'] as num?) ?? 0);
      } else {
        salIniC = 0;
      }
      final salIniV = idx > 0
          ? ((movs[idx - 1]['saldo_valor'] as num?) ?? 0)
          : (tipo == 'APERTURA' ? ((m['saldo_valor'] as num?) ?? 0) : 0);
      final puRaw = m['precio_unitario'];
      final num pu = (puRaw as num?) ??
          (cant != 0 ? valor.abs() / cant.abs().toDouble() : 0);
      final saldoC = (m['saldo_cantidad'] as num?) ?? 0;
      final saldoV = (m['saldo_valor'] as num?) ?? 0;
      final neg = saldoC < 0;
      final doc = m['numero_documento']?.toString() ?? '';
      final tipoL = _tipoLabel(tipo);
      final desc = doc.isNotEmpty && tipo != 'APERTURA' && tipo != 'VENTA'
          ? '$tipoL $doc'
          : tipoL;
      totEnt += ent;
      totSal += sal;
      finC = '$saldoC';
      finV = f.format(saldoV);
      filas.add(_FilaTabla(
        i: idx,
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          cell(_anchos[0], '${idx + 1}', neg: neg),
          cell(_anchos[1], '${m['fecha'] ?? ''}',
              align: Alignment.centerLeft, neg: neg),
          cell(_anchos[2], desc,
              align: Alignment.centerLeft, neg: neg, wrap: true),
          cell(_anchos[3], doc, align: Alignment.centerLeft, neg: neg),
          cell(_anchos[4], m['serie_del']?.toString() ?? '', neg: neg),
          cell(_anchos[5], m['serie_al']?.toString() ?? '', neg: neg),
          cell(_anchos[6], m['unidad_medida']?.toString() ?? '', neg: neg),
          cell(_anchos[7], f.format(pu),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[8], '$salIniC', neg: neg),
          cell(_anchos[9], '$ent', neg: neg),
          cell(_anchos[10], '$sal', neg: neg),
          cell(_anchos[11], '$saldoC', neg: neg, bold: true),
          cell(_anchos[12], f.format(salIniV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[13], f.format(vEnt),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[14], f.format(vSal),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[15], f.format(saldoV),
              align: Alignment.centerRight, neg: neg, bold: true),
        ]),
      ));
    }

    Widget footCell(double x, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w(x),
            height: 21,
            alignment: align,
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border:
                    Border.fromBorderSide(BorderSide(color: Color(0xFF999999)))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: _txt)));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        thSpan('N°', _anchos[0]),
        thSpan('FECHA', _anchos[1]),
        thSpan('DESCRIPCION', _anchos[2]),
        thSpan('N° DOC.', _anchos[3]),
        thSpan('DEL', _anchos[4]),
        thSpan('AL', _anchos[5]),
        thSpan('UNIDAD', _anchos[6]),
        thSpan('PRECIO\nUNITARIO', _anchos[7]),
        thGroup('CANTIDAD', 279.9),
        thGroup('VALORES (BS)', 377.4),
      ]),
      Row(children: [
        SizedBox(width: w(_anchoIzq)),
        thSub('SALDO\nINICIAL', _anchos[8]),
        thSub('ENTRADAS', _anchos[9]),
        thSub('SALIDAS', _anchos[10]),
        thSub('SALDO\nFINAL', _anchos[11]),
        thSub('SALDO\nINICIAL', _anchos[12]),
        thSub('ENTRADAS', _anchos[13]),
        thSub('SALIDAS', _anchos[14]),
        thSub('SALDO\nFINAL', _anchos[15]),
      ]),
      ...filas,
      if (movs.isNotEmpty)
        Row(children: [
          footCell(_anchoIzq, 'TOTAL:', align: Alignment.centerRight),
          footCell(_anchos[8], ''),
          footCell(_anchos[9], '$totEnt'),
          footCell(_anchos[10], '$totSal'),
          footCell(_anchos[11], finC),
          footCell(_anchos[12], '', align: Alignment.centerRight),
          footCell(_anchos[13], '', align: Alignment.centerRight),
          footCell(_anchos[14], '', align: Alignment.centerRight),
          footCell(_anchos[15], finV, align: Alignment.centerRight),
        ]),
    ]);
  }
}

// ===========================================================================
// ARQUEO DE CAJA (tabla valorada) - Java: GET /api/inventario/arqueo
// ===========================================================================

class _FilaArqueo {
  final int num;
  final String codigo;
  final String descripcion;
  final String unidad;
  final double pu;
  final int iniC;
  final double iniV;
  final int entC;
  final double entV;
  final int salC;
  final double salV;
  final int finC;
  final double finV;
  final int? cantFisica;
  final int? dif;
  final String tipo;
  final double? bs;
  final String obs;
  const _FilaArqueo({
    required this.num,
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.pu,
    required this.iniC,
    required this.iniV,
    required this.entC,
    required this.entV,
    required this.salC,
    required this.salV,
    required this.finC,
    required this.finV,
    required this.cantFisica,
    required this.dif,
    required this.tipo,
    required this.bs,
    required this.obs,
  });
}

Future<List<_FilaArqueo>> _calcularArqueo(DateTime fecha) async {
  final resumen = await _calcularResumen(fecha);
  final tomas = await Api.raw('toma_inventario_fisico', columns: '*');
  tomas.sort((a, b) {
    final c = '${b['fecha']}'.compareTo('${a['fecha']}');
    if (c != 0) return c;
    return (((b['id'] as num?) ?? 0).toInt())
        .compareTo((((a['id'] as num?) ?? 0).toInt()));
  });
  final porItem = <int, Map<String, dynamic>>{};
  for (final t in tomas) {
    final iid = ((t['item_id'] as num?)?.toInt());
    if (iid != null) porItem.putIfAbsent(iid, () => t);
  }

  return resumen.map((r) {
    final t = porItem[r.itemId];
    final cf = t != null ? ((t['cantidad_fisica'] as num?)?.toInt()) : null;
    final dif = cf != null ? cf - r.finC : null;
    final bs = dif != null ? r.pu * dif : null;
    final tipo = dif != null
        ? (dif < 0 ? 'FALTANTE' : dif > 0 ? 'SOBRANTE' : '-')
        : '';
    return _FilaArqueo(
      num: r.num,
      codigo: r.codigo,
      descripcion: r.descripcion,
      unidad: r.unidad,
      pu: r.pu,
      iniC: r.iniC,
      iniV: r.iniV,
      entC: r.entC,
      entV: r.entV,
      salC: r.salC,
      salV: r.salV,
      finC: r.finC,
      finV: r.finV,
      cantFisica: cf,
      dif: dif,
      tipo: tipo,
      bs: bs,
      obs: '${t?['observaciones'] ?? ''}',
    );
  }).toList();
}

class _ArqueoTab extends StatefulWidget {
  final DateTime fecha;
  const _ArqueoTab({super.key, required this.fecha});
  @override
  State<_ArqueoTab> createState() => _ArqueoTabState();
}

class _ArqueoTabState extends State<_ArqueoTab> {
  List<_FilaArqueo> _filas = [];
  String _fechaTxt = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _fechaTxt = _fLarga(widget.fecha);
  }

  Future<void> cargar(DateTime fecha) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final filas = await _calcularArqueo(fecha);
      if (!mounted) return;
      setState(() {
        _filas = filas;
        _fechaTxt = _iso(fecha);
      });
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final alto = c.maxHeight < 200 ? 480.0 : c.maxHeight;
      return SizedBox(
        height: alto,
        child: SingleChildScrollView(
          child: SoftCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xFF8B5CF6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text('ARQUEO DE CAJA — Al $_fechaTxt',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(builder: (context, c) {
                final e = (c.maxWidth / _ArqueoTabla._suma).clamp(1.0, 3.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _ArqueoTabla(filas: _filas, esc: e),
                );
              }),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  });
}
}

class _ArqueoTabla extends StatelessWidget {
  final List<_FilaArqueo> filas;
  final double esc;
  const _ArqueoTabla({required this.filas, this.esc = 1.0});

  static const _purple = Color(0xFF8B5CF6);
  static const _purpleBdr = Color(0xFF9966CC);
  static const _green = Color(0xFF27AE60);
  static const _greenBg = Color(0xFFD4EDDA);
  static const _greenTxt = Color(0xFF14532D);
  static const _cellBdr = Color(0xFFD1D5DB);
  static const _neg = Color(0xFFDC2626);
  static const _txt = Color(0xFF1E293B);
  static const _anchos = <double>[
    48.1, 79.5, 184.9, 69.7, 73.8, 55.6, 73.6, 59.5, 65.2, 84.4, 91.9, 73.8,
    97.0, 55.6, 47.0, 61.3, 94.0, 142.3
  ];
  static const _izq = 456.0;
  static const _verdes = 400.2;
  static const _suma = 1457.2;

  Color _colorTipo(String t) {
    if (t == 'FALTANTE') return const Color(0xFFDC2626);
    if (t == 'SOBRANTE') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    double w(double x) => x * esc;

    Widget thSpanP(String t, double x) => Container(
        width: w(x),
        height: 75.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration:
            BoxDecoration(color: _purple, border: Border.all(color: _purpleBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget thGroupP(String t, double x) => Container(
        width: w(x),
        height: 28.2,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: _purple, border: Border.all(color: _purpleBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.2)));

    Widget thSubP(String t, double x) => Container(
        width: w(x),
        height: 47.4,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(4),
        decoration:
            BoxDecoration(color: _purple, border: Border.all(color: _purpleBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: Colors.white,
                height: 1.6)));

    Widget thGreen(String t, double x) => Container(
        width: w(x),
        height: 75.6,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration:
            BoxDecoration(color: _greenBg, border: Border.all(color: _green)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: _greenTxt,
                height: 1.6)));

    Widget cell(double x, String t,
        {AlignmentGeometry align = Alignment.centerLeft,
        bool neg = false,
        bool bold = false,
        Color? color,
        bool wrap = false}) {
      final st = TextStyle(
          fontSize: 14,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? (neg ? _neg : _txt));
      return Container(
          width: w(x),
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _cellBdr))),
          child: wrap
              ? Text(t, style: st)
              : Text(t,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: align == Alignment.center
                      ? TextAlign.center
                      : align == Alignment.centerRight
                          ? TextAlign.right
                          : TextAlign.left,
                  style: st));
    }

    Widget cellGreen(double x, String t,
        {AlignmentGeometry align = Alignment.centerLeft,
        Color? color,
        bool bold = false,
        double fs = 14,
        bool wrap = false}) {
      final st = TextStyle(
          fontSize: fs,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          color: color ?? _txt);
      return Container(
          width: w(x),
          alignment: align,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
              border: Border.fromBorderSide(BorderSide(color: _green))),
          child: wrap
              ? Text(t, style: st)
              : Text(t,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  textAlign: align == Alignment.center
                      ? TextAlign.center
                      : align == Alignment.centerRight
                          ? TextAlign.right
                          : TextAlign.left,
                  style: st));
    }

    var totSI = 0, totE = 0, totS = 0, totSF = 0, totCF = 0, totD = 0;
    num totVI = 0, totVE = 0, totVS = 0, totVF = 0, totB = 0;

    final filasWidgets = <Widget>[];
    for (var i = 0; i < filas.length; i++) {
      final r = filas[i];
      final neg = r.finC < 0;
      final tc = _colorTipo(r.tipo);
      final fuerte = r.tipo == 'FALTANTE' || r.tipo == 'SOBRANTE';
      totSI += r.iniC;
      totE += r.entC;
      totS += r.salC;
      totSF += r.finC;
      totVI += r.iniV;
      totVE += r.entV;
      totVS += r.salV;
      totVF += r.finV;
      if (r.cantFisica != null) totCF += r.cantFisica!;
      if (r.dif != null) totD += r.dif!;
      if (r.bs != null) totB += r.bs!;
      filasWidgets.add(_FilaTabla(
        i: i,
        child:
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          cell(_anchos[0], '${r.num}', neg: neg),
          cell(_anchos[1], r.codigo, neg: neg),
          cell(_anchos[2], r.descripcion, neg: neg, wrap: true),
          cell(_anchos[3], r.unidad, align: Alignment.center, neg: neg),
          cell(_anchos[4], f.format(r.pu),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[5], '${r.iniC}', align: Alignment.center, neg: neg),
          cell(_anchos[6], '${r.entC}', align: Alignment.center, neg: neg),
          cell(_anchos[7], '${r.salC}', align: Alignment.center, neg: neg),
          cell(_anchos[8], '${r.finC}',
              align: Alignment.center, neg: neg, bold: true),
          cell(_anchos[9], f.format(r.iniV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[10], f.format(r.entV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[11], f.format(r.salV),
              align: Alignment.centerRight, neg: neg),
          cell(_anchos[12], f.format(r.finV),
              align: Alignment.centerRight, neg: neg, bold: true),
          cellGreen(_anchos[13], r.cantFisica != null ? '${r.cantFisica}' : '—',
              align: Alignment.center),
          cellGreen(_anchos[14], r.dif != null ? '${r.dif}' : '—',
              align: Alignment.center,
              color: tc,
              bold: fuerte),
          cellGreen(_anchos[15], r.tipo.isEmpty ? '—' : r.tipo,
              align: Alignment.center,
              color: tc,
              bold: fuerte),
          cellGreen(_anchos[16], r.bs != null ? f.format(r.bs) : '—',
              align: Alignment.centerRight,
              color: tc,
              bold: fuerte),
          cellGreen(_anchos[17], r.obs,
              align: Alignment.centerLeft, fs: 11.52, wrap: true),
        ]),
      ));
    }

    Widget footCellP(double x, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w(x),
            height: 21,
            alignment: align,
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border:
                    Border.fromBorderSide(BorderSide(color: Color(0xFF999999)))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)));

    Widget footCellG(double x, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w(x),
            height: 21,
            alignment: align,
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border.fromBorderSide(BorderSide(color: _green))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: _txt)));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        thSpanP('N°', _anchos[0]),
        thSpanP('CODIGO', _anchos[1]),
        thSpanP('DESCRIPCION (ITEM)', _anchos[2]),
        thSpanP('UNIDAD\nDE\nMEDIDA', _anchos[3]),
        thSpanP('PRECIO\nUNITARIO', _anchos[4]),
        thGroupP('CANTIDAD', 253.9),
        thGroupP('VALORES', 347.1),
        thGreen('CANT.\nFISICO', _anchos[13]),
        thGreen('DIF.\nCANT', _anchos[14]),
        thGreen('TIPO', _anchos[15]),
        thGreen('BS\nDIFERENCIA', _anchos[16]),
        thGreen('OBSERVACIONES', _anchos[17]),
      ]),
      Row(children: [
        SizedBox(width: w(_izq)),
        thSubP('SALDO\nINICIAL', _anchos[5]),
        thSubP('ENTRADAS', _anchos[6]),
        thSubP('SALIDAS', _anchos[7]),
        thSubP('SALDO\nFINAL', _anchos[8]),
        thSubP('SALDO\nINICIAL', _anchos[9]),
        thSubP('ENTRADAS', _anchos[10]),
        thSubP('SALIDAS', _anchos[11]),
        thSubP('SALDO\nFINAL', _anchos[12]),
        SizedBox(width: w(_verdes)),
      ]),
      ...filasWidgets,
      Row(children: [
        footCellP(_izq, 'TOTALES:', align: Alignment.centerRight),
        footCellP(_anchos[5], '$totSI', align: Alignment.center),
        footCellP(_anchos[6], '$totE', align: Alignment.center),
        footCellP(_anchos[7], '$totS', align: Alignment.center),
        footCellP(_anchos[8], '$totSF', align: Alignment.center),
        footCellP(_anchos[9], f.format(totVI), align: Alignment.centerRight),
        footCellP(_anchos[10], f.format(totVE), align: Alignment.centerRight),
        footCellP(_anchos[11], f.format(totVS), align: Alignment.centerRight),
        footCellP(_anchos[12], f.format(totVF), align: Alignment.centerRight),
        footCellG(_anchos[13], '$totCF', align: Alignment.center),
        footCellG(_anchos[14], '$totD', align: Alignment.center),
        footCellG(_anchos[15], ''),
        footCellG(_anchos[16], f.format(totB), align: Alignment.centerRight),
        footCellG(_anchos[17], ''),
      ]),
    ]);
  }
}

// ===========================================================================
// REGISTRAR (entrada de pedido + arqueo fisico)
// ===========================================================================

class _RegistrarTab extends StatefulWidget {
  const _RegistrarTab();
  @override
  State<_RegistrarTab> createState() => _RegistrarTabState();
}

class _RegistrarTabState extends State<_RegistrarTab> {
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _eItem;
  Map<String, dynamic>? _aItem;
  final _eCant = TextEditingController();
  final _eDoc = TextEditingController();
  final _eMot = TextEditingController();
  final _aFis = TextEditingController();
  final _aObs = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargarItems();
  }

  @override
  void dispose() {
    _eCant.dispose();
    _eDoc.dispose();
    _eMot.dispose();
    _aFis.dispose();
    _aObs.dispose();
    super.dispose();
  }

  Future<void> _cargarItems() async {
    _items = await cargarCatalogoItems();
    if (mounted) setState(() {});
  }

  Future<void> _entrada() async {
    final c = int.tryParse(_eCant.text.trim());
    if (_eItem == null || c == null) {
      snack(context, 'Complete item y cantidad', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.rpc('sp_entrada_inventario', {
        'p_item_id': _eItem!['id'],
        'p_cantidad': c,
        'p_numero_doc': _eDoc.text,
        'p_motivo': _eMot.text,
      });
      if (mounted) {
        snack(context, 'Entrada registrada');
        _eCant.clear();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _arqueo() async {
    final c = int.tryParse(_aFis.text.trim());
    if (_aItem == null || c == null) {
      snack(context, 'Complete item y cantidad', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.rpc('sp_toma_fisica', {
        'p_item_id': _aItem!['id'],
        'p_fisica': c,
        'p_obs': _aObs.text,
      });
      if (mounted) {
        snack(context, 'Arqueo registrado');
        _aFis.clear();
        _aObs.clear();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _campo(Widget w) => Padding(
      padding: const EdgeInsets.only(bottom: 10), child: w);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.arrow_circle_down,
                    titulo: 'Registrar Entrada / Pedido'),
                _campo(DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                      labelText: 'Item', hintText: 'Seleccione...'),
                  items: _items
                      .map((i) => DropdownMenuItem(
                          value: i,
                          child:
                              Text('${i['codigo']} - ${i['descripcion']}')))
                      .toList(),
                  onChanged: (i) => setState(() => _eItem = i),
                )),
                _campo(TextField(
                  controller: _eCant,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                )),
                _campo(TextField(
                  controller: _eDoc,
                  decoration: const InputDecoration(
                      labelText: 'N Documento / Pedido'),
                )),
                _campo(TextField(
                  controller: _eMot,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                )),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _entrada,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Registrar Entrada',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 7,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.assignment, titulo: 'Registrar Arqueo Fisico'),
                Row(children: [
                  Expanded(
                    flex: 4,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      decoration: const InputDecoration(
                          labelText: 'Item', hintText: 'Seleccione...'),
                      items: _items
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text(
                                  '${i['codigo']} - ${i['descripcion']}')))
                          .toList(),
                      onChanged: (i) => setState(() => _aItem = i),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _aFis,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Cant. Fisica'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextField(
                      controller: _aObs,
                      decoration: const InputDecoration(
                          labelText: 'Observaciones',
                          hintText: 'Ej: Conciliar con kardex almacenes'),
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _arqueo,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Registrar Arqueo',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// APERTURA UNICA
// ===========================================================================

class _AperturaTab extends StatefulWidget {
  final VoidCallback? onResumen;
  const _AperturaTab({this.onResumen});
  @override
  State<_AperturaTab> createState() => _AperturaTabState();
}

class _AperturaTabState extends State<_AperturaTab> {
  List<Map<String, dynamic>> _aps = [];
  List<Map<String, dynamic>> _items = [];
  final _ctrls = <int, TextEditingController>{};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    final aps = await Api.raw('apertura_inventario',
        columns: 'fecha', orderCol: 'id', asc: false, limit: 1);
    final items = await cargarCatalogoItems();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    _ctrls.clear();
    for (final it in items) {
      final id = ((it['id'] as num?)?.toInt()) ?? 0;
      _ctrls[id] = TextEditingController(text: '0');
    }
    _aps = aps;
    _items = items;
    if (mounted) setState(() {});
  }

  Future<void> _abrir() async {
    final registros = <Map<String, dynamic>>[];
    for (final it in _items) {
      final id = ((it['id'] as num?)?.toInt()) ?? 0;
      final c = int.tryParse(_ctrls[id]?.text.trim() ?? '') ?? 0;
      if (c > 0) registros.add({'itemId': id, 'cantidad': c});
    }
    if (registros.isEmpty) {
      snack(context, 'Ingrese cantidades mayores a cero para al menos un item');
      return;
    }
    final ok = await _confirmar(
      context,
      titulo: 'Apertura de Inventario',
      mensaje:
          'Se registrara la apertura UNICA de ${registros.length} item(s). Desea continuar?',
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.rpc('sp_apertura_inventario', {
        'p_sucursal_id': 1,
        'p_registros': registros,
      });
      if (mounted) {
        snack(context, 'Apertura de inventario registrada');
        await _cargar();
        widget.onResumen?.call();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registrada = _aps.isNotEmpty;
    final fecha = _aps.isNotEmpty ? '${_aps.first['fecha']}' : '';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.lock_open,
                    titulo: 'Apertura de Inventario (unica vez)'),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: registrada
                        ? const Color(0xFFD1E7DD)
                        : const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    registrada
                        ? 'Apertura registrada el $fecha (unica vez). Ya no puede modificarse.'
                        : 'Pendiente: registre el stock fisico inicial de todos los items.',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: registrada
                            ? const Color(0xFF0F5132)
                            : const Color(0xFF664D03)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Registra por unica vez el stock fisico inicial de cada item. Una vez registrada no puede volver a habilitarse para la sucursal.',
                  style: TextStyle(fontSize: 12, color: T.texto2(context)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: registrada || _busy ? null : _abrir,
                    icon: const Icon(Icons.check_circle, size: 16),
                    label: const Text(
                        'Registrar Apertura con cantidades ingresadas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade400,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 8,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.checklist,
                    titulo: 'Stock Fisico Inicial por Item'),
                SizedBox(
                  height: 420,
                  child: SingleChildScrollView(
                    child: TablaModerna(
                      anchoTotal: 560,
                      columnas: const ['Codigo', 'Item', 'Cantidad Fisica'],
                      filas: [
                        for (final it in _items)
                          DataRow(cells: [
                            DataCell(Text('${it['codigo']}')),
                            DataCell(Text('${it['descripcion']}')),
                            DataCell(SizedBox(
                              width: 130,
                              child: TextField(
                                controller:
                                    _ctrls[((it['id'] as num?)?.toInt()) ?? 0],
                                decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 10)),
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontSize: 13),
                              ),
                            )),
                          ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// PEDIDOS DE REPOSICION
// ===========================================================================

class _PedidosTab extends StatefulWidget {
  final VoidCallback? onResumen;
  const _PedidosTab({this.onResumen});
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
    _cant.text = '1';
    _cargar();
  }

  @override
  void dispose() {
    _cant.dispose();
    _doc.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    _items = await cargarCatalogoItems();
    final ped = await Api.raw('pedido_reposicion',
        columns:
            '*, item:item_valorado(descripcion,codigo), reg:usuario_sistema!pedido_reposicion_registrado_por_fkey(nombre), apr:usuario_sistema!pedido_reposicion_aprobado_por_fkey(nombre)',
        orderCol: 'id');
    // Java: OrderByFechaDescIdDesc (mas reciente primero)
    ped.sort((a, b) {
      final c = '${b['fecha']}'.compareTo('${a['fecha']}');
      if (c != 0) return c;
      return (((b['id'] as num?) ?? 0).toInt())
          .compareTo((((a['id'] as num?) ?? 0).toInt()));
    });
    _pedidos = ped;
    if (mounted) setState(() {});
  }

  Future<void> _emitir() async {
    final c = int.tryParse(_cant.text.trim());
    if (_itemSel == null || c == null) {
      snack(context, 'Seleccione item y cantidad');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_emitir_pedido', {
        'p_item_id': _itemSel!['id'],
        'p_cantidad': c,
        'p_doc': _doc.text.trim().isEmpty ? null : _doc.text.trim(),
      });
      if (mounted) {
        snack(context, 'Pedido emitido: ${res['numero_pedido'] ?? ''}');
        _cant.text = '1';
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: const _CabeceraModal('Recepcion de Pedido'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
              labelText: 'Cantidad recibida fisicamente'),
        ),
        actions: [
          BtnSecundario('Cancelar',
              onPressed: () => Navigator.pop(ctx, false)),
          BtnPrimario('Registrar',
              onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final cr = int.tryParse(c.text.trim());
      await Api.rpc('sp_recepcionar_pedido', {
        'p_pedido_id': p['id'],
        // JS de Java: parseInt(cant)||null (0 o vacio => null)
        'p_cantidad_recibida': (cr == null || cr == 0) ? null : cr,
      });
      if (mounted) {
        snack(context, 'Recepcion registrada');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _aprobar(Map<String, dynamic> p) async {
    final ok = await _confirmar(
      context,
      titulo: 'Aprobar Pedido',
      mensaje:
          'Aprobar y generar entrada de Kardex? (Requiere rol TESORERIA/ADMIN distinto del registrador)',
      okLabel: 'Aprobar',
    );
    if (!ok) return;
    try {
      await Api.rpc('sp_aprobar_pedido', {'p_pedido_id': p['id']});
      if (mounted) {
        snack(context, 'Pedido aprobado y entrada registrada');
        _cargar();
        widget.onResumen?.call();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _anular(Map<String, dynamic> p) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: const _CabeceraModal('Anular Pedido'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
                labelText: 'Motivo de anulacion del pedido:'),
          ),
          actions: [
            BtnSecundario('Cancelar',
                onPressed: () => Navigator.pop(ctx, null)),
            BtnPrimario('Anular', onPressed: () => Navigator.pop(ctx, ctrl.text)),
          ],
        );
      },
    );
    if (motivo == null || motivo.trim().isEmpty) return;
    try {
      await Api.rpc('sp_anular_pedido', {
        'p_pedido_id': p['id'],
        'p_motivo': motivo.trim(),
      });
      if (mounted) {
        snack(context, 'Pedido anulado');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.note_add, titulo: 'Emitir Pedido'),
                DropdownButtonFormField<Map<String, dynamic>>(
                  decoration: const InputDecoration(
                      labelText: 'Item', hintText: 'Seleccione...'),
                  items: _items
                      .map((i) => DropdownMenuItem(
                          value: i,
                          child:
                              Text('${i['codigo']} - ${i['descripcion']}')))
                      .toList(),
                  onChanged: (i) => setState(() => _itemSel = i),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cant,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Cantidad'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _doc,
                  decoration: const InputDecoration(
                      labelText: 'Documento de respaldo',
                      hintText: 'Ej: OC-001'),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _emitir,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Emitir Pedido',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Flujo: EMITIDO → recepción → aprobación con doble firma (aprueba TESORERÍA/ADMIN distinto del registrador).',
                  style: TextStyle(fontSize: 11, color: T.texto2(context)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          flex: 8,
          child: SoftCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CardHeaderSection(
                    icon: Icons.assignment, titulo: 'Estado de Pedidos'),
                SizedBox(
                  height: 460,
                  child: SingleChildScrollView(
                    child: TablaModerna(
                      anchoTotal: 760,
                      columnas: const [
                        'N°',
                        'Fecha',
                        'Item',
                        'Cant.',
                        'Recib.',
                        'Estado',
                        'Acciones',
                      ],
                      filas: [
                        if (_pedidos.isEmpty)
                          DataRow(cells: [
                            const DataCell(Text('Sin pedidos')),
                            ...List.generate(
                                6, (_) => const DataCell(SizedBox.shrink())),
                          ]),
                        for (final p in _pedidos)
                          DataRow(cells: [
                            DataCell(Text('${p['numero_pedido']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(Text('${p['fecha'] ?? ''}')),
                            DataCell(Text('${p['item']?['descripcion'] ?? ''}')),
                            DataCell(Text('${p['cantidad']}')),
                            DataCell(Text('${p['cantidad_recibida'] ?? '—'}')),
                            DataCell(_BadgePedido(
                                '${p['estado'] ?? 'EMITIDO'}')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (p['estado'] == 'EMITIDO' ||
                                    p['estado'] == 'PARCIAL') ...[
                                  _BtnIconoAccion(
                                    color: const Color(0xFF2563EB),
                                    icon: Icons.input,
                                    tooltip: 'Recepcionar',
                                    onTap: () => _recepcionar(p),
                                  ),
                                  const SizedBox(width: 6),
                                  _BtnIconoAccion(
                                    color: const Color(0xFF16A34A),
                                    icon: Icons.check,
                                    tooltip: 'Aprobar (doble firma)',
                                    onTap: () => _aprobar(p),
                                  ),
                                  const SizedBox(width: 6),
                                  _BtnIconoAccion(
                                    color: const Color(0xFFDC2626),
                                    icon: Icons.cancel,
                                    tooltip: 'Anular',
                                    onTap: () => _anular(p),
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
        ),
      ],
    );
  }
}

// ===========================================================================
// AUXILIARES
// ===========================================================================

Future<bool> _confirmar(BuildContext context,
    {required String titulo,
    required String mensaje,
    String okLabel = 'Confirmar'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: _CabeceraModal(titulo),
      content: Text(mensaje,
          style: TextStyle(fontSize: 14, color: T.texto(ctx))),
      actions: [
        BtnSecundario('Cancelar', onPressed: () => Navigator.pop(ctx, false)),
        BtnPrimario(okLabel, onPressed: () => Navigator.pop(ctx, true)),
      ],
    ),
  );
  return res ?? false;
}

class _CabeceraModal extends StatelessWidget {
  final String titulo;
  const _CabeceraModal(this.titulo);

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
              colors: [Color(0xFF1E3A5F), Color(0xFF3B82F6)]),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Text(titulo,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      );
}

class _BtnBarra extends StatelessWidget {
  final String texto;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool outline;
  const _BtnBarra(
      {required this.texto,
      required this.icon,
      required this.color,
      this.onPressed,
      this.outline = false});

  @override
  Widget build(BuildContext context) {
    final child = Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14),
      const SizedBox(width: 5),
      Text(texto,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ]);
    if (outline) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(0, 32),
          visualDensity: VisualDensity.compact,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: child,
      );
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 32),
        visualDensity: VisualDensity.compact,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: child,
    );
  }
}

class _BtnIconoAccion extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _BtnIconoAccion(
      {required this.color,
      required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 30,
          height: 28,
          child: OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 28),
              foregroundColor: color,
              side: BorderSide(color: color),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: Icon(icon, size: 15),
          ),
        ),
      );
}

class _BadgePedido extends StatelessWidget {
  final String estado;
  const _BadgePedido(this.estado);

  Color get _c {
    if (estado == 'COMPLETO') return const Color(0xFF16A34A);
    if (estado == 'ANULADO') return const Color(0xFFDC2626);
    if (estado == 'PARCIAL') return const Color(0xFFD97706);
    return const Color(0xFF2563EB);
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _c.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(estado,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _c)),
      );
}
