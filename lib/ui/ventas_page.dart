import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/exportar.dart';
import '../widgets/snack.dart';
import 'tema.dart';

/// Réplica de `ventas.html`: título de página, tarjeta "Nueva Venta" con
/// tabla de detalles y modal de ítems, sidebar "Ventas del Día", resumen
/// estadístico, tabla "Detalle de Ventas del Día" + detalle expandido y
/// modales de Editar / Anular / Emitir Recibo.
class VentasPage extends StatefulWidget {
  const VentasPage({super.key});
  @override
  State<VentasPage> createState() => _VentasPageState();
}

class _Linea {
  Map<String, dynamic> item;
  int cantidad;
  String serieDel = '';
  String serieAl = '';
  late final TextEditingController cantCtrl;
  late final TextEditingController serieDelCtrl;
  late final TextEditingController serieAlCtrl;

  _Linea(this.item, this.cantidad) {
    cantCtrl = TextEditingController(text: '$cantidad');
    serieDelCtrl = TextEditingController(text: serieDel);
    serieAlCtrl = TextEditingController(text: serieAl);
  }

  bool get serializado => item['es_serializado'] == true;

  void dispose() {
    cantCtrl.dispose();
    serieDelCtrl.dispose();
    serieAlCtrl.dispose();
  }
}

final NumberFormat _nf = NumberFormat('#,##0.00', 'es_BO');

String _num(dynamic v) => _nf.format((v as num?) ?? 0);

String _horaCorta(dynamic hora) {
  final s = hora?.toString() ?? '';
  final i = s.indexOf('T');
  if (i >= 0 && s.length >= i + 6) return s.substring(i + 1, i + 6);
  if (s.length >= 5) return s.substring(0, 5);
  return s;
}

String _clienteDe(Map<String, dynamic> v) {
  final c = v['cliente'];
  if (c is Map && '${c['nombre'] ?? ''}'.trim().isNotEmpty) {
    final ci = c['ci'];
    return ci == null || '$ci'.trim().isEmpty
        ? '${c['nombre']}'
        : '${c['nombre']} (CI: $ci)';
  }
  return '—';
}

List<Map<String, dynamic>> _detallesDe(Map<String, dynamic> v) =>
    (v['detalles'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

String _resumenItems(Map<String, dynamic> v) {
  final d = _detallesDe(v);
  if (d.isEmpty) return 'Sin items';
  final r = [for (final x in d.take(2)) '${x['item']?['descripcion'] ?? ''}'];
  return d.length > 2 ? '${r.join(', ')} +${d.length - 2} mas' : r.join(', ');
}

// ---------------------------------------------------------------------------
// PÁGINA
// ---------------------------------------------------------------------------

class _VentasPageState extends State<VentasPage> {
  List<Map<String, dynamic>> _hoy = [];
  bool _cargando = true;
  Map<String, dynamic>? _detalleSel;
  Timer? _refresco;

  @override
  void initState() {
    super.initState();
    _cargar(mostrarCarga: true);
    // initRealtimeSales: refresco automatico cada 8s (igual que el original)
    _refresco = Timer.periodic(
        const Duration(seconds: 8), (_) => _cargar(mostrarCarga: false));
  }

  @override
  void dispose() {
    _refresco?.cancel();
    super.dispose();
  }

  Future<void> _cargar({bool mostrarCarga = false}) async {
    if (mostrarCarga && mounted) setState(() => _cargando = true);
    try {
      final hoy = DateFormat('yyyy-MM-dd').format(DateTime.now());
      List<Map<String, dynamic>> rows;
      try {
        rows = await Api.raw('venta',
            columns:
                '*,tramite(nombre,codigo),cliente(nombre,ci),cajero:usuario_sistema(nombre),detalles:venta_detalle(id,cantidad,subtotal,precio_unitario_congelado,serie_del,serie_al,item:item_valorado(codigo,descripcion))',
            eqField: 'fecha',
            eqVal: hoy,
            orderCol: 'id');
      } catch (_) {
        rows = await Api.raw('venta',
            columns: '*, tramite(nombre), cajero:usuario_sistema(nombre)',
            eqField: 'fecha',
            eqVal: hoy,
            orderCol: 'id');
      }
      _hoy = rows.reversed.toList();
      final sel = _detalleSel;
      if (sel != null) {
        final id = sel['id'];
        final act = _hoy.where((v) => v['id'] == id);
        _detalleSel = act.isEmpty ? null : act.first;
      }
    } finally {
      if (mounted && mostrarCarga) setState(() => _cargando = false);
      if (mounted && !mostrarCarga) setState(() {});
    }
  }

  // Resumen del día (cards + footer de la tabla del original)
  int get _totalActivas =>
      _hoy.where((v) => v['estado'] != 'ANULADA').length;
  int get _totalAnuladas => _hoy.where((v) => v['estado'] == 'ANULADA').length;
  num get _totalBs {
    num t = 0;
    for (final v in _hoy) {
      if (v['estado'] != 'ANULADA') t += (v['total'] as num?) ?? 0;
    }
    return t;
  }

  num get _promedioBs => _totalActivas == 0 ? 0 : _totalBs / _totalActivas;

  // -------------------------------------------------------------------------
  // Anular venta (flujo existente: sp_anular_venta)
  // -------------------------------------------------------------------------
  Future<void> _anular(Map<String, dynamic> v) async {
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const _TituloModal(
          gradiente: LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
          icon: Icons.cancel,
          texto: 'Anular Venta',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EtiquetaForm(
                  icon: Icons.notes, color: T.red1, texto: 'Motivo de anulacion'),
              const SizedBox(height: 6),
              TextField(
                controller: motivo,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'Ingrese el motivo...'),
              ),
            ],
          ),
        ),
        actions: [
          BtnSecundario('Cancelar', onPressed: () => Navigator.pop(ctx, false)),
          BtnPeligro('Anular', icon: Icons.cancel, onPressed: () {
            if (motivo.text.trim().isEmpty) {
              snack(ctx, 'Ingrese el motivo de anulacion', error: true);
              return;
            }
            Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.rpc('sp_anular_venta', {
        'p_venta_id': v['id'],
        'p_motivo': motivo.text.trim(),
      });
      if (mounted) snack(context, 'Venta anulada');
      _cargar(mostrarCarga: true);
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  // -------------------------------------------------------------------------
  // Editar venta (modal del original: nombre del cliente + forma de pago)
  // -------------------------------------------------------------------------
  Future<void> _editar(Map<String, dynamic> v) async {
    final nombre = TextEditingController();
    var forma = '${v['forma_pago'] ?? 'EFECTIVO'}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: const _TituloModal(
            gradiente: LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
            icon: Icons.edit,
            texto: 'Editar Venta',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _EtiquetaForm(
                    icon: Icons.person,
                    color: T.green1,
                    texto: 'Nombre del Cliente'),
                const SizedBox(height: 6),
                TextField(
                  controller: nombre,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                      hintText: 'NOMBRE Y APELLIDO DEL CLIENTE'),
                ),
                const SizedBox(height: 14),
                const _EtiquetaForm(
                    icon: Icons.account_balance_wallet,
                    color: T.purple1,
                    texto: 'Forma de Pago'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: forma,
                  items: const [
                    DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                    DropdownMenuItem(value: 'DEPOSITO', child: Text('Deposito')),
                  ],
                  onChanged: (nv) => setD(() => forma = nv ?? 'EFECTIVO'),
                ),
              ],
            ),
          ),
          actions: [
            BtnSecundario('Cancelar',
                icon: Icons.close, onPressed: () => Navigator.pop(ctx, false)),
            BtnPrimario('Guardar',
                icon: Icons.check, onPressed: () => Navigator.pop(ctx, true)),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final n = nombre.text.trim().toUpperCase();
      await Api.rpc('sp_actualizar_venta', {
        'p_venta_id': v['id'],
        'p_nombre_cliente': n.isEmpty ? null : n,
        'p_forma_pago': forma,
      });
      if (mounted) snack(context, 'Venta actualizada');
      _cargar(mostrarCarga: true);
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _eliminar(Map<String, dynamic> v) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar Venta'),
        content: const Text(
            'Esta seguro de eliminar esta venta? Se revertira el inventario.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          BtnPeligro('Eliminar',
              icon: Icons.delete, onPressed: () => Navigator.pop(ctx, true)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.rpc('sp_eliminar_venta', {'p_venta_id': v['id']});
      if (mounted) snack(context, 'Venta eliminada');
      _cargar(mostrarCarga: true);
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  void _verDetalleVenta(Map<String, dynamic> v) =>
      setState(() => _detalleSel = v);

  Future<void> _exportarPdf() async {
    try {
      await exportarVentasDiariasPdf(
          _hoy, DateFormat('yyyy-MM-dd').format(DateTime.now()));
    } catch (e) {
      if (mounted) snack(context, 'Error al exportar PDF: $e', error: true);
    }
  }

  Future<void> _exportarExcel() async {
    try {
      await exportarVentasDiariasXlsx(
          _hoy, DateFormat('yyyy-MM-dd').format(DateTime.now()));
    } catch (e) {
      if (mounted) snack(context, 'Error al exportar Excel: $e', error: true);
    }
  }

  Future<void> _abrirRecibo() async {
    await showDialog(
      context: context,
      builder: (_) => _DialogoRecibo(ventas: _hoy),
    );
  }

  // -------------------------------------------------------------------------
  // BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cabecera(),
        const SizedBox(height: 8),
        if (_cargando) const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth >= 900) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 8,
                    child: _NuevaVenta(onRegistrada: () => _cargar())),
                const SizedBox(width: 16),
                Expanded(flex: 4, child: _cardVentasDia()),
              ],
            );
          }
          return Column(children: [
            _NuevaVenta(onRegistrada: () => _cargar()),
            const SizedBox(height: 16),
            _cardVentasDia(),
          ]);
        }),
        const SizedBox(height: 12),
        _resumenEstadistico(),
        const SizedBox(height: 12),
        _detalleDelDia(),
        if (_detalleSel != null) ...[
          const SizedBox(height: 16),
          _detalleVentaCard(),
        ],
      ],
    );
  }

  Widget _cabecera() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart,
                      color: Color(0xFF3B82F6), size: 30),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Registro de Ventas',
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: T.texto(context))),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.description,
                      color: Color(0xFF94A3B8), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Venta de Formularios, Valorados y Tramites',
                        style: TextStyle(
                            fontSize: 16, color: T.texto2(context))),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        BtnPrimario('Emitir Recibo',
            icon: Icons.receipt_long, onPressed: _abrirRecibo),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Sidebar: Ventas del Día
  // -------------------------------------------------------------------------
  Widget _cardVentasDia() {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: CardHeaderSection(
                icon: Icons.bolt, titulo: 'Ventas del Dia'),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 620),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cifras grandes del día
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        children: [
                          Text('$_totalActivas',
                              style: const TextStyle(
                                  fontSize: 56,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF3B82F6),
                                  height: 1)),
                          const SizedBox(height: 4),
                          Text('ventas realizadas hoy',
                              style: TextStyle(
                                  fontSize: 14.4, color: T.texto2(context))),
                          const SizedBox(height: 6),
                          Text('${_num(_totalBs)} Bs',
                              style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF10B981))),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFE2E8F0)),
                    if (_hoy.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32),
                        child: Column(
                          children: [
                            Icon(Icons.inbox,
                                size: 32, color: T.texto2(context)),
                            const SizedBox(height: 8),
                            Text('Sin ventas registradas',
                                style: TextStyle(color: T.texto2(context))),
                          ],
                        ),
                      )
                    else
                      for (final v in _hoy) _cardVenta(v),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardVenta(Map<String, dynamic> v) {
    final esAnulada = v['estado'] == 'ANULADA';
    final esConsolidada =
        v['estado'] == 'CONSOLIDADA' || v['estado'] == 'CERRADA';
    final color = esAnulada
        ? const Color(0xFFDC2626)
        : esConsolidada
            ? const Color(0xFF2563EB)
            : const Color(0xFF10B981);
    final bgColor = esAnulada
        ? const Color(0xFFFEF2F2)
        : esConsolidada
            ? const Color(0xFFEFF6FF)
            : const Color(0xFFF8FAFC);
    final acciones = <Widget>[];
    if (!esAnulada && !esConsolidada) {
      acciones.add(_miniBoton(
          const Color(0xFFDBEAFE),
          const Color(0xFF2563EB),
          Icons.edit,
          'Editar',
          () => _editar(v)));
      acciones.add(_miniBoton(
          const Color(0xFFFEF3C7),
          const Color(0xFFD97706),
          Icons.cancel,
          'Anular',
          () => _anular(v)));
      acciones.add(_miniBoton(
          const Color(0xFFFEE2E2),
          const Color(0xFFDC2626),
          Icons.delete,
          'Eliminar',
          () => _eliminar(v)));
    } else if (esConsolidada) {
      acciones.add(const _BadgeHtml(
          texto: 'CONSOLIDADA',
          bg: Color(0xFFDBEAFE),
          fg: Color(0xFF2563EB),
          fontSize: 11.2));
    } else if (esAnulada) {
      acciones.add(const _BadgeHtml(
          texto: 'ANULADA',
          bg: Color(0xFFFEE2E2),
          fg: Color(0xFFDC2626),
          fontSize: 11.2));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _BadgeHtml(
                        texto: '#${v['numero_recibo'] ?? ''}',
                        bg: const Color(0xFFE2E8F0),
                        fg: const Color(0xFF475569),
                        fontSize: 11.2,
                        radio: 4),
                    Text(_horaCorta(v['hora']),
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                    _BadgeHtml(
                      texto: '${v['estado'] ?? ''}',
                      bg: esAnulada
                          ? const Color(0xFFFEE2E2)
                          : esConsolidada
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFDCFCE7),
                      fg: esAnulada
                          ? const Color(0xFFDC2626)
                          : esConsolidada
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF16A34A),
                      fontSize: 10.4,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.person,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                          (v['cliente'] is Map
                                  ? '${v['cliente']['nombre'] ?? ''}'
                                  : '${v['cliente_nombre'] ?? ''}')
                              .trim(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15.2,
                              fontWeight: FontWeight.w600,
                              color: T.texto(context))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(_resumenItems(v),
                    style:
                        const TextStyle(fontSize: 12.8, color: Color(0xFF64748B))),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${_num(v['total'])} Bs',
                  style: TextStyle(
                      fontSize: 17.6,
                      fontWeight: FontWeight.w700,
                      color: color)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: acciones,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBoton(Color bg, Color fg, IconData icon, String tip,
      VoidCallback onPressed) {
    return Tooltip(
      message: tip,
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onPressed,
        child: Container(
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 13, color: fg),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Resumen estadístico (4 cards)
  // -------------------------------------------------------------------------
  Widget _resumenEstadistico() {
    final cards = <Widget>[
      _StatVenta(
          icon: Icons.receipt,
          color: const Color(0xFF3B82F6),
          bg: const Color(0xFFDBEAFE),
          valor: '$_totalActivas',
          etiqueta: 'Ventas'),
      _StatVenta(
          icon: Icons.payments,
          color: const Color(0xFF10B981),
          bg: const Color(0xFFDCFCE7),
          valor: _num(_totalBs),
          etiqueta: 'Total Ingresado'),
      _StatVenta(
          icon: Icons.trending_up,
          color: const Color(0xFFF59E0B),
          bg: const Color(0xFFFEF3C7),
          valor: _num(_promedioBs),
          etiqueta: 'Promedio/Venta'),
      _StatVenta(
          icon: Icons.cancel,
          color: const Color(0xFFEF4444),
          bg: const Color(0xFFFEE2E2),
          valor: '$_totalAnuladas',
          etiqueta: 'Anuladas'),
    ];
    return LayoutBuilder(builder: (ctx, c) {
      if (c.maxWidth >= 1000) {
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: cards[i]),
            ],
          ],
        );
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final w in cards)
            SizedBox(
                width: c.maxWidth >= 520 ? (c.maxWidth - 12) / 2 : c.maxWidth,
                child: w),
        ],
      );
    });
  }

  // -------------------------------------------------------------------------
  // Detalle de Ventas del Día
  // -------------------------------------------------------------------------
  Widget _detalleDelDia() {
    final filas = <DataRow>[];
    for (var i = 0; i < _hoy.length; i++) {
      filas.addAll(_filasVenta(_hoy[i], i + 1));
    }
    if (_hoy.isNotEmpty) {
      var cantTotalDia = 0;
      num totalPuDia = 0;
      num totalBsDia = 0;
      var ventasContadas = 0;
      for (final v in _hoy) {
        if (v['estado'] == 'ANULADA') continue;
        final d = _detallesDe(v);
        for (final x in d) {
          cantTotalDia += ((x['cantidad'] as num?) ?? 0).toInt();
          totalPuDia += (x['precio_unitario_congelado'] as num?) ?? 0;
          totalBsDia += ((x['precio_unitario_congelado'] as num?) ?? 0) *
              ((x['cantidad'] as num?) ?? 0);
        }
        ventasContadas++;
      }
      filas.add(DataRow(
        color: WidgetStateProperty.all(const Color(0xFFE2E8F0)),
        cells: [
          for (var i = 0; i < 5; i++) const DataCell(SizedBox.shrink()),
          DataCell(Text('TOTAL DEL DIA ($ventasContadas ventas):',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
          const DataCell(SizedBox.shrink()),
          DataCell(Text('$cantTotalDia',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
          DataCell(Text(_num(totalPuDia),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
          DataCell(Text('$cantTotalDia',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF1E293B)))),
          DataCell(Text('${_num(totalBsDia)} Bs',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF1E293B)))),
        ],
      ));
    }

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: CardHeaderSection(
              icon: Icons.table_chart,
              titulo: 'Detalle de Ventas del Dia',
              acciones: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BtnSecundario('PDF',
                      icon: Icons.picture_as_pdf, onPressed: _exportarPdf),
                  const SizedBox(width: 8),
                  BtnSecundario('Excel',
                      icon: Icons.table_view, onPressed: _exportarExcel),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TablaModerna(
              anchoTotal: 1120,
              columnas: const [
                'N°',
                'HORA',
                'CLIENTE',
                'COD. TRAMITE',
                'DETALLE TRAMITE',
                'CODIGO',
                'DETALLE',
                'CANT',
                'P/U',
                'CANT',
                'TOTAL (Bs)',
              ],
              filas: filas,
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _filasVenta(Map<String, dynamic> v, int n) {
    final anulada = v['estado'] == 'ANULADA';
    final detalles = _detallesDe(v);
    final cantTotal =
        detalles.fold<num>(0, (a, d) => a + ((d['cantidad'] as num?) ?? 0));
    final totalVenta = detalles.fold<num>(
        0,
        (a, d) =>
            a +
            (((d['precio_unitario_congelado'] as num?) ?? 0) *
                ((d['cantidad'] as num?) ?? 0)));

    // Java: <tr style="opacity:0.5;"> para ventas anuladas
    Widget op(Widget w) => anulada ? Opacity(opacity: 0.5, child: w) : w;
    DataCell dc(Widget w) => DataCell(op(w));

    Widget tramiteCodigo() {
      final c = v['tramite']?['codigo'];
      if (c == null || '$c'.trim().isEmpty) {
        return Text('—', style: TextStyle(color: T.texto2(context)));
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: const Color(0xFFF3F0FF),
            borderRadius: BorderRadius.circular(4)),
        child: Text('$c',
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8B5CF6),
                fontWeight: FontWeight.w600)),
      );
    }

    Widget tramiteNombre() {
      final t = v['tramite']?['nombre'];
      if (t == null || '$t'.trim().isEmpty) {
        return Text('—', style: TextStyle(color: T.texto2(context)));
      }
      return Text('$t',
          style: const TextStyle(
              fontSize: 13.6,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B)));
    }

    if (detalles.isEmpty) {
      return [
        DataRow(onSelectChanged: (_) => _verDetalleVenta(v), cells: [
          dc(Text('#$n', style: const TextStyle(fontWeight: FontWeight.w700))),
          dc(Text(_horaCorta(v['hora']))),
          dc(Row(
            children: [
              const Icon(Icons.person, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(_clienteDe(v)),
            ],
          )),
          dc(tramiteCodigo()),
          dc(tramiteNombre()),
          dc(Text('Sin items',
              style: TextStyle(
                  fontStyle: FontStyle.italic, color: T.texto2(context)))),
          dc(const SizedBox.shrink()),
          dc(const SizedBox.shrink()),
          dc(const SizedBox.shrink()),
          dc(Text('$cantTotal', textAlign: TextAlign.center)),
          dc(Text('${_num(totalVenta)} Bs',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
      ];
    }

    final filas = <DataRow>[];
    for (var i = 0; i < detalles.length; i++) {
      final d = detalles[i];
      if (i == 0) {
        filas.add(DataRow(onSelectChanged: (_) => _verDetalleVenta(v), cells: [
          dc(Text('#$n', style: const TextStyle(fontWeight: FontWeight.w700))),
          dc(Text(_horaCorta(v['hora']))),
          dc(Row(
            children: [
              const Icon(Icons.person, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(_clienteDe(v)),
            ],
          )),
          dc(tramiteCodigo()),
          dc(tramiteNombre()),
          dc(itemCodigo(d, null)),
          dc(Text('${d['item']?['descripcion'] ?? ''}')),
          dc(Text('${d['cantidad'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          dc(Text(_num(d['precio_unitario_congelado']),
              textAlign: TextAlign.right)),
          dc(Text('$cantTotal',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          dc(Text('${_num(totalVenta)} Bs',
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 16))),
        ]));
      } else {
        filas.add(DataRow(cells: [
          for (var k = 0; k < 5; k++) dc(const SizedBox.shrink()),
          dc(itemCodigo(d, null)),
          dc(Text('${d['item']?['descripcion'] ?? ''}')),
          dc(Text('${d['cantidad'] ?? 0}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700))),
          dc(Text(_num(d['precio_unitario_congelado']),
              textAlign: TextAlign.right)),
          dc(const SizedBox.shrink()),
          dc(const SizedBox.shrink()),
        ]));
      }
    }
    return filas;
  }

  Widget itemCodigo(Map<String, dynamic> d, Color? colorTexto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(4)),
        child: Text('${d['item']?['codigo'] ?? ''}',
            style: TextStyle(
                fontSize: 12,
                color: colorTexto ?? T.texto(context),
                fontWeight: FontWeight.w600)),
      );

  // -------------------------------------------------------------------------
  // Detalle expandido de una venta
  // -------------------------------------------------------------------------
  Widget _detalleVentaCard() {
    final v = _detalleSel!;
    final detalles = _detallesDe(v);
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: CardHeaderSection(
              icon: Icons.receipt,
              titulo:
                  'Detalle de Venta # ${v['numero_recibo'] ?? ''} - ${(v['cliente'] is Map ? '${v['cliente']['nombre'] ?? ''}' : '${v['cliente_nombre'] ?? ''}').trim()}',
              acciones: IconButton(
                tooltip: 'Cerrar',
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _detalleSel = null),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: TablaModerna(
              anchoTotal: 760,
              columnas: const [
                'CODIGO',
                'ITEM',
                'SERIE DEL',
                'SERIE AL',
                'CANT',
                'P/U (Bs)',
                'SUBTOTAL (Bs)',
              ],
              filas: [
                for (final d in detalles)
                  DataRow(cells: [
                    DataCell(Text('${d['item']?['codigo'] ?? ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('${d['item']?['descripcion'] ?? ''}')),
                    DataCell(Text('${d['serie_del'] ?? '-'}')),
                    DataCell(Text('${d['serie_al'] ?? '-'}')),
                    DataCell(Text('${d['cantidad'] ?? 0}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                    DataCell(Text(_num(d['precio_unitario_congelado']),
                        textAlign: TextAlign.right)),
                    DataCell(Text(_num(d['subtotal']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// NUEVA VENTA
// ---------------------------------------------------------------------------

class _NuevaVenta extends StatefulWidget {
  final VoidCallback? onRegistrada;
  const _NuevaVenta({this.onRegistrada});
  @override
  State<_NuevaVenta> createState() => _NuevaVentaState();
}

class _NuevaVentaState extends State<_NuevaVenta> {
  List<Map<String, dynamic>> _tramites = [];
  List<Map<String, dynamic>> _items = [];
  int? _tramiteId;
  String _tramiteSel = '';
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
        columns:
            'id,codigo,descripcion,precio_unitario_vigente,activo,es_serializado',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);
    if (mounted) setState(() {});
  }

  /// cargarTramite() del original: '' limpia, 'MANUAL' no-op conserva lineas,
  /// otro id reemplaza las lineas con los detalles del tramite.
  Future<void> _cambiarTramite(String v) async {
    setState(() {
      _tramiteSel = v;
      _tramiteId = (v.isEmpty || v == 'MANUAL') ? null : int.tryParse(v);
    });
    if (v.isEmpty) {
      setState(_vaciarLineas);
      return;
    }
    if (v == 'MANUAL') return;
    try {
      final rows = await Api.raw('tramite_detalle',
          columns:
              'item_id,cantidad,item:item_valorado(id,codigo,descripcion,precio_unitario_vigente,es_serializado)',
          eqField: 'tramite_id',
          eqVal: _tramiteId);
      if (!mounted) return;
      setState(() {
        _vaciarLineas();
        for (final r in rows) {
          final it = (r['item'] as Map?)?.cast<String, dynamic>() ?? {};
          if (it.isEmpty) continue;
          _lineas.add(_Linea(it, ((r['cantidad'] as num?) ?? 1).toInt()));
        }
      });
    } catch (e) {
      if (mounted) snack(context, 'Error al cargar detalles del tramite',
          error: true);
    }
  }

  /// buscarCliente() del original (onblur del campo CI).
  Future<void> _buscarCliente() async {
    final ci = _ci.text.trim();
    if (ci.isEmpty) return;
    try {
      final rows = await Api.raw('cliente',
          columns: 'id,nombre,ci', eqField: 'ci', eqVal: ci, limit: 1);
      if (!mounted || rows.isEmpty) return;
      final nombre = '${rows.first['nombre'] ?? ''}';
      if (nombre.trim().isNotEmpty) {
        setState(() => _cliente.text = nombre);
      }
    } catch (_) {}
  }

  double get _total => _lineas.fold(
      0, (a, l) => a + l.cantidad * ((l.item['precio_unitario_vigente'] as num?) ?? 0));

  @override
  void dispose() {
    for (final l in _lineas) {
      l.dispose();
    }
    super.dispose();
  }

  void _vaciarLineas() {
    for (final l in _lineas) {
      l.dispose();
    }
    _lineas.clear();
  }

  Future<void> _registrar() async {
    if (_lineas.isEmpty) {
      snack(context, 'Debe agregar al menos un item', error: true);
      return;
    }
    final ci = _ci.text.trim();
    final nombre = _cliente.text.trim().toUpperCase();
    if (ci.isEmpty && nombre.isEmpty) {
      snack(context, 'Ingrese CI o Nombre del cliente', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.rpc('sp_registrar_venta', {
        'p_tramite_id': _tramiteId,
        'p_items': [
          for (final l in _lineas)
            {
              'item_id': l.item['id'],
              'cantidad': l.cantidad,
              if (l.serieDel.trim().isNotEmpty)
                'serie_del': int.tryParse(l.serieDel.trim()),
              if (l.serieAl.trim().isNotEmpty)
                'serie_al': int.tryParse(l.serieAl.trim()),
            }
        ],
        'p_forma_pago': _forma,
        'p_cliente_nombre': nombre.isEmpty ? null : nombre,
        'p_cliente_ci': ci.isEmpty ? null : ci,
      });
      if (mounted) {
        snack(context, 'Venta registrada exitosamente');
        setState(() {
          _vaciarLineas();
          _cliente.clear();
          _ci.clear();
          _tramiteId = null;
          _tramiteSel = '';
        });
        widget.onRegistrada?.call();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Modal "Seleccionar Items" del original
  Future<void> _abrirModalItems() async {
    final cantidades = <int, int>{};
    final busqueda = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final q = busqueda.text.trim().toLowerCase();
          final visibles = _items
              .where((i) =>
                  q.isEmpty ||
                  '${i['codigo'] ?? ''}'.toLowerCase().contains(q) ||
                  '${i['descripcion'] ?? ''}'.toLowerCase().contains(q))
              .toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const _TituloModal(
              gradiente: LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF1E3A5F)]),
              icon: Icons.add_box,
              texto: 'Seleccionar Items',
            ),
            content: SizedBox(
              width: 720,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: busqueda,
                    onChanged: (_) => setD(() {}),
                    decoration: const InputDecoration(
                        hintText: 'Buscar item por codigo o nombre...'),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 400),
                    decoration: BoxDecoration(
                      color: T.tarjeta(ctx),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: T.borde(ctx)),
                    ),
                    child: visibles.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                                child: Text('No hay items disponibles',
                                    style: TextStyle(
                                        color: T.texto2(ctx)))),
                          )
                        : ListView(
                            shrinkWrap: true,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                color: T.tableHover,
                                child: Row(
                                  children: [
                                    const SizedBox(width: 32),
                                    Expanded(
                                      flex: 2,
                                      child: Text('CODIGO',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: .5,
                                              color: T.texto2(ctx))),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text('DESCRIPCION',
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: .5,
                                              color: T.texto2(ctx))),
                                    ),
                                    SizedBox(
                                      width: 90,
                                      child: Text('P/U (Bs)',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: .5,
                                              color: T.texto2(ctx))),
                                    ),
                                    const SizedBox(width: 78),
                                  ],
                                ),
                              ),
                              for (final i in visibles)
                                _filaItemSel(ctx, i, cantidades, setD),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              BtnSecundario('Cancelar',
                  onPressed: () => Navigator.pop(ctx, false)),
              _BtnExito('Agregar Seleccionados',
                  icon: Icons.done_all,
                  onPressed: () => Navigator.pop(ctx, true)),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      cantidades.forEach((id, cant) {
        if (cant <= 0) return;
        final item = _items.firstWhere(
            (i) => (i['id'] as num).toInt() == id,
            orElse: () => <String, dynamic>{});
        if (item.isEmpty) return;
        final ex = _lineas.where((l) => l.item['id'] == id);
        if (ex.isEmpty) {
          _lineas.add(_Linea(item, cant));
        } else {
          ex.first.cantidad += cant;
          ex.first.cantCtrl.text = '${ex.first.cantidad}';
        }
      });
    });
  }

  Widget _filaItemSel(BuildContext ctx, Map<String, dynamic> i,
      Map<int, int> cantidades, void Function(void Function()) setD) {
    final id = (i['id'] as num).toInt();
    final marcado = (cantidades[id] ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: T.borde(ctx)))),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Checkbox(
              value: marcado,
              visualDensity: VisualDensity.compact,
              onChanged: (v) => setD(() {
                if (v == true) {
                  cantidades[id] = cantidades[id] == null || cantidades[id]! <= 0
                      ? 1
                      : cantidades[id]!;
                } else {
                  cantidades.remove(id);
                }
              }),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6)),
              child: Text('${i['codigo'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text('${i['descripcion'] ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 90,
            child: Text('${_num(i['precio_unitario_vigente'])} Bs',
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
          ),
          SizedBox(
            width: 78,
            child: TextField(
              keyboardType: TextInputType.number,
              enabled: marcado,
              textAlign: TextAlign.center,
              onChanged: (t) => setD(() {
                final n = int.tryParse(t) ?? 1;
                cantidades[id] = n < 1 ? 1 : n;
              }),
              decoration: const InputDecoration(
                  isDense: true, contentPadding: EdgeInsets.all(8)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: _CabeceraSeccion(
              icon: Icons.add_circle,
              color: Color(0xFF10B981),
              titulo: 'Nueva Venta',
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: LayoutBuilder(builder: (ctx, c) {
              final campos = [
                _campoTramite(c.maxWidth),
                const SizedBox(height: 12),
                c.maxWidth >= 640
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 4, child: _campoCI()),
                          const SizedBox(width: 12),
                          Expanded(flex: 5, child: _campoNombre()),
                          const SizedBox(width: 12),
                          Expanded(flex: 3, child: _campoForma()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _campoCI(),
                          const SizedBox(height: 12),
                          _campoNombre(),
                          const SizedBox(height: 12),
                          _campoForma(),
                        ],
                      ),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...campos,
                  const SizedBox(height: 16),
                  TablaModerna(
                    anchoTotal: 820,
                    columnas: const [
                      'N°',
                      'CODIGO',
                      'DETALLE',
                      'P/U',
                      'CANTIDAD',
                      'SERIE DEL',
                      'SERIE AL',
                      'SUBTOTAL',
                      'ACCION',
                    ],
                    filas: [
                      for (var k = 0; k < _lineas.length; k++)
                        DataRow(cells: [
                          DataCell(Text('${k + 1}')),
                          DataCell(Text('${_lineas[k].item['codigo'] ?? ''}')),
                          DataCell(SizedBox(
                              width: 220,
                              child: Text(
                                  '${_lineas[k].item['descripcion'] ?? ''}',
                                  overflow: TextOverflow.ellipsis))),
                          DataCell(Text(_num(
                              _lineas[k].item['precio_unitario_vigente']))),
                          DataCell(SizedBox(
                              width: 72,
                              child: TextField(
                                controller: _lineas[k].cantCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                onChanged: (t) {
                                  final n = int.tryParse(t);
                                  setState(() {
                                    _lineas[k].cantidad =
                                        (n == null || n < 1) ? 1 : n;
                                  });
                                },
                                decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.all(6)),
                              ))),
                          DataCell(_campoSerie(k, true)),
                          DataCell(_campoSerie(k, false)),
                          DataCell(Text(_num(_lineas[k].cantidad *
                              (_lineas[k].item['precio_unitario_vigente']
                                      as num)))),
                          DataCell(IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            icon: const Icon(Icons.delete,
                                size: 18, color: T.red1),
                            onPressed: () =>
                                setState(() => _lineas.removeAt(k).dispose()),
                          )),
                        ]),
                      DataRow(cells: [
                        for (var i = 0; i < 7; i++)
                          const DataCell(SizedBox.shrink()),
                        DataCell(Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.payments,
                                size: 15, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text('TOTAL:',
                                style: TextStyle(
                                    fontSize: 16.8,
                                    fontWeight: FontWeight.w700,
                                    color: T.texto(context))),
                          ],
                        )),
                        DataCell(Text('${_num(_total)} Bs',
                            style: const TextStyle(
                                fontSize: 17.6,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF10B981)))),
                      ]),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BtnSecundario('Agregar Item',
                      icon: Icons.add_box, onPressed: _abrirModalItems),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12)),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Total: ',
                                style: TextStyle(
                                    fontSize: 20, color: T.texto(context))),
                            Text(_num(_total),
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: T.accent)),
                            Text(' Bs',
                                style: TextStyle(
                                    fontSize: 20, color: T.texto(context))),
                          ],
                        ),
                        _BtnExito('Registrar Venta',
                            icon: Icons.check_circle,
                            cargando: _busy,
                            onPressed: _busy ? null : _registrar),
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _campoTramite(double ancho) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtiquetaForm(
            icon: Icons.folder_open,
            color: T.accent,
            texto: 'Tramite'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _tramiteSel,
          isExpanded: true,
          items: [
            const DropdownMenuItem(
                value: '', child: Text('-- Seleccione tramite --')),
            for (final t in _tramites)
              DropdownMenuItem(
                  value: '${t['id']}', child: Text('${t['nombre']}')),
            const DropdownMenuItem(
                value: 'MANUAL',
                child: Text('Venta Manual (sin tramite)')),
          ],
          onChanged: (v) => _cambiarTramite(v ?? ''),
        ),
      ],
    );
  }

  Widget _campoCI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtiquetaForm(
            icon: Icons.badge,
            color: T.amber1,
            texto: 'CI del Cliente',
            extra: '(opcional)',
            extraColor: T.textSecondary),
        const SizedBox(height: 6),
        Focus(
          onFocusChange: (foco) {
            if (!foco) _buscarCliente();
          },
          child: TextField(
            controller: _ci,
            decoration: const InputDecoration(hintText: 'CI del cliente'),
          ),
        ),
      ],
    );
  }

  Widget _campoNombre() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtiquetaForm(
            icon: Icons.person,
            color: T.green1,
            texto: 'Nombre del Cliente',
            requerido: true),
        const SizedBox(height: 6),
        TextField(
          controller: _cliente,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
              hintText: 'NOMBRE Y APELLIDO DEL CLIENTE'),
        ),
      ],
    );
  }

  Widget _campoForma() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _EtiquetaForm(
            icon: Icons.account_balance_wallet,
            color: T.purple1,
            texto: 'Forma de Pago'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: _forma,
          items: const [
            DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
            DropdownMenuItem(value: 'DEPOSITO', child: Text('Deposito')),
          ],
          onChanged: (v) => setState(() => _forma = v ?? 'EFECTIVO'),
        ),
      ],
    );
  }

  /// Inputs de serie solo para items serializados ('-' en caso contrario).
  Widget _campoSerie(int k, bool desde) {
    final l = _lineas[k];
    if (!l.serializado) return const Text('-');
    return SizedBox(
      width: 74,
      child: TextField(
        controller: desde ? l.serieDelCtrl : l.serieAlCtrl,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        onChanged: (t) {
          if (desde) {
            l.serieDel = t;
          } else {
            l.serieAl = t;
          }
        },
        decoration: const InputDecoration(
            isDense: true, contentPadding: EdgeInsets.all(6)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MODAL: EMITIR RECIBO DE PAGO
// ---------------------------------------------------------------------------

class _DialogoRecibo extends StatefulWidget {
  final List<Map<String, dynamic>> ventas;
  const _DialogoRecibo({required this.ventas});
  @override
  State<_DialogoRecibo> createState() => _DialogoReciboState();
}

class _DialogoReciboState extends State<_DialogoRecibo> {
  Map<String, dynamic>? _venta;
  Map<String, dynamic>? _recibo;
  bool _cargandoRecibo = false;

  List<Map<String, dynamic>> get _disponibles =>
      widget.ventas.where((v) => v['estado'] != 'ANULADA').toList();

  bool get _activo =>
      _recibo != null && _recibo!['estado'] != 'ANULADO';

  Future<void> _cargarRecibo() async {
    final v = _venta;
    if (v == null) {
      if (mounted) setState(() => _recibo = null);
      return;
    }
    setState(() => _cargandoRecibo = true);
    try {
      final rows = await Api.raw('recibo_venta',
          columns:
              'id,numero,estado,motivo_anulacion,venta_id,sucursal_id,emisor_usuario_id,fecha_emision,emisor:usuario_sistema!recibo_venta_emisor_fkey(nombre)',
          eqField: 'venta_id',
          eqVal: v['id'],
          limit: 1);
      if (mounted) setState(() => _recibo = rows.isEmpty ? null : rows.first);
    } catch (_) {
      if (mounted) setState(() => _recibo = null);
    } finally {
      if (mounted) setState(() => _cargandoRecibo = false);
    }
  }

  Future<void> _emitir() async {
    final v = _venta;
    if (v == null) {
      snack(context, 'Seleccione una venta', error: true);
      return;
    }
    try {
      final recibo = await Api.rpc('sp_emitir_recibo', {'p_venta_id': v['id']});
      if (!mounted) return;
      snack(context, 'Recibo ${recibo['numero']} emitido correctamente');
      setState(() => _recibo = recibo);
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _anularRecibo() async {
    final r = _recibo;
    if (r == null) return;
    final motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const _TituloModal(
          gradiente: LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)]),
          icon: Icons.cancel,
          texto: 'Anular recibo',
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _EtiquetaForm(
                  icon: Icons.notes,
                  color: T.red1,
                  texto: 'Motivo de anulacion del recibo'),
              const SizedBox(height: 6),
              TextField(
                controller: motivo,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'Ingrese el motivo...'),
              ),
            ],
          ),
        ),
        actions: [
          BtnSecundario('Cancelar', onPressed: () => Navigator.pop(ctx, false)),
          BtnPeligro('Anular', icon: Icons.cancel, onPressed: () {
            if (motivo.text.trim().isEmpty) {
              snack(ctx, 'Debe indicar el motivo de anulacion del recibo',
                  error: true);
              return;
            }
            Navigator.pop(ctx, true);
          }),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await Api.rpc('sp_anular_recibo', {
        'p_recibo_id': r['id'],
        'p_motivo': motivo.text.trim(),
      });
      if (mounted) snack(context, 'Recibo anulado');
      _cargarRecibo();
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _imprimir() async {
    final v = _venta;
    final r = _recibo;
    if (v == null || r == null) {
      snack(context, 'Emita el recibo antes de imprimir', error: true);
      return;
    }
    try {
      await imprimirReciboPdf(v, r);
    } catch (e) {
      if (mounted) snack(context, 'Error al imprimir: $e', error: true);
    }
  }

  Future<void> _exportarPdfRecibo() async {
    final v = _venta;
    final r = _recibo;
    if (v == null || r == null) {
      snack(context, 'Emita el recibo antes de exportar', error: true);
      return;
    }
    try {
      await exportarReciboPdf(v, r);
    } catch (e) {
      if (mounted) snack(context, 'Error al exportar: $e', error: true);
    }
  }

  String get _textoBadge {
    if (_venta == null) return 'SIN SELECCIONAR';
    if (_recibo == null) return 'NO EMITIDO';
    return _activo ? 'EMITIDO' : 'ANULADO';
  }

  Color get _colorBadgeFondo {
    if (_venta == null) return const Color(0xFFE2E8F0);
    if (_recibo == null) return const Color(0xFFFEF3C7);
    return _activo ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);
  }

  Color get _colorBadgeTexto {
    if (_venta == null) return const Color(0xFF475569);
    if (_recibo == null) return const Color(0xFFD97706);
    return _activo ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0EA5E9), Color(0xFF1E3A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.receipt_long,
                  color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Emitir Recibo de Pago',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  Text('Comprobante formal entregado al cliente',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.85),
                          fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      ),
      content: Container(
        width: 660,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  flex: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _EtiquetaForm(
                          icon: Icons.shopping_cart,
                          color: T.accent,
                          texto: 'Venta del dia'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _venta?['id']?.toString(),
                        isExpanded: true,
                        items: _disponibles.isEmpty
                            ? const [
                                DropdownMenuItem(
                                    value: '',
                                    child: Text('Sin ventas activas hoy'))
                              ]
                            : [
                                for (final v in _disponibles)
                                  DropdownMenuItem(
                                    value: '${v['id']}',
                                    child: Text(
                                        '#${v['numero_recibo'] ?? v['id']} — ${_clienteDe(v)} — Bs ${_num(v['total'])}',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                              ],
                        onChanged: (id) {
                          final v = _disponibles.where(
                              (x) => '${x['id']}' == id);
                          setState(() =>
                              _venta = v.isEmpty ? null : v.first);
                          _cargarRecibo();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 4,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _BadgeHtml(
                      texto: _textoBadge,
                      bg: _colorBadgeFondo,
                      fg: _colorBadgeTexto,
                      fontSize: 12.8,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_cargandoRecibo) const LinearProgressIndicator(minHeight: 2),
            Center(
              child: _venta == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.receipt,
                              size: 40, color: T.texto2(context)),
                          const SizedBox(height: 8),
                          Text('Seleccione una venta para ver el recibo',
                              style: TextStyle(color: T.texto2(context))),
                        ],
                      ),
                    )
                  : ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 420),
                      child: SingleChildScrollView(
                        child: _ReciboPreview(venta: _venta!, recibo: _recibo),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actions: [
        BtnSecundario('Cerrar',
            icon: Icons.close, onPressed: () => Navigator.pop(context)),
        BtnSecundario('Anular',
            icon: Icons.cancel,
            onPressed:
                _activo ? _anularRecibo : null),
        BtnSecundario('Imprimir',
            icon: Icons.print, onPressed: _activo ? _imprimir : null),
        _BtnExito('Exportar PDF',
            icon: Icons.picture_as_pdf,
            onPressed: _activo ? _exportarPdfRecibo : null),
        BtnPrimario('Emitir Recibo',
            icon: Icons.send,
            onPressed: (_venta != null && _recibo == null) ? _emitir : null),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// PREVIEW DEL RECIBO
// ---------------------------------------------------------------------------

class _ReciboPreview extends StatelessWidget {
  final Map<String, dynamic> venta;
  final Map<String, dynamic>? recibo;
  const _ReciboPreview({required this.venta, this.recibo});

  Widget _fila(String campo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 150,
              child: Text(campo,
                  style: const TextStyle(fontSize: 13.3, color: Color(0xFF64748B)))),
          Expanded(
            child: Text(valor.isEmpty ? '—' : valor,
                style: const TextStyle(
                    fontSize: 13.3,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emitido = recibo != null;
    final anulado = emitido && recibo!['estado'] == 'ANULADO';
    final numero = emitido ? '${recibo!['numero']}' : '—';
    final detalles = _detallesDe(venta);
    final forma = '${venta['forma_pago'] ?? 'EFECTIVO'}';
    final formaTexto = forma.isEmpty
        ? 'Efectivo'
        : forma.substring(0, 1) + forma.substring(1).toLowerCase();
    final tramite = venta['tramite'];
    final textoTramite = (tramite is Map && tramite['nombre'] != null)
        ? '${(tramite['codigo'] != null && '${tramite['codigo']}'.trim().isNotEmpty ? '${tramite['codigo']} — ' : '')}${tramite['nombre']}'
        : 'Venta manual';

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 560),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E3A5F),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(
                children: [
                  const Text(
                      'DIRECCION DEPARTAMENTAL DE EDUCACION DE PANDO',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15.2,
                          letterSpacing: .5)),
                  const SizedBox(height: 2),
                  Text('Unidad de Asuntos Administrativos',
                      style: TextStyle(
                          color: Colors.white.withOpacity(.85),
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  const Text('RECIBO DE PAGO',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.8,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Text('N° $numero',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.8,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: _BadgeHtml(
                texto: emitido
                    ? (anulado ? 'ANULADO' : 'EMITIDO')
                    : 'PENDIENTE DE EMISION',
                bg: emitido
                    ? (anulado
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFDCFCE7))
                    : const Color(0xFFFEF3C7),
                fg: emitido
                    ? (anulado
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF16A34A))
                    : const Color(0xFFD97706),
                fontSize: 11.2,
              ),
            ),
            if (anulado &&
                '${recibo!['motivo_anulacion'] ?? ''}'.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('ANULADO: ${recibo!['motivo_anulacion']}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 14),
            _fila('Venta N°', '#${venta['numero_recibo'] ?? venta['id']}'),
            _fila('Fecha', _horaCorta(venta['hora'])),
            _fila('Cliente', _clienteDe(venta)),
            _fila('Tramite', textoTramite),
            _fila('Forma de pago', formaTexto),
            const SizedBox(height: 12),
            // Tabla de items
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: const BoxDecoration(
                        color: Color(0xFF1E3A5F),
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(8))),
                    child: const Row(
                      children: [
                        SizedBox(
                            width: 64,
                            child: Text('CODIGO',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                        Expanded(
                            child: Text('DETALLE',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 92,
                            child: Text('SERIE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 36,
                            child: Text('CANT',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 56,
                            child: Text('P/U',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                        SizedBox(
                            width: 70,
                            child: Text('SUBTOTAL',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                  for (var i = 0; i < detalles.length; i++)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      color:
                          i.isEven ? const Color(0xFFF8FAFC) : Colors.white,
                      child: _filaItemRecibo(detalles[i]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                  color: const Color(0xFF10B981),
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                  Text('Bs ${_num(venta['total'])}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 20.8)),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Color(0xFF64748B)))),
                    child: const Text('Responsable de Ventanilla',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.only(top: 5),
                    decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: Color(0xFF64748B)))),
                    child: const Text('Entregado al Cliente',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF64748B))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
                'Documento de control interno. No es un comprobante fiscal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10.4,
                    color: T.texto2(context),
                    fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }

  Widget _filaItemRecibo(Map<String, dynamic> d) {
    final serie = (d['serie_del'] != null && d['serie_al'] != null)
        ? '${d['serie_del']} al ${d['serie_al']}'
        : '—';
    return Row(
      children: [
        SizedBox(
            width: 64,
            child: Text('${d['item']?['codigo'] ?? ''}',
                style: const TextStyle(
                    fontSize: 11.2, fontWeight: FontWeight.w600))),
        Expanded(
            child: Text('${d['item']?['descripcion'] ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.2))),
        SizedBox(
            width: 92,
            child: Text(serie,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.2))),
        SizedBox(
            width: 36,
            child: Text('${d['cantidad'] ?? 0}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.2))),
        SizedBox(
            width: 56,
            child: Text(_num(d['precio_unitario_congelado']),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 11.2))),
        SizedBox(
            width: 70,
            child: Text(_num(d['subtotal']),
                textAlign: TextAlign.right,
                style:
                    const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGETS DE APOYO
// ---------------------------------------------------------------------------

/// Cabecera de sección (.card-header-section) con color de ícono configurable.
class _CabeceraSeccion extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  const _CabeceraSeccion(
      {required this.icon, required this.color, required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.borde(context)))),
      child: Row(
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
    );
  }
}

/// Etiqueta de formulario (.form-label) con ícono de color.
class _EtiquetaForm extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String texto;
  final String? extra;
  final Color? extraColor;
  final bool requerido;
  const _EtiquetaForm(
      {required this.icon,
      required this.color,
      required this.texto,
      this.extra,
      this.extraColor,
      this.requerido = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(texto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: T.texto(context))),
        if (extra != null) ...[
          const SizedBox(width: 4),
          Text(extra!,
              style: TextStyle(
                  fontSize: 13, color: extraColor ?? T.texto2(context))),
        ],
        if (requerido) ...[
          const SizedBox(width: 4),
          Text('*',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: T.red1)),
        ],
      ],
    );
  }
}

/// .btn-success-custom (#22c55e).
class _BtnExito extends StatelessWidget {
  final String texto;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool cargando;
  const _BtnExito(this.texto,
      {this.icon, this.onPressed, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: cargando ? null : onPressed,
      icon: cargando
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Icon(icon ?? Icons.check, size: 18),
      label: Text(texto,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF22C55E),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

/// Cabecera con degradado de los modales del original.
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

/// Badge con los colores en línea del original.
class _BadgeHtml extends StatelessWidget {
  final String texto;
  final Color bg;
  final Color fg;
  final double fontSize;
  final double radio;
  final EdgeInsets padding;
  const _BadgeHtml(
      {required this.texto,
      required this.bg,
      required this.fg,
      this.fontSize = 11.2,
      this.radio = 20,
      this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radio)),
      child: Text(texto,
          style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: fg,
              letterSpacing: .2)),
    );
  }
}

/// Stat card del resumen (borde izquierdo de color + caja de ícono).
class _StatVenta extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String valor;
  final String etiqueta;
  const _StatVenta(
      {required this.icon,
      required this.color,
      required this.bg,
      required this.valor,
      required this.etiqueta});

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              border: Border(left: BorderSide(color: color, width: 4))),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(valor,
                        style: TextStyle(
                            fontSize: 25.6,
                            fontWeight: FontWeight.w700,
                            color: color,
                            height: 1)),
                    const SizedBox(height: 2),
                    Text(etiqueta,
                        style: TextStyle(
                            fontSize: 12.8, color: T.texto2(context))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
