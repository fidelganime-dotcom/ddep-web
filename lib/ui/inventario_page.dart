import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';
import 'tema.dart';

String _fLarga(DateTime d) => '${d.day}/${d.month}/${d.year}';

class InventarioPage extends StatefulWidget {
  const InventarioPage({super.key});
  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  DateTime _fecha = DateTime.now();

  @override
  void initState() {
    super.initState();
    final rol = sesionOf(context).perfil?.rol ?? '';
    final n = rol == 'AUDITOR' ? 2 : 4;
    _tab = TabController(length: n, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _fIso(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final soloLectura = rol == 'AUDITOR';
    final tabs = <Widget>[
      const Tab(text: 'KARDEX POR ITEM'),
      const Tab(text: 'ARQUEO DE CAJA'),
      if (!soloLectura) const Tab(text: 'APERTURA'),
      if (!soloLectura) const Tab(text: 'PEDIDOS'),
    ];
    final views = <Widget>[
      const _KardexTab(),
      _ArqueoTab(fecha: _fecha),
      if (!soloLectura) const _AperturaTab(),
      if (!soloLectura) const _PedidosTab(),
    ];
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
                  decoration: const InputDecoration(
                      labelText: 'Sucursal', isDense: true),
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
                  onPressed: () => _tab.animateTo(0)),
              _BtnBarra(
                  texto: 'Arqueo de Caja',
                  icon: Icons.assignment_turned_in,
                  color: const Color(0xFF8B5CF6),
                  onPressed: () => _tab.animateTo(1)),
              _BtnBarra(
                  texto: 'GRAL PDF',
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => snack(
                      context, 'Reporte no disponible en la versión web')),
              _BtnBarra(
                  texto: 'GRAL Excel',
                  icon: Icons.table_view,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => snack(
                      context, 'Reporte no disponible en la versión web')),
              _BtnBarra(
                  texto: 'ARQUEO PDF',
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => snack(
                      context, 'Reporte no disponible en la versión web')),
              _BtnBarra(
                  texto: 'ARQUEO Excel',
                  icon: Icons.table_view,
                  color: const Color(0xFF64748B),
                  outline: true,
                  onPressed: () => snack(
                      context, 'Reporte no disponible en la versión web')),
            ],
          ),
        ),
        TabBar(controller: _tab, tabs: tabs),
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 300,
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

  void _verSeleccionado() {
    final item = _drop;
    if (item == null) {
      snack(context, 'Seleccione un item');
      return;
    }
    _ver(item);
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
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
                      onPressed: () => snack(
                          context, 'Reporte no disponible en la versión web')),
                  _BtnBarra(
                      texto: 'Excel',
                      icon: Icons.table_view,
                      color: Colors.white,
                      outline: true,
                      onPressed: () => snack(
                          context, 'Reporte no disponible en la versión web')),
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
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _KardexTabla(movs: _movs),
              ),
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
    );
  }
}

class _KardexTabla extends StatelessWidget {
  final List<Map<String, dynamic>> movs;
  const _KardexTabla({required this.movs});

  static const _navy = Color(0xFF1E3A5F);
  static const _hdrBdr = Color(0xFF4A90D9);
  static const _cellBdr = Color(0xFFD1D5DB);
  static const _neg = Color(0xFFDC2626);
  static const _txt = Color(0xFF1E293B);
  static const _anchoIzq = 610.0;
  static const _anchos = <double>[
    40, 90, 170, 90, 40, 40, 60, 80, 65, 65, 65, 65, 80, 80, 80, 80
  ];

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

    Widget thSpan(String t, double w) => Container(
        width: w,
        height: 52,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
            color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15)));

    Widget thGroup(String t, double w) => Container(
        width: w,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white)));

    Widget thSub(String t, double w) => Container(
        width: w,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: _navy, border: Border.all(color: _hdrBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.1)));

    Widget cell(double w, String t,
            {AlignmentGeometry align = Alignment.center,
            bool neg = false,
            bool bold = false}) =>
        Container(
            width: w,
            height: 26,
            alignment: align,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: const BoxDecoration(
                color: Colors.white,
                border: Border.fromBorderSide(BorderSide(color: _cellBdr))),
            child: Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: neg ? _neg : _txt)));

    final filas = <Widget>[];
    num totEnt = 0, totSal = 0;
    var finC = '0';
    var finV = '0.00';
    for (var idx = 0; idx < movs.length; idx++) {
      final m = movs[idx];
      final tipo = '${m['tipo'] ?? ''}';
      final cant = (m['cantidad'] as num?) ?? 0;
      final valor = (m['valor'] as num?) ?? 0;
      final esEntrada = tipo.startsWith('ENTRADA');
      final ent = (m['cantidad_entradas'] as num?) ??
          (esEntrada ? cant : 0);
      final sal = (m['cantidad_salidas'] as num?) ??
          (!esEntrada && tipo != 'APERTURA' ? cant : 0);
      final vEnt =
          (m['valor_entradas'] as num?) ?? (esEntrada ? valor : 0);
      final vSal = (m['valor_salidas'] as num?) ??
          (!esEntrada && tipo != 'APERTURA' ? valor : 0);
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
      filas.add(Row(children: [
        cell(_anchos[0], '${idx + 1}', neg: neg),
        cell(_anchos[1], '${m['fecha'] ?? ''}',
            align: Alignment.centerLeft, neg: neg),
        cell(_anchos[2], desc, align: Alignment.centerLeft, neg: neg),
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
      ]));
    }

    Widget footCell(double w, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w,
            height: 28,
            alignment: align,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border:
                    Border.fromBorderSide(BorderSide(color: Color(0xFF999999)))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _txt)));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        thSpan('N°', _anchos[0]),
        thSpan('FECHA', _anchos[1]),
        thSpan('DESCRIPCION', _anchos[2]),
        thSpan('N° DOC.', _anchos[3]),
        thSpan('DEL', _anchos[4]),
        thSpan('AL', _anchos[5]),
        thSpan('UNIDAD', _anchos[6]),
        thSpan('PRECIO UNITARIO', _anchos[7]),
        thGroup('CANTIDAD', 260),
        thGroup('VALORES (BS)', 320),
      ]),
      Row(children: [
        SizedBox(width: _anchoIzq),
        thSub('SALDO INICIAL', _anchos[8]),
        thSub('ENTRADAS', _anchos[9]),
        thSub('SALIDAS', _anchos[10]),
        thSub('SALDO FINAL', _anchos[11]),
        thSub('SALDO INICIAL', _anchos[12]),
        thSub('ENTRADAS', _anchos[13]),
        thSub('SALIDAS', _anchos[14]),
        thSub('SALDO FINAL', _anchos[15]),
      ]),
      ...filas,
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

class _ArqueoTab extends StatefulWidget {
  final DateTime fecha;
  const _ArqueoTab({required this.fecha});
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
    if (_sel == null || _fisica.text.isEmpty) {
      snack(context, 'Complete item y cantidad', error: true);
      return;
    }
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
    return SoftCard(
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
              child: Text('ARQUEO DE CAJA — Al ${_fLarga(widget.fecha)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            if (puede)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    SizedBox(
                      width: 320,
                      child: DropdownButtonFormField<Map<String, dynamic>>(
                        decoration: const InputDecoration(
                            labelText: 'Item', hintText: 'Seleccione...'),
                        items: _items
                            .map((i) => DropdownMenuItem(
                                value: i,
                                child: Text(
                                    '${i['codigo']} — ${i['descripcion']}')))
                            .toList(),
                        onChanged: (i) => setState(() => _sel = i),
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: TextField(
                        controller: _fisica,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Cant. Fisica'),
                      ),
                    ),
                    SizedBox(
                      width: 260,
                      child: TextField(
                        controller: _obs,
                        decoration: const InputDecoration(
                            labelText: 'Observaciones',
                            hintText: 'Ej: Conciliar con kardex almacenes'),
                      ),
                    ),
                    _BtnBarra(
                        texto: 'Registrar Arqueo',
                        icon: Icons.check,
                        color: const Color(0xFFF59E0B),
                        onPressed: _busy ? null : _registrar),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _ArqueoTabla(tomas: _tomas.reversed.toList()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArqueoTabla extends StatelessWidget {
  final List<Map<String, dynamic>> tomas;
  const _ArqueoTabla({required this.tomas});

  static const _purple = Color(0xFF8B5CF6);
  static const _purpleBdr = Color(0xFF9966CC);
  static const _green = Color(0xFF27AE60);
  static const _greenBg = Color(0xFFD4EDDA);
  static const _cellBdr = Color(0xFFD1D5DB);
  static const _txt = Color(0xFF1E293B);
  static const _anchos = <double>[40, 90, 200, 80, 80, 90, 100, 200];

  Color _colorTipo(String? t) {
    if (t == 'FALTANTE') return const Color(0xFFDC2626);
    if (t == 'SOBRANTE') return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    num totCF = 0, totD = 0, totB = 0;

    Widget thP(String t, double w) => Container(
        width: w,
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
            color: _purple, border: Border.all(color: _purpleBdr)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15)));

    Widget thG(String t, double w) => Container(
        width: w,
        height: 42,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration:
            BoxDecoration(color: _greenBg, border: Border.all(color: _green)),
        child: Text(t,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.15)));

    Widget cell(double w, String t,
            {AlignmentGeometry align = Alignment.center,
            Color color = _txt,
            Color border = _cellBdr,
            bool bold = false,
            double fs = 11}) =>
        Container(
            width: w,
            height: 26,
            alignment: align,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
                color: Colors.white, border: Border.all(color: border)),
            child: Text(t,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: fs,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                    color: color)));

    final filas = <Widget>[];
    for (var idx = 0; idx < tomas.length; idx++) {
      final t = tomas[idx];
      final item = t['item'] is Map
          ? (t['item'] as Map).cast<String, dynamic>()
          : null;
      final cf = (t['cantidad_fisica'] as num?);
      final dif = (t['diferencia'] as num?);
      final bs = (t['bs_diferencia'] as num?);
      final tipo = t['tipo_diferencia']?.toString();
      final tc = _colorTipo(tipo);
      final fuerte = tipo == 'FALTANTE' || tipo == 'SOBRANTE';
      if (cf != null) totCF += cf;
      if (dif != null) totD += dif;
      if (bs != null) totB += bs;
      filas.add(Row(children: [
        cell(_anchos[0], '${idx + 1}'),
        cell(_anchos[1], '${item?['codigo'] ?? ''}',
            align: Alignment.centerLeft),
        cell(_anchos[2], '${item?['descripcion'] ?? ''}',
            align: Alignment.centerLeft),
        cell(_anchos[3], cf != null ? '$cf' : '—', border: _green),
        cell(_anchos[4], dif != null ? '$dif' : '—',
            color: tc, bold: fuerte),
        cell(_anchos[5], tipo ?? '—', color: tc, bold: fuerte),
        cell(_anchos[6], bs != null ? f.format(bs) : '—',
            align: Alignment.centerRight, color: tc, bold: fuerte),
        cell(_anchos[7], '${t['observaciones'] ?? ''}',
            align: Alignment.centerLeft, fs: 10),
      ]));
    }

    Widget gCell(double w, String t,
            {AlignmentGeometry align = Alignment.center}) =>
        Container(
            width: w,
            height: 28,
            alignment: align,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border.fromBorderSide(BorderSide(color: _green))),
            child: Text(t,
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _txt)));

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        thP('N°', _anchos[0]),
        thP('CODIGO', _anchos[1]),
        thP('DESCRIPCION (ITEM)', _anchos[2]),
        thG('CANT. FISICO', _anchos[3]),
        thG('DIF. CANT', _anchos[4]),
        thG('TIPO', _anchos[5]),
        thG('BS DIFERENCIA', _anchos[6]),
        thG('OBSERVACIONES', _anchos[7]),
      ]),
      ...filas,
      Row(children: [
        Container(
            width: 330,
            height: 28,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
                color: Color(0xFFE2E8F0),
                border: Border.fromBorderSide(
                    BorderSide(color: Color(0xFF999999)))),
            child: const Text('TOTALES:',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _txt))),
        gCell(_anchos[3], '$totCF'),
        gCell(_anchos[4], '$totD'),
        gCell(_anchos[5], ''),
        gCell(_anchos[6], f.format(totB), align: Alignment.centerRight),
        gCell(_anchos[7], ''),
      ]),
    ]);
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
    if (_itemSel == null || _cant.text.isEmpty) {
      snack(context, 'Seleccione item y cantidad');
      return;
    }
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
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: const _CabeceraModal('Recepción de Pedido'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cantidad recibida'),
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
    final ok = await _confirmar(
      context,
      titulo: 'Aprobar Pedido',
      mensaje:
          'Aprobar y generar entrada de Kardex? (Requiere rol TESORERIA/ADMIN distinto del registrador)',
      okLabel: 'Aprobar',
    );
    if (!ok) return;
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
    final puede =
        rol == 'ADMIN' || rol == 'CAJERA' || rol == 'TESORERIA';
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
                if (puede) ...[
                  DropdownButtonFormField<Map<String, dynamic>>(
                    decoration: const InputDecoration(
                        labelText: 'Item', hintText: 'Seleccione...'),
                    items: _items
                        .map((i) => DropdownMenuItem(
                            value: i,
                            child:
                                Text('${i['codigo']} — ${i['descripcion']}')))
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
                  height: 420,
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
                        for (final p in _pedidos.reversed)
                          DataRow(cells: [
                            DataCell(Text('${p['numero_pedido']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(Text('${p['fecha'] ?? ''}')),
                            DataCell(Text(
                                '${p['item']?['codigo'] ?? ''} ${p['item']?['descripcion'] ?? ''}')),
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
                                  if (p['cantidad_recibida'] != null) ...[
                                    const SizedBox(width: 6),
                                    _BtnIconoAccion(
                                      color: const Color(0xFF16A34A),
                                      icon: Icons.check,
                                      tooltip: 'Aprobar (doble firma)',
                                      onTap: () => _aprobar(p),
                                    ),
                                  ],
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

class _AperturaTab extends StatefulWidget {
  const _AperturaTab();
  @override
  State<_AperturaTab> createState() => _AperturaTabState();
}

class _AperturaTabState extends State<_AperturaTab> {
  List<Map<String, dynamic>> _aps = [];
  List<Map<String, dynamic>> _items = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _aps = await Api.raw('apertura_inventario',
        columns: '*, reg:usuario_sistema(nombre)', orderCol: 'id');
    _items = await cargarCatalogoItems();
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
    final registrada = _aps.isNotEmpty;
    final fecha = _aps.isNotEmpty ? '${_aps.last['fecha']}' : '';
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
                  style:
                      TextStyle(fontSize: 12, color: T.texto2(context)),
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
                TablaModerna(
                  anchoTotal: 520,
                  columnas: const ['Codigo', 'Item'],
                  filas: [
                    for (final it in _items)
                      DataRow(cells: [
                        DataCell(Text('${it['codigo']}')),
                        DataCell(Text('${it['descripcion']}')),
                      ]),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

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
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _c)),
      );
}
