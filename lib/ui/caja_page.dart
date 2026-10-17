import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';

class CajaPage extends StatefulWidget {
  const CajaPage({super.key});
  @override
  State<CajaPage> createState() => _CajaPageState();
}

class _CajaPageState extends State<CajaPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const TabBar(tabs: [
          Tab(text: 'Apertura / Cierre'),
          Tab(text: 'Notas de ajuste'),
          Tab(text: 'Depósitos'),
        ]),
        SizedBox(
          height: MediaQuery.sizeOf(context).height - 180,
          child: TabBarView(
            controller: _tab,
            children: const [_CajaTab(), _NotasTab(), _DepositosTab()],
          ),
        ),
      ],
    );
  }
}

class _CajaTab extends StatefulWidget {
  const _CajaTab();
  @override
  State<_CajaTab> createState() => _CajaTabState();
}

class _CajaTabState extends State<_CajaTab> {
  Map<String, dynamic>? _apertura;
  Map<String, dynamic>? _cierre;
  List<Map<String, dynamic>> _historial = [];
  final _fondo = TextEditingController(text: '150');
  final _contado = TextEditingController();
  final _deposito = TextEditingController(text: '0');
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
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
        columns: '*, caj:usuario_sistema(nombre)', orderCol: 'id');
    if (mounted) {
      setState(() {
        _apertura = aps.isEmpty ? null : aps.first;
        _cierre = ccs.isEmpty ? null : ccs.first;
        _historial = hist;
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
        snack(context, 'Caja abierta con fondo Bs ${res['fondo']}');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
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
        snack(context,
            'Cierre registrado — esperado Bs ${res['esperado']}, diferencia Bs ${res['diferencia']}');
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
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

  @override
  Widget build(BuildContext context) {
    final f = NumberFormat('#,##0.00', 'es_BO');
    final rol = sesionOf(context).perfil?.rol ?? '';
    final puedeOperar = rol == 'ADMIN' || rol == 'CAJERA';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            if (puedeOperar && _apertura == null && _cierre == null) ...[
              Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _fondo,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Fondo inicial (Bs)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _abrir,
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Abrir caja'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            if (_apertura != null && _cierre == null && puedeOperar) ...[
              Text('Caja abierta — fondo Bs ${f.format(_apertura!['fondo_inicial'])}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _contado,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Efectivo contado'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _deposito,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Total depósitos (Bs)'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _cerrar,
                    icon: const Icon(Icons.lock),
                    label: const Text('Cerrar caja'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            if (_apertura != null && _cierre != null) ...[
              Card(
                color: const Color(0xFFEEF3FA),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cierre del día — Bs ${f.format(_cierre!['efectivo_esperado'])} esperado',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Contado: Bs ${f.format(_cierre!['efectivo_contado'])} · '
                          'Diferencia: Bs ${f.format(_cierre!['diferencia'])} · '
                          'Consolidado: Bs ${f.format(_cierre!['consolidado_monto'] ?? 0)} · '
                          'Comprobantes: Bs ${f.format(_cierre!['comprobantes_monto'] ?? 0)}'),
                      Text('Validación: ${_cierre!['estado_validacion']}'),
                    ],
                  ),
                ),
              ),
              if (_cierre!['estado_validacion'] == 'PENDIENTE' &&
                  (rol == 'ADMIN' || rol == 'TESORERIA'))
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () => _validar(_cierre!),
                    icon: const Icon(Icons.verified),
                    label: const Text('Validar cierre (doble firma)'),
                  ),
                ),
              const Divider(height: 24),
            ],
            const Text('Historial de cierres',
                style: TextStyle(fontWeight: FontWeight.bold)),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Fecha')),
                  DataColumn(label: Text('Esperado')),
                  DataColumn(label: Text('Contado')),
                  DataColumn(label: Text('Diferencia')),
                  DataColumn(label: Text('Validación')),
                ],
                rows: [
                  for (final c in _historial)
                    DataRow(cells: [
                      DataCell(Text('${c['fecha']}')),
                      DataCell(Text(f.format(c['efectivo_esperado'] ?? 0))),
                      DataCell(Text(f.format(c['efectivo_contado'] ?? 0))),
                      DataCell(Text(f.format(c['diferencia'] ?? 0),
                          style: TextStyle(
                              color: (c['diferencia'] as num? ?? 0) == 0
                                  ? Colors.green
                                  : Colors.red))),
                      DataCell(Text('${c['estado_validacion']}')),
                    ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotasTab extends StatefulWidget {
  const _NotasTab();
  @override
  State<_NotasTab> createState() => _NotasTabState();
}

class _NotasTabState extends State<_NotasTab> {
  List<Map<String, dynamic>> _notas = [];
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _ventaSel;
  Map<String, dynamic>? _itemSel;
  final _cant = TextEditingController();
  final _motivo = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _items = await Api.raw('item_valorado',
        columns: 'id,codigo,descripcion,precio_unitario_vigente',
        eqField: 'activo',
        eqVal: true,
        orderCol: 'codigo',
        asc: true);
    _notas = await Api.raw('nota_ajuste',
        columns:
            '*, sol:usuario_sistema!nota_ajuste_solicitado_por_fkey(nombre), apr:usuario_sistema!nota_ajuste_autorizado_por_fkey(nombre), venta:venta(numero_recibo)',
        orderCol: 'id');
    if (mounted) setState(() {});
  }

  Future<void> _buscarVenta() async {
    final hoy = DateTime.now().toIso8601String().substring(0, 10);
    final rows = await Api.raw('venta',
        columns: 'id,numero_recibo,total,estado',
        orderCol: 'id');
    final hoyRows =
        rows.where((v) => v['fecha'] == hoy || true).take(50).toList().reversed;
    if (!mounted) return;
    final sel = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Seleccionar venta'),
        children: [
          for (final v in hoyRows.take(30))
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, v),
              child: Text(
                  '${v['numero_recibo']} — Bs ${v['total']} (${v['estado']})'),
            ),
        ],
      ),
    );
    if (sel != null) setState(() => _ventaSel = sel);
  }

  Future<void> _crear() async {
    if (_ventaSel == null || _itemSel == null || _cant.text.isEmpty) {
      snack(context, 'Seleccione venta, ítem y cantidad', error: true);
      return;
    }
    setState(() => _busy = true);
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
      if (mounted) setState(() => _busy = false);
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

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final puedeCrear = rol == 'ADMIN' || rol == 'CAJERA';
    final puedeAutorizar = rol == 'ADMIN' || rol == 'TESORERIA';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (puedeCrear) ...[
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _buscarVenta,
                    icon: const Icon(Icons.receipt_long),
                    label: Text(_ventaSel == null
                        ? 'Buscar venta'
                        : 'Venta: ${_ventaSel!['numero_recibo']}'),
                  ),
                  SizedBox(
                    width: 320,
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: _itemSel,
                      decoration: const InputDecoration(labelText: 'Ítem'),
                      items: _items
                          .map((i) => DropdownMenuItem(
                              value: i,
                              child: Text('${i['codigo']} — ${i['descripcion']}')))
                          .toList(),
                      onChanged: (i) => setState(() => _itemSel = i),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _cant,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Cant. (+ salida / − devolución)'),
                    ),
                  ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      controller: _motivo,
                      decoration: const InputDecoration(labelText: 'Motivo'),
                    ),
                  ),
                  FilledButton(
                    onPressed: _busy ? null : _crear,
                    child: const Text('Crear nota'),
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('N°')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Venta')),
                    DataColumn(label: Text('Motivo')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Solicitó')),
                    DataColumn(label: Text('Autorizó')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: [
                    for (final n in _notas.reversed)
                      DataRow(cells: [
                        DataCell(Text('${n['numero']}')),
                        DataCell(Text('${n['fecha']}')),
                        DataCell(Text('${n['venta']?['numero_recibo'] ?? '—'}')),
                        DataCell(Text('${n['motivo']}', maxLines: 1)),
                        DataCell(Text('${n['estado']}')),
                        DataCell(Text('${n['sol']?['nombre'] ?? '—'}')),
                        DataCell(Text('${n['apr']?['nombre'] ?? '—'}')),
                        DataCell(n['estado'] == 'PENDIENTE' && puedeAutorizar
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check_circle,
                                        color: Colors.green, size: 20),
                                    tooltip: 'Autorizar (doble firma)',
                                    onPressed: () => _autorizar(n, true, ''),
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
                                          title: const Text('Rechazar nota'),
                                          content: TextField(
                                              controller: m,
                                              decoration: const InputDecoration(
                                                  labelText: 'Motivo')),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Cancelar')),
                                            FilledButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Rechazar')),
                                          ],
                                        ),
                                      );
                                      if (ok == true) _autorizar(n, false, m.text);
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink()),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DepositosTab extends StatefulWidget {
  const _DepositosTab();
  @override
  State<_DepositosTab> createState() => _DepositosTabState();
}

class _DepositosTabState extends State<_DepositosTab> {
  List<Map<String, dynamic>> _deps = [];
  final _monto = TextEditingController();
  final _cuenta = TextEditingController(text: 'Banco Unión');
  final _numero = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _deps = await Api.raw('deposito_bancario', columns: '*', orderCol: 'id');
    if (mounted) setState(() {});
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
        snack(context, 'Depósito registrado');
        _monto.clear();
        _numero.clear();
        _cargar();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final puede = rol == 'ADMIN' || rol == 'TESORERIA';
    final f = NumberFormat('#,##0.00', 'es_BO');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            if (puede)
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _monto,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Monto (Bs)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 180,
                    child: TextField(
                      controller: _cuenta,
                      decoration: const InputDecoration(labelText: 'Cuenta'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 160,
                    child: TextField(
                      controller: _numero,
                      decoration:
                          const InputDecoration(labelText: 'N° depósito'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                      onPressed: _agregar, child: const Text('Registrar')),
                ],
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: [
                  for (final d in _deps.reversed)
                    ListTile(
                      leading: const Icon(Icons.account_balance_wallet),
                      title: Text('Bs ${f.format(d['monto'] ?? 0)} — ${d['numero_cuenta']}'),
                      subtitle: Text('${d['fecha_deposito']} · Dep. N° ${d['numero_deposito'] ?? '—'}'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
