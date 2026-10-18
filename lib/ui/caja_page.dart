import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';
import 'tema.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({super.key});
  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage> {
  Map<String, dynamic>? _apertura;
  Map<String, dynamic>? _cierre;
  List<Map<String, dynamic>> _historial = [];
  final _fondo = TextEditingController(text: '150');
  final _contado = TextEditingController();
  final _deposito = TextEditingController(text: '0');
  bool _busy = false;

  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _ventaSel;
  Map<String, dynamic>? _itemSel;
  final _cant = TextEditingController();
  final _motivo = TextEditingController();
  bool _busyNota = false;
  bool _notasListas = false;

  List<Map<String, dynamic>> _deps = [];
  final _monto = TextEditingController();
  final _cuenta = TextEditingController(text: 'Banco Unión');
  final _numero = TextEditingController();

  List<Map<String, dynamic>> _ventas = [];
  String _mensaje = '';
  bool _mensajeError = false;

  static const Map<String, String> _bancos = {
    'BANCO_UNION': 'Banco Union',
    'BNB': 'Banco Nacional de Bolivia',
    'BANCO_FIE': 'Banco Fie',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _fondo.dispose();
    _contado.dispose();
    _deposito.dispose();
    _cant.dispose();
    _motivo.dispose();
    _monto.dispose();
    _cuenta.dispose();
    _numero.dispose();
    super.dispose();
  }

  double _n(dynamic v) =>
      v is num ? v.toDouble() : (double.tryParse('${v ?? ''}') ?? 0);

  String? _codigoBanco(String texto) {
    final t = texto
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áäâ]'), 'a')
        .replaceAll(RegExp('[éëê]'), 'e')
        .replaceAll(RegExp('[íïî]'), 'i')
        .replaceAll(RegExp('[óöô]'), 'o')
        .replaceAll(RegExp('[úüû]'), 'u');
    if (t.isEmpty) return null;
    if (t.contains('union')) return 'BANCO_UNION';
    if (t.contains('nacional') || t == 'bnb') return 'BNB';
    if (t.contains('fie')) return 'BANCO_FIE';
    return null;
  }

  void _setMensaje(String msg, {bool error = false}) {
    _mensaje = msg;
    _mensajeError = error;
  }

  Future<void> _cargar() async {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final aps = await Api.raw('apertura_caja',
        columns: '*, caj:usuario_sistema(nombre)',
        eqField: 'fecha',
        eqVal: hoy);
    final ccs = await Api.raw('cierre_caja',
        columns: '*, val:usuario_sistema!cierre_caja_validado_por_fkey(nombre)',
        eqField: 'fecha',
        eqVal: hoy);
    final hist = await Api.raw('cierre_caja',
        columns: '*, caj:usuario_sistema!cierre_caja_cajero_id_fkey(nombre)',
        orderCol: 'id');
    final items = await Api.raw('item_valorado',
        columns: 'id,codigo,descripcion,precio_unitario_vigente',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);
    final notas = await Api.raw('nota_ajuste',
        columns:
            '*, sol:usuario_sistema!nota_ajuste_solicitado_por_fkey(nombre), apr:usuario_sistema!nota_ajuste_autorizado_por_fkey(nombre), venta:venta(numero_recibo)',
        orderCol: 'id');
    final deps =
        await Api.raw('deposito_bancario', columns: '*', orderCol: 'id');
    final ventas = await Api.raw('venta',
        columns: 'id,numero_recibo,total,estado,fecha', orderCol: 'id');
    if (mounted) {
      setState(() {
        _apertura = aps.isEmpty ? null : aps.first;
        _cierre = ccs.isEmpty ? null : ccs.first;
        _historial = hist;
        _items = items;
        _notas = notas;
        _deps = deps;
        _ventas = ventas;
        _notasListas = true;
      });
    }
  }

  Future<void> _abrir() async {
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_apertura_caja', {
        'p_fondo': double.parse(_fondo.text),
      });
      if (mounted) {
        _setMensaje('Caja abierta con fondo Bs ${res['fondo']}');
        snack(context, 'Caja abierta con fondo Bs ${res['fondo']}');
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        _setMensaje(Api.err(e), error: true);
        snack(context, Api.err(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cerrar() async {
    setState(() => _busy = true);
    try {
      final res = await Api.rpc('sp_cierre_caja', {
        'p_contado': double.parse(_contado.text),
        'p_deposito': double.parse(_deposito.text),
      });
      if (mounted) {
        final msg =
            'Cierre registrado — esperado Bs ${res['esperado']}, diferencia Bs ${res['diferencia']}';
        _setMensaje(msg);
        snack(context, msg);
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        _setMensaje(Api.err(e), error: true);
        snack(context, Api.err(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _validar(Map<String, dynamic> c) async {
    try {
      await Api.rpc('sp_validar_cierre', {'p_cierre_id': c['id']});
      if (mounted) {
        snack(context, 'Cierre validado');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _buscarVenta() async {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await Api.raw('venta',
        columns: 'id,numero_recibo,total,estado', orderCol: 'id');
    final hoyRows =
        rows.where((v) => v['fecha'] == hoy || true).take(50).toList().reversed;
    if (!mounted) return;
    final sel = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const _TituloModal(
          gradiente: LinearGradient(
              colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
          icon: Icons.receipt_long,
          texto: 'Seleccionar venta',
        ),
        content: SizedBox(
          width: 420,
          height: 320,
          child: ListView(
            children: [
              for (final v in hoyRows.take(30))
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(ctx, v),
                  hoverColor: T.tableHover,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: Text(
                        '${v['numero_recibo']} — Bs ${v['total']} (${v['estado']})',
                        style: TextStyle(fontSize: 13.5, color: T.texto(ctx))),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (sel != null) setState(() => _ventaSel = sel);
  }

  Future<void> _crear() async {
    if (_ventaSel == null || _itemSel == null || _cant.text.isEmpty) {
      snack(context, 'Seleccione venta, ítem y cantidad', error: true);
      return;
    }
    setState(() => _busyNota = true);
    try {
      final q = int.parse(_cant.text);
      final res = await Api.rpc('sp_crear_nota_ajuste', {
        'p_venta': _ventaSel!['id'],
        'p_items': [
          {
            'item_id': _itemSel!['id'],
            'cantidad': q,
            'precio_unitario': _itemSel!['precio_unitario_vigente'],
          }
        ],
        'p_motivo': _motivo.text.trim().isEmpty
            ? 'Ajuste por inventario'
            : _motivo.text.trim(),
      });
      if (mounted) {
        snack(context, 'Nota ${res['numero']} creada (PENDIENTE)');
        _ventaSel = null;
        _itemSel = null;
        _cant.clear();
        _motivo.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busyNota = false);
    }
  }

  Future<void> _autorizar(Map<String, dynamic> n, bool ok, String motivo) async {
    try {
      if (ok) {
        await Api.rpc('sp_autorizar_nota', {'p_nota_id': n['id']});
      } else {
        await Api.rpc('sp_rechazar_nota', {
          'p_nota_id': n['id'],
          'p_motivo': motivo.isEmpty ? 'Rechazado' : motivo,
        });
      }
      if (mounted) {
        snack(context, ok ? 'Nota autorizada' : 'Nota rechazada');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _agregar() async {
    if (_monto.text.isEmpty) return;
    try {
      final cierre = await Api.raw('cierre_caja',
          columns: 'id',
          eqField: 'fecha',
          eqVal: DateTime.now().toIso8601String().substring(0, 10));
      if (cierre.isEmpty) {
        snack(context, 'Primero cierre la caja del día', error: true);
        return;
      }
      await Api.c.from('deposito_bancario').insert({
        'cierre_caja_id': cierre.first['id'],
        'fecha_deposito': DateTime.now().toIso8601String().substring(0, 10),
        'monto': double.parse(_monto.text),
        'numero_cuenta': _cuenta.text,
        'numero_deposito': _numero.text,
      });
      if (mounted) {
        _setMensaje('Depósito registrado');
        snack(context, 'Depósito registrado');
        _monto.clear();
        _numero.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) {
        _setMensaje(Api.err(e), error: true);
        snack(context, Api.err(e), error: true);
      }
    }
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: T.texto2(context))),
      );

  Widget _filaInfo(String k, Widget v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
                child: Text(k,
                    style: TextStyle(fontSize: 12.5, color: T.texto2(context)))),
            const SizedBox(width: 8),
            Flexible(child: v),
          ],
        ),
      );

  Widget _cajaInfo(List<Widget> filas) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: T.esOscuro(context) ? T.darkHover : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(children: filas),
      );

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    final rol = sesionOf(context).perfil?.rol ?? '';
    final puedeOperar = rol == 'ADMIN' || rol == 'CAJERA';
    final puedeCrear = rol == 'ADMIN' || rol == 'CAJERA';
    final puedeAutorizar = rol == 'ADMIN' || rol == 'TESORERIA';
    final puedeDeposito = rol == 'ADMIN' || rol == 'TESORERIA';
    final hoy = DateTime.now().toIso8601String().substring(0, 10);

    final efectivo = _cierre != null
        ? (_n(_cierre!['efectivo_contado']) != 0
            ? _n(_cierre!['efectivo_contado'])
            : _n(_cierre!['efectivo_esperado']))
        : _n(_apertura?['fondo_inicial']);
    final totalDep = _deps
        .where((d) => '${d['fecha_deposito']}' == hoy)
        .fold<double>(0, (a, d) => a + _n(d['monto']));
    final ventasHoy = _ventas
        .where((v) => '${v['fecha']}' == hoy && v['estado'] != 'ANULADA')
        .toList();
    final totalVentas =
        ventasHoy.fold<double>(0, (a, v) => a + _n(v['total']));
    final estadoCaja = _cierre != null
        ? 'CERRADA'
        : (_apertura != null ? 'ABIERTA' : 'SIN_APERTURA');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.payments, color: T.purple1, size: 26),
            const SizedBox(width: 10),
            Text('Caja',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: T.texto(context))),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            'Apertura, consolidado de ventas, cierre con triple cuadre y depósitos',
            style: TextStyle(fontSize: 14, color: T.texto2(context))),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (ctx, c) {
          final ancho = c.maxWidth;
          final cols = ancho >= 1200 ? 4 : (ancho >= 768 ? 2 : 1);
          final w = (ancho - 12 * (cols - 1)) / cols;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: w,
                child: _kpi(
                  bg: const Color(0xFFE3F2FD),
                  icon: Icons.payments,
                  iconColor: const Color(0xFF0D6EFD),
                  valor: Text('${f.format(efectivo)} Bs',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  etiqueta: 'Efectivo',
                ),
              ),
              SizedBox(
                width: w,
                child: _kpi(
                  bg: const Color(0xFFE8F5E9),
                  icon: Icons.account_balance,
                  iconColor: const Color(0xFF198754),
                  valor: Text('${f.format(totalDep)} Bs',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  etiqueta: 'Depósito / QR',
                ),
              ),
              SizedBox(
                width: w,
                child: _kpi(
                  bg: const Color(0xFFFFF8E1),
                  icon: Icons.receipt_long,
                  iconColor: const Color(0xFFFFC107),
                  valor: Text('${f.format(totalVentas)} Bs',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B))),
                  etiqueta: 'Total ventas (${ventasHoy.length})',
                ),
              ),
              SizedBox(
                width: w,
                child: _kpi(
                  bg: const Color(0xFFF3E8FF),
                  icon: Icons.lock,
                  iconColor: const Color(0xFF8B5CF6),
                  valor: _badgeEstadoCaja(estadoCaja),
                  etiqueta: 'Estado',
                ),
              ),
            ],
          );
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final ancho = c.maxWidth;
          final w = ancho >= 1100 ? (ancho - 24) / 3 : ancho;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: w, child: _cardApertura(f, puedeOperar)),
              SizedBox(width: w, child: _cardConsolidado(f, ventasHoy.length)),
              SizedBox(width: w, child: _cardArqueo(f, puedeOperar)),
            ],
          );
        }),
        const SizedBox(height: 4),
        LayoutBuilder(builder: (ctx, c) {
          final ancho = c.maxWidth;
          final w = ancho >= 1100 ? (ancho - 12) / 2 : ancho;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(width: w, child: _cardDeposito(f, puedeDeposito)),
              SizedBox(width: w, child: _cardFlujo()),
            ],
          );
        }),
        const SizedBox(height: 4),
        _cardNotas(puedeCrear, puedeAutorizar),
      ],
    );
  }

  Widget _kpi({
    required Color bg,
    required IconData icon,
    required Color iconColor,
    required Widget valor,
    required String etiqueta,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 30, color: iconColor),
          const SizedBox(height: 6),
          valor,
          const SizedBox(height: 2),
          Text(etiqueta,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _badgeEstadoCaja(String estado) {
    const cfg = <String, List<String>>{
      'SIN_APERTURA': ['#e2e8f0', '#475569', 'SIN APERTURA'],
      'ABIERTA': ['#dcfce7', '#16a34a', 'ABIERTA'],
      'CONSOLIDADA': ['#dbeafe', '#2563eb', 'CONSOLIDADA'],
      'CERRADA': ['#fef3c7', '#d97706', 'CERRADA'],
      'REABIERTA': ['#fee2e2', '#dc2626', 'REABIERTA'],
    };
    final c = cfg[estado] ?? ['#e2e8f0', '#475569', estado];
    return _BadgeColor(
        texto: c[2], bg: _hex(c[0]), fg: _hex(c[1]));
  }

  Color _hex(String h) =>
      Color(int.parse('FF${h.replaceFirst('#', '')}', radix: 16));

  Widget _badgeValidacion(dynamic val) {
    final v = '${val ?? '—'}';
    if (v == 'VALIDADO') {
      return const _BadgeColor(
          texto: 'VALIDADO', bg: Color(0xFFDCFCE7), fg: Color(0xFF16A34A));
    }
    if (v == 'REABIERTO') {
      return const _BadgeColor(
          texto: 'REABIERTO', bg: Color(0xFFFEE2E2), fg: Color(0xFFDC2626));
    }
    return _BadgeColor(
        texto: v, bg: const Color(0xFFE2E8F0), fg: const Color(0xFF475569));
  }

  Widget _btnHtml({
    required String texto,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool enabled = true,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 17),
        label: Text(texto,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withOpacity(.45),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _cardApertura(NumberFormat f, bool puedeOperar) {
    final abierta = _apertura != null;
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.login, titulo: '1. Inicio de Caja'),
          _label('Fondo Inicial (Bs)'),
          TextField(
            controller: _fondo,
            enabled: !abierta,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 10),
          Text(
            abierta
                ? 'Fondo inicial registrado: Bs ${f.format(_n(_apertura!['fondo_inicial']))}'
                : 'La caja aun no ha sido iniciada hoy.',
            style: TextStyle(fontSize: 12, color: T.texto2(context)),
          ),
          const SizedBox(height: 12),
          _btnHtml(
            texto: 'Iniciar Caja',
            icon: Icons.play_circle,
            color: T.green1,
            onPressed: _abrir,
            enabled: puedeOperar && !abierta && _cierre == null && !_busy,
          ),
        ],
      ),
    );
  }

  Widget _cardConsolidado(NumberFormat f, int cantidadVentas) {
    final con = _cierre?['consolidado_monto'];
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.collections,
              titulo: '2. Cierre de Ventas (Resumen Diario)'),
          Text(
            'Agrupa las ventas confirmadas del día y genera la única salida de Kardex consolidada.',
            style: TextStyle(fontSize: 12.5, color: T.texto2(context), height: 1.4),
          ),
          const SizedBox(height: 12),
          _cajaInfo([
            _filaInfo(
              'Consolidado:',
              Text(con == null ? '—' : 'Bs ${f.format(_n(con))}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: T.texto(context))),
            ),
            _filaInfo(
              'Estado:',
              con == null
                  ? const _BadgeColor(
                      texto: 'PENDIENTE',
                      bg: Color(0xFFE2E8F0),
                      fg: Color(0xFF475569))
                  : _BadgeColor(
                      texto: 'GENERADO ($cantidadVentas ventas)',
                      bg: const Color(0xFFDCFCE7),
                      fg: const Color(0xFF16A34A)),
            ),
          ]),
          const SizedBox(height: 12),
          _btnHtml(
            texto: 'Generar Resumen Diario Consolidado',
            icon: Icons.verified_user,
            color: T.purple1,
            onPressed: () =>
                snack(context, 'Función no disponible en la versión web'),
          ),
        ],
      ),
    );
  }

  Widget _cardArqueo(NumberFormat f, bool puedeOperar) {
    final okCuadre = _cierre != null && _cierre!['consolidado_monto'] != null &&
        _n(_cierre!['consolidado_monto']) == _n(_cierre!['comprobantes_monto']);
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.lock, titulo: '3. Arqueo y Cierre'),
          _cajaInfo([
            _filaInfo(
              'Fondo inicial:',
              Text(f.format(_n(_apertura?['fondo_inicial'])),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: T.texto(context))),
            ),
            _filaInfo(
              'Efectivo esperado:',
              Text(f.format(_n(_cierre?['efectivo_esperado'])),
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: T.texto(context))),
            ),
            _filaInfo(
              'Consolidado == Comprobantes:',
              _cierre == null || _cierre!['consolidado_monto'] == null
                  ? Text('—',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: T.texto(context)))
                  : Text(
                      okCuadre
                          ? 'OK (Bs ${f.format(_n(_cierre!['consolidado_monto']))})'
                          : 'DESCUADRE',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: okCuadre
                              ? const Color(0xFF16A34A)
                              : const Color(0xFFDC2626)),
                    ),
            ),
            _filaInfo(
              'Cierre:',
              _cierre == null
                  ? const _BadgeColor(
                      texto: 'SIN CERRAR',
                      bg: Color(0xFFE2E8F0),
                      fg: Color(0xFF475569))
                  : const _BadgeColor(
                      texto: 'CERRADA',
                      bg: Color(0xFFDCFCE7),
                      fg: Color(0xFF16A34A)),
            ),
            _filaInfo(
              'Validación:',
              _badgeValidacion(_cierre?['estado_validacion']),
            ),
          ]),
          const SizedBox(height: 12),
          _label('Efectivo Contado (Bs)'),
          TextField(
            controller: _contado,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 10),
          _label('Total Depósitos (Bs)'),
          TextField(
            controller: _deposito,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(hintText: '0.00'),
          ),
          const SizedBox(height: 12),
          _btnHtml(
            texto: 'Cerrar Caja (Arqueo)',
            icon: Icons.lock,
            color: T.red1,
            onPressed: _cerrar,
            enabled:
                puedeOperar && _apertura != null && _cierre == null && !_busy,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_cierre == null) {
                        snack(context, 'No hay cierre registrado hoy',
                            error: true);
                        return;
                      }
                      _validar(_cierre!);
                    },
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Validar (Tesorería)',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: T.green1,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      if (_cierre == null) {
                        snack(context, 'No hay cierre registrado hoy',
                            error: true);
                        return;
                      }
                      snack(context,
                          'Función no disponible en la versión web');
                    },
                    icon: const Icon(Icons.lock_open, size: 16),
                    label: const Text('Reabrir',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: T.red1,
                      side: const BorderSide(color: T.red1),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_historial.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text('Historial de cierres',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: T.texto(context))),
            const SizedBox(height: 8),
            TablaModerna(
              anchoTotal: 560,
              columnas: const ['Fecha', 'Esperado', 'Contado', 'Diferencia', 'Validación'],
              filas: [
                for (final c in _historial)
                  DataRow(cells: [
                    DataCell(Text('${c['fecha']}',
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(f.format(_n(c['efectivo_esperado'])),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(f.format(_n(c['efectivo_contado'])),
                        style: const TextStyle(fontSize: 12))),
                    DataCell(Text(f.format(_n(c['diferencia'])),
                        style: TextStyle(
                            fontSize: 12,
                            color: _n(c['diferencia']) == 0
                                ? T.green1
                                : T.red1))),
                    DataCell(Text('${c['estado_validacion']}',
                        style: const TextStyle(fontSize: 12))),
                  ]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardDeposito(NumberFormat f, bool puedeDeposito) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.account_balance, titulo: '4. Depósito Bancario'),
          if (puedeDeposito) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 160,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Monto (Bs)'),
                      TextField(
                        controller: _monto,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(hintText: 'Monto (Bs)'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Banco'),
                      DropdownButtonFormField<String>(
                        value: _codigoBanco(_cuenta.text),
                        hint: const Text('Seleccione banco...'),
                        items: [
                          for (final e in _bancos.entries)
                            DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value,
                                  style: const TextStyle(fontSize: 13)),
                            ),
                        ],
                        onChanged: (c) => setState(
                            () => _cuenta.text = _bancos[c] ?? _cuenta.text),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('N° Comprobante'),
                      TextField(
                        controller: _numero,
                        decoration: const InputDecoration(
                            hintText: 'N° Comprobante'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _btnHtml(
              texto: 'Registrar Depósito',
              icon: Icons.check,
              color: T.green1,
              onPressed: _agregar,
            ),
            const SizedBox(height: 12),
          ],
          TablaModerna(
            anchoTotal: 520,
            columnas: const ['N° Depósito', 'Fecha', 'Monto', 'Cuenta'],
            filas: _deps.isEmpty
                ? [
                    const DataRow(cells: [
                      DataCell(Text('Sin datos disponibles')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ]),
                  ]
                : [
                    for (final d in _deps.reversed)
                      DataRow(cells: [
                        DataCell(Text('${d['numero_deposito'] ?? '—'}')),
                        DataCell(Text('${d['fecha_deposito'] ?? '—'}')),
                        DataCell(Text('Bs ${f.format(_n(d['monto']))}')),
                        DataCell(Text('${d['numero_cuenta'] ?? '—'}')),
                      ]),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _cardFlujo() {
    Widget item(String termino, String resto) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$termino ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      color: T.texto(context))),
              TextSpan(
                  text: resto,
                  style: TextStyle(
                      fontSize: 12.5, height: 1.4, color: T.texto2(context))),
            ]),
          ),
        );
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.info_outline, titulo: 'Flujo del Cierre'),
          item('1. Apertura:',
              'se registra el fondo inicial (una vez por día).'),
          item('2. Cierre de ventas:',
              'se genera el Resumen Diario Consolidado (una única salida de Kardex por item).'),
          item('3. Arqueo:',
              'fondo inicial + ventas en efectivo vs. efectivo contado (triple cuadre: consolidado = comprobantes = efectivo).'),
          item('4. Validación:',
              'Tesorería valida el cierre; cualquier corrección exige reapertura con motivo o Nota de Ajuste.'),
          item('5. Depósito:',
              'el efectivo excedente se deposita y se registra el comprobante.'),
          if (_mensaje.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (_mensajeError ? T.red1 : T.green1).withOpacity(.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: (_mensajeError ? T.red1 : T.green1).withOpacity(.3)),
              ),
              child: Text(_mensaje,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _mensajeError ? T.red1 : T.green2)),
            ),
        ],
      ),
    );
  }

  Widget _cardNotas(bool puedeCrear, bool puedeAutorizar) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CardHeaderSection(
              icon: Icons.task_alt,
              titulo: '5. Notas de Ajuste (correcciones post-cierre)'),
          if (puedeCrear) ...[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                SizedBox(
                  width: 190,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Venta original (ID)'),
                      SizedBox(
                        width: double.infinity,
                        child: BtnSecundario(
                          _ventaSel == null
                              ? 'Buscar venta (#ID)'
                              : 'Venta: ${_ventaSel!['numero_recibo']}',
                          icon: Icons.search,
                          onPressed: _buscarVenta,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Item (ID)'),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _itemSel,
                        hint: const Text('#ID item'),
                        items: _items
                            .map((i) => DropdownMenuItem(
                                value: i,
                                child: Text(
                                    '${i['codigo']} — ${i['descripcion']}',
                                    style: const TextStyle(fontSize: 13))))
                            .toList(),
                        onChanged: (i) => setState(() => _itemSel = i),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Cantidad (+/-)'),
                      TextField(
                        controller: _cant,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(hintText: 'ej: 2 o -1'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Motivo'),
                      TextField(
                        controller: _motivo,
                        decoration: const InputDecoration(
                            hintText: 'Motivo del ajuste'),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 130,
                  child: _btnHtml(
                    texto: 'Solicitar',
                    icon: Icons.add_circle,
                    color: T.amber1,
                    onPressed: _crear,
                    enabled: !_busyNota,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          TablaModerna(
            anchoTotal: 780,
            columnas: const [
              'N°',
              'Fecha',
              'Venta',
              'Motivo',
              'Estado',
              'Acciones'
            ],
            filas: !_notasListas
                ? [
                    const DataRow(cells: [
                      DataCell(Text('Cargando...')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                      DataCell(Text('')),
                    ]),
                  ]
                : _notas.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('Sin datos disponibles')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                        ]),
                      ]
                    : [
                        for (final n in _notas.reversed)
                          DataRow(cells: [
                            DataCell(Text('${n['numero']}',
                                style: const TextStyle(fontSize: 12.5))),
                            DataCell(Text('${n['fecha']}',
                                style: const TextStyle(fontSize: 12.5))),
                            DataCell(Text('${n['venta']?['numero_recibo'] ?? '—'}',
                                style: const TextStyle(fontSize: 12.5))),
                            DataCell(Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${n['motivo']}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12.5)),
                                Text(
                                    'Solicitó: ${n['sol']?['nombre'] ?? '—'} · Autorizó: ${n['apr']?['nombre'] ?? '—'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10.5, color: T.texto2(context))),
                              ],
                            )),
                            DataCell(BadgeEstado('${n['estado']}')),
                            DataCell(n['estado'] == 'PENDIENTE' && puedeAutorizar
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.check_circle,
                                            color: Colors.green, size: 20),
                                        tooltip: 'Autorizar (doble firma)',
                                        onPressed: () =>
                                            _autorizar(n, true, ''),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.cancel,
                                            color: Colors.red, size: 20),
                                        tooltip: 'Rechazar',
                                        onPressed: () async {
                                          final m = TextEditingController();
                                          final ok = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          16)),
                                              title: const _TituloModal(
                                                gradiente: LinearGradient(
                                                    colors: [
                                                      Color(0xFFEF4444),
                                                      Color(0xFFB91C1C)
                                                    ]),
                                                icon: Icons.cancel,
                                                texto: 'Rechazar nota',
                                              ),
                                              content: SizedBox(
                                                width: 380,
                                                child: TextField(
                                                    controller: m,
                                                    decoration:
                                                        const InputDecoration(
                                                            labelText:
                                                                'Motivo')),
                                              ),
                                              actions: [
                                                BtnSecundario('Cancelar',
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, false)),
                                                BtnPeligro('Rechazar',
                                                    icon: Icons.cancel,
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                            ctx, true)),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            _autorizar(n, false, m.text);
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                : const SizedBox.shrink()),
                          ]),
                      ],
          ),
        ],
      ),
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
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
