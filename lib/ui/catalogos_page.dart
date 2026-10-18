import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import '../services/exportar.dart';
import '../services/sesion.dart';
import '../widgets/snack.dart';
import 'tema.dart';

const _azul = Color(0xFF3B82F6);
const _azulOscuro = Color(0xFF1E3A5F);
const _verde = Color(0xFF10B981);
const _verdeBtn = Color(0xFF22C55E);
const _morado = Color(0xFF8B5CF6);
const _moradoOscuro = Color(0xFF6D28D9);
const _ambar = Color(0xFFF59E0B);
const _ambarOscuro = Color(0xFFD97706);
const _gris = Color(0xFF94A3B8);
const _rojo = Color(0xFFDC2626);
const _rojoBg = Color(0xFFFEE2E2);
const _verdeBg = Color(0xFFDCFCE7);
const _verdeTxt = Color(0xFF16A34A);
const _verdeLinkBg = Color(0xFFD1FAE5);
const _verdeLink = Color(0xFF059669);
const _azulBg = Color(0xFFDBEAFE);
const _azulTxt = Color(0xFF2563EB);
const _ambarBg = Color(0xFFFEF3C7);
const _ambarTxt = Color(0xFFD97706);
const _grisBg = Color(0xFFF1F5F9);
const _grisTxt = Color(0xFF64748B);

int? _id(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse('${v ?? ''}');
}

class CatalogosPage extends StatefulWidget {
  const CatalogosPage({super.key});
  @override
  State<CatalogosPage> createState() => _CatalogosPageState();
}

class _CatalogosPageState extends State<CatalogosPage> {
  final NumberFormat _f = NumberFormat('#,##0.00', 'es_BO');

  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _tramites = [];
  List<Map<String, dynamic>> _detalles = [];
  int? _tramiteDetallesId;
  String _tramiteDetallesNombre = '';

  bool _cargandoItems = true;
  bool _cargandoTramites = true;
  bool _cargandoDetalles = false;
  String? _errItems;
  String? _errTramites;
  String? _errDetalles;

  /// Java: `sesionService.exigirPermiso("EDITAR_CATALOGOS")` en todos los
  /// endpoints de items/tramites. En BD solo el rol ADMIN lo posee.
  bool get _puedeEditar =>
      sesionOf(context).perfil?.rol == 'ADMIN';

  /// Mensaje exacto de `SesionService.exigirPermiso`.
  static const _errPermiso =
      'No tiene permiso para esta accion. Requiere: EDITAR_CATALOGOS';

  @override
  void initState() {
    super.initState();
    _cargarItems();
    _cargarTramites();
  }

  Future<void> _cargarItems() async {
    try {
      _items = await Api.raw('item_valorado',
          columns: '*', orderCol: 'codigo', asc: true);
      _errItems = null;
    } catch (e) {
      _errItems = Api.err(e);
    }
    if (mounted) setState(() => _cargandoItems = false);
  }

  Future<void> _cargarTramites() async {
    try {
      _tramites = await Api.raw('tramite',
          columns: '*', orderCol: 'nombre', asc: true);
      _errTramites = null;
    } catch (e) {
      _errTramites = Api.err(e);
    }
    if (mounted) setState(() => _cargandoTramites = false);
  }

  Future<void> _cargarDetalles() async {
    final tid = _tramiteDetallesId;
    if (tid == null) return;
    setState(() {
      _cargandoDetalles = true;
      _errDetalles = null;
    });
    try {
      _detalles = await Api.raw('tramite_detalle',
          columns: '*', eqField: 'tramite_id', eqVal: tid, orderCol: 'id');
    } catch (e) {
      _detalles = [];
      _errDetalles = Api.err(e);
    }
    if (mounted) setState(() => _cargandoDetalles = false);
  }

  Future<void> _verDetalles(Map<String, dynamic> t) async {
    _tramiteDetallesId = _id(t['id']);
    _tramiteDetallesNombre = '${t['nombre']}';
    _detalles = [];
    _errDetalles = null;
    _cargandoDetalles = true;
    if (mounted) setState(() {});
    await _cargarDetalles();
  }

  Map<String, dynamic>? _itemPorId(dynamic itemId) {
    final k = '$itemId';
    for (final i in _items) {
      if ('${i['id']}' == k) return i;
    }
    return null;
  }

  // ============================== ITEMS ==============================

  Future<void> _editarItem([Map<String, dynamic>? item]) async {
    final puede = _puedeEditar;
    final codigo = TextEditingController(text: item?['codigo']?.toString() ?? '');
    final desc =
        TextEditingController(text: item?['descripcion']?.toString() ?? '');
    final precio = TextEditingController(
        text: item != null ? '${item['precio_unitario_vigente']}' : '');
    final um = TextEditingController(
        text: item?['unidad_medida']?.toString() ?? 'UNIDAD');
    bool serial = (item?['es_serializado'] ?? false) as bool;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: _CabeceraModal(
              titulo: item == null ? 'Nuevo Item' : 'Editar Item',
              icono: Icons.inventory_2,
              c1: _azul,
              c2: _azulOscuro),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Etiqueta('Codigo', Icons.qr_code_scanner, _azul),
                const SizedBox(height: 6),
                TextField(
                    controller: codigo,
                    decoration: const InputDecoration(hintText: 'Ej: F-001')),
                const SizedBox(height: 14),
                _Etiqueta('Descripcion', Icons.notes, _verde),
                const SizedBox(height: 6),
                TextField(
                    controller: desc,
                    decoration:
                        const InputDecoration(hintText: 'Nombre del item')),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Etiqueta('Precio Unitario', Icons.payments, _ambar),
                        const SizedBox(height: 6),
                        TextField(
                          controller: precio,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(hintText: '0.00'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Etiqueta('Unidad', Icons.straighten, _morado),
                        const SizedBox(height: 6),
                        TextField(controller: um),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setD(() => serial = !serial),
                  child: Row(children: [
                    Checkbox(
                      value: serial,
                      activeColor: _azul,
                      onChanged: (v) => setD(() => serial = v ?? false),
                    ),
                    const Icon(Icons.qr_code, color: _rojo, size: 16),
                    const SizedBox(width: 6),
                    const Text('Es Serializado',
                        style: TextStyle(fontSize: 13.5)),
                  ]),
                ),
              ],
            ),
          ),
          actions: [
            BtnSecundario('Cancelar',
                onPressed: () => Navigator.pop(ctx, false)),
            BtnPrimario('Guardar', icon: Icons.check, onPressed: () {
              if (!puede) {
                snack(ctx, _errPermiso, error: true);
                return;
              }
              final err = _validarCodigoItem(codigo.text.trim(),
                  excepto: item == null ? null : _id(item['id']));
              if (err != null) {
                snack(ctx, err, error: true);
                return;
              }
              Navigator.pop(ctx, true);
            }),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      final data = {
        'codigo': codigo.text.trim(),
        'descripcion': desc.text.trim(),
        'precio_unitario_vigente': double.tryParse(precio.text.trim()) ?? 0,
        'unidad_medida': um.text.trim(),
        'es_serializado': serial,
        // Java guardarItem() siempre envia activo: true
        'activo': true,
      };
      if (item == null) {
        await Api.c.from('item_valorado').insert(data);
        if (mounted) snack(context, 'Item creado');
      } else {
        await Api.c.from('item_valorado').update(data).eq('id', item['id']);
        if (mounted) snack(context, 'Item actualizado');
      }
      if (mounted) _cargarItems();
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  /// ItemController: valida duplicado de item (excluyendo el propio) y luego
  /// contra tramites, solo si el codigo no esta vacio.
  String? _validarCodigoItem(String cod, {int? excepto}) {
    if (cod.isEmpty) return null;
    for (final i in _items) {
      if (_id(i['id']) != excepto && '${i['codigo']}' == cod) {
        return "El codigo '$cod' ya esta registrado en otro item";
      }
    }
    for (final t in _tramites) {
      if ('${t['codigo'] ?? ''}' == cod) {
        return "El codigo '$cod' ya esta registrado en un tramite";
      }
    }
    return null;
  }

  /// TramiteController: en crear valida contra tramites y contra items;
  /// en editar solo contra otros tramites.
  String? _validarCodigoTramite(String cod,
      {int? excepto, bool checarItem = true}) {
    if (cod.isEmpty) return null;
    for (final t in _tramites) {
      if (_id(t['id']) != excepto && '${t['codigo'] ?? ''}' == cod) {
        return "El codigo '$cod' ya esta registrado en otro tramite";
      }
    }
    if (checarItem) {
      for (final i in _items) {
        if ('${i['codigo']}' == cod) {
          return "El codigo '$cod' ya esta registrado en un item valorado";
        }
      }
    }
    return null;
  }

  Future<void> _toggleItem(Map<String, dynamic> i) async {
    final activo = i['activo'] == true;
    if (activo) {
      final ok = await _confirmar(context,
          titulo: 'Desactivar',
          mensaje: 'Este item quedara como inactivo. Continuar?');
      if (!ok || !mounted) return;
      if (!_puedeEditar) {
        snack(context, _errPermiso, error: true);
        return;
      }
      try {
        await Api.c.from('item_valorado').update({'activo': false}).eq(
            'id', i['id']);
        if (mounted) {
          snack(context, 'Item desactivado');
          _cargarItems();
        }
      } catch (e) {
        if (mounted) snack(context, Api.err(e), error: true);
      }
      return;
    }
    if (!_puedeEditar) {
      snack(context, _errPermiso, error: true);
      return;
    }
    try {
      await Api.c
          .from('item_valorado')
          .update({'activo': true}).eq('id', i['id']);
      if (mounted) {
        snack(context, 'Item activado');
        _cargarItems();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _eliminarItem(Map<String, dynamic> i) async {
    final ok = await _confirmar(context,
        titulo: 'Eliminar',
        mensaje: 'Esta accion eliminara el item permanentemente. Esta seguro?');
    if (!ok || !mounted) return;
    if (!_puedeEditar) {
      snack(context, _errPermiso, error: true);
      return;
    }
    try {
      // ItemValoradoService.eliminarReal: borra venta_detalle,
      // movimiento_inventario, tramite_detalle, toma_inventario_fisico y
      // pedido_reposicion antes del item (RLS bloquea DELETE directo).
      await Api.rpc('sp_eliminar_item_real', {'p_item_id': _id(i['id'])});
      if (mounted) {
        snack(context, 'Item eliminado');
        _cargarItems();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  // ============================= TRAMITES ============================

  Future<void> _editarTramite([Map<String, dynamic>? t]) async {
    final puede = _puedeEditar;
    final codigo = TextEditingController(text: t?['codigo']?.toString() ?? '');
    final nombre = TextEditingController(text: t?['nombre']?.toString() ?? '');
    final tarifa =
        TextEditingController(text: t != null ? '${t['tarifa']}' : '');

    final sel = <String, bool>{};
    final cant = <String, int>{};
    if (t != null) {
      try {
        final dets = await Api.raw('tramite_detalle',
            columns: '*', eqField: 'tramite_id', eqVal: t['id']);
        for (final d in dets) {
          final k = '${d['item_id']}';
          sel[k] = true;
          cant[k] = (d['cantidad'] as num?)?.toInt() ?? 1;
        }
      } catch (_) {}
    }
    if (!mounted) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final activos =
              _items.where((i) => i['activo'] == true).toList(growable: false);
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            titlePadding: EdgeInsets.zero,
            title: _CabeceraModal(
                titulo: t == null ? 'Nuevo Tramite' : 'Editar Tramite',
                icono: Icons.book,
                c1: _morado,
                c2: _moradoOscuro),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Etiqueta('Codigo', Icons.sell, _morado),
                  const SizedBox(height: 6),
                  TextField(
                      controller: codigo,
                      decoration: const InputDecoration(hintText: 'Ej: T-001')),
                  const SizedBox(height: 14),
                  _Etiqueta('Nombre', Icons.notes, _verde),
                  const SizedBox(height: 6),
                  TextField(
                      controller: nombre,
                      decoration: const InputDecoration(
                          hintText: 'Nombre del tramite')),
                  const SizedBox(height: 14),
                  _Etiqueta('Tarifa (Bs)', Icons.payments, _ambar),
                  const SizedBox(height: 6),
                  TextField(
                    controller: tarifa,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(hintText: '0.00'),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _Etiqueta('Items / Formularios Asociados',
                      Icons.inventory_2, _azul,
                      negrita: true),
                  const SizedBox(height: 4),
                  Text(
                    'Seleccione los items que forman parte de este tramite (cantidad default: 1)',
                    style: TextStyle(fontSize: 12.5, color: T.texto2(ctx)),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 200,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: T.esOscuro(ctx)
                          ? T.darkHover
                          : const Color(0xFFF8FAFC),
                      border: Border.all(color: T.borde(ctx)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: _cargandoItems
                        ? Center(
                            child: Text('Cargando items...',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    color: T.texto2(ctx))),
                          )
                        : activos.isEmpty
                            ? Center(
                                child: Text(
                                    'No hay items activos en el catalogo',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        color: T.texto2(ctx))),
                              )
                            : ListView(
                                children: [
                                  for (final i in activos)
                                    _filaItemCheck(i, sel, cant, setD, ctx),
                                ],
                              ),
                  ),
                ],
              ),
            ),
            actions: [
              BtnSecundario('Cancelar',
                  onPressed: () => Navigator.pop(ctx, false)),
              BtnPrimario('Guardar', icon: Icons.check, onPressed: () {
                if (!puede) {
                  snack(ctx, _errPermiso, error: true);
                  return;
                }
                final err = _validarCodigoTramite(codigo.text.trim(),
                    excepto: t == null ? null : _id(t['id']),
                    checarItem: t == null);
                if (err != null) {
                  snack(ctx, err, error: true);
                  return;
                }
                Navigator.pop(ctx, true);
              }),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    try {
      // Java guardarTramite() envia descripcion: '' y activo: true siempre.
      final data = {
        'codigo': codigo.text.trim(),
        'nombre': nombre.text.trim(),
        'descripcion': '',
        'tarifa': double.tryParse(tarifa.text) ?? 0,
        'activo': true,
      };
      if (t == null) {
        final nuevo =
            await Api.c.from('tramite').insert(data).select('id').single();
        final tramiteId = nuevo['id'];
        var n = 0;
        for (final i in _items) {
          if (i['activo'] != true) continue;
          final k = '${i['id']}';
          if (sel[k] != true) continue;
          await Api.c.from('tramite_detalle').insert({
            'tramite_id': tramiteId,
            'item_id': i['id'],
            'cantidad': cant[k] ?? 1,
          });
          n++;
        }
        if (mounted) {
          snack(context, 'Tramite creado con $n item(s) asociado(s)');
          _cargarTramites();
        }
      } else {
        // Java editarTramite(): PUT del tramite; los checkboxes de items NO
        // se guardan (el PUT ignora los detalles) - paridad exacta.
        await Api.c.from('tramite').update(data).eq('id', t['id']);
        if (mounted) {
          snack(context, 'Tramite actualizado');
          _cargarTramites();
        }
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Widget _filaItemCheck(Map<String, dynamic> i, Map<String, bool> sel,
      Map<String, int> cant,
      void Function(void Function()) setD,
      BuildContext ctx) {
    final k = '${i['id']}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 26,
          height: 26,
          child: Checkbox(
            value: sel[k] ?? false,
            activeColor: _morado,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (v) => setD(() => sel[k] = v ?? false),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(children: [
              TextSpan(
                  text: '${i['codigo']} ',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: T.texto(ctx))),
              TextSpan(
                  text: '${i['descripcion']}',
                  style: TextStyle(
                      fontSize: 13, color: T.texto2(ctx))),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('Cant:',
            style: TextStyle(fontSize: 11, color: _gris)),
        const SizedBox(width: 6),
        SizedBox(
          width: 62,
          child: TextFormField(
            initialValue: '${cant[k] ?? 1}',
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: T.texto(ctx)),
            decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 8)),
            onChanged: (v) => cant[k] = int.tryParse(v) ?? 1,
          ),
        ),
      ]),
    );
  }

  Future<void> _toggleTramite(Map<String, dynamic> t) async {
    final activo = t['activo'] == true;
    if (activo) {
      final ok = await _confirmar(context,
          titulo: 'Desactivar',
          mensaje: 'Este tramite quedara como inactivo. Continuar?');
      if (!ok || !mounted) return;
      if (!_puedeEditar) {
        snack(context, _errPermiso, error: true);
        return;
      }
      try {
        await Api.c.from('tramite').update({'activo': false}).eq('id', t['id']);
        if (mounted) {
          snack(context, 'Tramite desactivado');
          _cargarTramites();
        }
      } catch (e) {
        if (mounted) snack(context, Api.err(e), error: true);
      }
      return;
    }
    if (!_puedeEditar) {
      snack(context, _errPermiso, error: true);
      return;
    }
    try {
      await Api.c.from('tramite').update({'activo': true}).eq('id', t['id']);
      if (mounted) {
        snack(context, 'Tramite activado');
        _cargarTramites();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _eliminarTramite(Map<String, dynamic> t) async {
    final ok = await _confirmar(context,
        titulo: 'Eliminar',
        mensaje:
            'Esta accion eliminara el tramite y sus items vinculados. Esta seguro?');
    if (!ok || !mounted) return;
    if (!_puedeEditar) {
      snack(context, _errPermiso, error: true);
      return;
    }
    try {
      await Api.c.from('tramite_detalle').delete().eq('tramite_id', t['id']);
      await Api.c.from('tramite').delete().eq('id', t['id']);
      if (_tramiteDetallesId == _id(t['id'])) {
        _tramiteDetallesId = null;
        _tramiteDetallesNombre = '';
        _detalles = [];
        _errDetalles = null;
      }
      if (mounted) {
        snack(context, 'Tramite eliminado');
        _cargarTramites();
        setState(() {});
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  // =========================== VINCULAR ITEM =========================

  Future<void> _abrirVincular() async {
    if (_tramiteDetallesId == null) return;
    final puede = _puedeEditar;
    final activos =
        _items.where((i) => i['activo'] == true).toList(growable: false);
    int? itemId = activos.isEmpty ? null : _id(activos.first['id']);
    final cantidad = TextEditingController(text: '1');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: _CabeceraModal(
            titulo: 'Vincular Item',
            icono: Icons.link,
            c1: _ambar,
            c2: _ambarOscuro),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Etiqueta('Item', Icons.inventory_2, _verde),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: itemId,
                isExpanded: true,
                items: [
                  for (final i in activos)
                    DropdownMenuItem<int>(
                      value: _id(i['id']),
                      child: Text(
                        '${i['codigo']} - ${i['descripcion']} '
                        '(${_f.format(i['precio_unitario_vigente'] ?? 0)} Bs)',
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => itemId = v,
                decoration: const InputDecoration(isDense: true),
              ),
              const SizedBox(height: 14),
              _Etiqueta('Cantidad', Icons.numbers, _azul),
              const SizedBox(height: 6),
              TextField(
                controller: cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true),
              ),
            ],
          ),
        ),
        actions: [
          BtnSecundario('Cancelar',
              onPressed: () => Navigator.pop(ctx, false)),
          _BtnBarra(
              texto: 'Vincular',
              icon: Icons.link,
              color: _verdeBtn,
              onPressed: () {
                final c = int.tryParse(cantidad.text) ?? 0;
                if (itemId == null || c < 1) {
                  snack(ctx, 'Seleccione item y cantidad');
                  return;
                }
                if (!puede) {
                  snack(ctx, _errPermiso, error: true);
                  return;
                }
                Navigator.pop(ctx, true);
              }),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final c = int.tryParse(cantidad.text) ?? 0;
    try {
      await Api.c.from('tramite_detalle').insert({
        'tramite_id': _tramiteDetallesId,
        'item_id': itemId,
        'cantidad': c,
      });
      if (mounted) {
        snack(context, 'Item vinculado al tramite');
        _cargarDetalles();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  Future<void> _desvincular(Map<String, dynamic> d) async {
    final ok = await _confirmar(context,
        titulo: 'Desvincular', mensaje: 'Quitar este item del tramite?');
    if (!ok || !mounted) return;
    if (!_puedeEditar) {
      snack(context, _errPermiso, error: true);
      return;
    }
    try {
      await Api.c.from('tramite_detalle').delete().eq('id', d['id']);
      if (mounted) {
        snack(context, 'Item desvinculado');
        _cargarDetalles();
      }
    } catch (e) {
      if (mounted) snack(context, Api.err(e), error: true);
    }
  }

  // ============================== UI =================================

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _cabecera(context),
        LayoutBuilder(builder: (ctx, cc) {
          final ancho = cc.maxWidth >= 1024
              ? (cc.maxWidth - 16) / 2
              : cc.maxWidth;
          return Wrap(spacing: 16, runSpacing: 4, children: [
            SizedBox(width: ancho, child: _tarjetaItems(context)),
            SizedBox(width: ancho, child: _tarjetaTramites(context)),
          ]);
        }),
        if (_tramiteDetallesId != null) _tarjetaDetalles(context),
      ],
    );
  }

  /// `exportarItemsPDF()` / `exportarItemsExcel()` de Java: abren
  /// `/reportes/resumen-kardex/pdf|excel?sucursalId=1&fechaHasta=<hoy>`.
  Future<void> _exportarItems(bool pdf) async {
    final hoy = DateTime.now();
    final iso =
        '${hoy.year.toString().padLeft(4, '0')}-${hoy.month.toString().padLeft(2, '0')}-${hoy.day.toString().padLeft(2, '0')}';
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

  Widget _cabecera(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.book, color: _azul, size: 30),
                const SizedBox(width: 10),
                Text('Catalogos',
                    style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: T.texto(context))),
              ]),
              const SizedBox(height: 2),
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.inventory_2, color: _gris, size: 18),
                const SizedBox(width: 8),
                Text('Gestion de Items y Tramites',
                    style: TextStyle(
                        fontSize: 16, color: T.texto2(context))),
              ]),
            ],
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _BtnBarra(
                texto: 'PDF Items',
                icon: Icons.picture_as_pdf,
                color: _gris,
                outline: true,
                onPressed: () => _exportarItems(true)),
            _BtnBarra(
                texto: 'Excel Items',
                icon: Icons.table_view,
                color: _gris,
                outline: true,
                onPressed: () => _exportarItems(false)),
          ]),
        ],
      ),
    );
  }

  Widget _tarjetaItems(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _CabeceraSeccion(
              icono: Icons.inventory_2,
              color: _verde,
              titulo: 'Items / Formularios',
              acciones: BtnPrimario('Nuevo Item',
                  icon: Icons.add, onPressed: () => _editarItem()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _contenidoItems(context),
          ),
        ],
      ),
    );
  }

  Widget _contenidoItems(BuildContext context) {
    if (_cargandoItems) return _estado(context, 'Cargando items...');
    if (_errItems != null) return _estado(context, _errItems!, error: true);
    if (_items.isEmpty) return _estado(context, 'No hay items registrados');
    final f = _f;
    return TablaModerna(
      anchoTotal: 620,
      columnSpacing: 12,
      horizontalMargin: 10,
      columnas: const [
        'CODIGO',
        'DESCRIPCION',
        'P/UNITARIO',
        'SERIAL',
        'ESTADO',
        'ACCIONES',
      ],
      filas: [
        for (final i in _items)
          () {
            final activo = i['activo'] == true;
            final serial = i['es_serializado'] == true;
            return DataRow(cells: [
              DataCell(_Codigo('${i['codigo']}', activo: activo)),
              DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text('${i['descripcion']}',
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: activo ? null : _gris)))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                Text(f.format(i['precio_unitario_vigente'] ?? 0),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: activo ? _verde : _gris)),
                const Text(' Bs'),
              ])),
              DataCell(serial
                  ? const _Chip(
                      bg: _ambarBg,
                      fg: _ambarTxt,
                      texto: 'Serial',
                      icono: Icons.qr_code)
                  : const _Chip(
                      bg: _grisBg, fg: _grisTxt, texto: 'Normal')),
              DataCell(activo
                  ? const _Chip(
                      bg: _verdeBg,
                      fg: _verdeTxt,
                      texto: 'Activo',
                      icono: Icons.check_circle)
                  : const _Chip(
                      bg: _rojoBg,
                      fg: _rojo,
                      texto: 'Inactivo',
                      icono: Icons.cancel)),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                _BtnAccion(
                    bg: _azulBg,
                    fg: _azulTxt,
                    icon: Icons.edit,
                    tooltip: 'Editar',
                    onTap: () => _editarItem(i)),
                const SizedBox(width: 6),
                if (activo)
                  _BtnAccion(
                      bg: _ambarBg,
                      fg: _ambarTxt,
                      icon: Icons.toggle_off,
                      tooltip: 'Desactivar',
                      onTap: () => _toggleItem(i))
                else
                  _BtnAccion(
                      bg: _verdeBg,
                      fg: _verdeTxt,
                      icon: Icons.toggle_on,
                      tooltip: 'Activar',
                      onTap: () => _toggleItem(i)),
                const SizedBox(width: 6),
                _BtnAccion(
                    bg: _rojoBg,
                    fg: _rojo,
                    icon: Icons.delete,
                    tooltip: 'Eliminar',
                    onTap: () => _eliminarItem(i)),
              ])),
            ]);
          }(),
      ],
    );
  }

  Widget _tarjetaTramites(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _CabeceraSeccion(
              icono: Icons.book,
              color: _morado,
              titulo: 'Tramites',
              acciones: BtnPrimario('Nuevo Tramite',
                  icon: Icons.add, onPressed: () => _editarTramite()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _contenidoTramites(context),
          ),
        ],
      ),
    );
  }

  Widget _contenidoTramites(BuildContext context) {
    if (_cargandoTramites) return _estado(context, 'Cargando tramites...');
    if (_errTramites != null) {
      return _estado(context, _errTramites!, error: true);
    }
    if (_tramites.isEmpty) {
      return _estado(context, 'No hay tramites registrados');
    }
    final f = _f;
    return TablaModerna(
      anchoTotal: 580,
      columnSpacing: 12,
      horizontalMargin: 10,
      columnas: const ['CODIGO', 'NOMBRE', 'TARIFA', 'ESTADO', 'ACCIONES'],
      filas: [
        for (final t in _tramites)
          () {
            final activo = t['activo'] == true;
            final cod = '${t['codigo'] ?? ''}'.trim();
            return DataRow(cells: [
              DataCell(_Codigo(cod.isEmpty ? 'S/C' : cod, activo: activo)),
              DataCell(ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text('${t['nombre']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: activo ? null : _gris)))),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                Text(f.format(t['tarifa'] ?? 0),
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: activo ? _verde : _gris)),
                const Text(' Bs'),
              ])),
              DataCell(activo
                  ? const _Chip(
                      bg: _verdeBg,
                      fg: _verdeTxt,
                      texto: 'Activo',
                      icono: Icons.check_circle)
                  : const _Chip(
                      bg: _rojoBg,
                      fg: _rojo,
                      texto: 'Inactivo',
                      icono: Icons.cancel)),
              DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                _BtnAccion(
                    bg: _azulBg,
                    fg: _azulTxt,
                    icon: Icons.edit,
                    tooltip: 'Editar',
                    onTap: () => _editarTramite(t)),
                const SizedBox(width: 6),
                if (activo)
                  _BtnAccion(
                      bg: _ambarBg,
                      fg: _ambarTxt,
                      icon: Icons.toggle_off,
                      tooltip: 'Desactivar',
                      onTap: () => _toggleTramite(t))
                else
                  _BtnAccion(
                      bg: _verdeBg,
                      fg: _verdeTxt,
                      icon: Icons.toggle_on,
                      tooltip: 'Activar',
                      onTap: () => _toggleTramite(t)),
                const SizedBox(width: 6),
                _BtnAccion(
                    bg: _rojoBg,
                    fg: _rojo,
                    icon: Icons.delete,
                    tooltip: 'Eliminar',
                    onTap: () => _eliminarTramite(t)),
                if (activo) ...[
                  const SizedBox(width: 6),
                  _BtnAccion(
                      bg: _verdeLinkBg,
                      fg: _verdeLink,
                      icon: Icons.link,
                      tooltip: 'Vincular Items',
                      onTap: () => _verDetalles(t)),
                ],
              ])),
            ]);
          }(),
      ],
    );
  }

  Widget _tarjetaDetalles(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: _CabeceraSeccion(
              icono: Icons.link,
              color: _ambar,
              titulo: 'Items del Tramite: $_tramiteDetallesNombre',
              acciones: _BtnBarra(
                  texto: 'Vincular Item',
                  icon: Icons.add,
                  color: _verdeBtn,
                  onPressed: _abrirVincular),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _contenidoDetalles(context),
          ),
        ],
      ),
    );
  }

  Widget _contenidoDetalles(BuildContext context) {
    if (_cargandoDetalles) return _estado(context, 'Cargando items...');
    if (_errDetalles != null) {
      return _estado(context, _errDetalles!, error: true);
    }
    if (_detalles.isEmpty) {
      return _estado(context,
          'Sin items vinculados. Haga clic en "Vincular Item" para agregar.',
          icono: Icons.inbox);
    }
    final oscuro = T.esOscuro(context);
    final filas = <DataRow>[];
    var total = 0.0;
    for (final d in _detalles) {
      final item = _itemPorId(d['item_id']);
      final precio =
          (item?['precio_unitario_vigente'] as num?)?.toDouble() ?? 0;
      final cantidad = (d['cantidad'] as num?)?.toInt() ?? 1;
      final sub = precio * cantidad;
      total += sub;
      filas.add(DataRow(cells: [
        DataCell(_Codigo('${item?['codigo'] ?? ''}', activo: true)),
        DataCell(Text('${item?['descripcion'] ?? ''}')),
        DataCell(Text('$cantidad',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700))),
        DataCell(Text(_f.format(precio), textAlign: TextAlign.right)),
        DataCell(Text(_f.format(sub),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.w700, color: _verde))),
        DataCell(_BtnAccion(
            bg: _rojoBg,
            fg: _rojo,
            icon: Icons.close,
            tooltip: 'Desvincular',
            onTap: () => _desvincular(d))),
      ]));
    }
    filas.add(DataRow(
      color: WidgetStateProperty.all(
          oscuro ? const Color(0xFF14532D) : const Color(0xFFF0FDF4)),
      cells: [
        DataCell.empty,
        DataCell.empty,
        DataCell.empty,
        DataCell(Align(
          alignment: Alignment.centerRight,
          child: Text('TOTAL:',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: T.texto(context))),
        )),
        DataCell(Align(
          alignment: Alignment.centerRight,
          child: Text('${_f.format(total)} Bs',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: _verdeTxt))),
        ),
        DataCell.empty,
      ],
    ));
    return _TablaTexto(
      anchoTotal: 820,
      columnas: const [
        'CODIGO',
        'DESCRIPCION',
        'CANTIDAD',
        'P/U (Bs)',
        'SUBTOTAL (Bs)',
        'ACCIONES',
      ],
      filas: filas,
    );
  }

  Widget _estado(BuildContext context, String msg,
      {bool error = false, IconData? icono}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Center(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono ?? Icons.info_outline,
              size: 18, color: error ? _rojo : _gris),
          const SizedBox(width: 8),
          Flexible(
            child: Text(msg,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: error ? _rojo : T.texto2(context))),
          ),
        ]),
      ),
    );
  }
}

// ============================ WIDGETS ================================

Future<bool> _confirmar(BuildContext context,
    {required String titulo,
    required String mensaje,
    String okLabel = 'Confirmar'}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: EdgeInsets.zero,
      title: _CabeceraModal(
          titulo: titulo,
          icono: Icons.help_outline,
          c1: _azul,
          c2: _azulOscuro),
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
  final IconData icono;
  final Color c1;
  final Color c2;
  const _CabeceraModal(
      {required this.titulo,
      required this.icono,
      required this.c1,
      required this.c2});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [c1, c2],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Row(children: [
          Icon(icono, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16)),
          ),
        ]),
      );
}

class _CabeceraSeccion extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final Widget? acciones;
  const _CabeceraSeccion(
      {required this.icono,
      required this.color,
      required this.titulo,
      this.acciones});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.only(bottom: 14),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: T.borde(context)))),
        child: Row(children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: T.texto(context))),
          ),
          if (acciones != null) acciones!,
        ]),
      );
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final IconData icono;
  final Color color;
  final bool negrita;
  const _Etiqueta(this.texto, this.icono, this.color, {this.negrita = false});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icono, size: 14, color: color),
        const SizedBox(width: 6),
        Text(texto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: negrita ? FontWeight.w700 : FontWeight.w600,
                color: T.texto(context))),
      ]);
}

class _Chip extends StatelessWidget {
  final Color bg;
  final Color fg;
  final String texto;
  final IconData? icono;
  const _Chip({required this.bg, required this.fg, required this.texto, this.icono});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(texto,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: fg)),
        ]),
      );
}

class _Codigo extends StatelessWidget {
  final String texto;
  final bool activo;
  const _Codigo(this.texto, {required this.activo});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: activo ? _grisBg : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(texto,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: activo ? const Color(0xFF1E293B) : _gris)),
      );
}

class _BtnAccion extends StatelessWidget {
  final Color bg;
  final Color fg;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _BtnAccion(
      {required this.bg,
      required this.fg,
      required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
                width: 30,
                height: 28,
                child: Icon(icon, size: 16, color: fg)),
          ),
        ),
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
          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
    ]);
    if (outline) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          minimumSize: const Size(0, 36),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 36),
        visualDensity: VisualDensity.compact,
        elevation: 0,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: child,
    );
  }
}

/// Igual que [TablaModerna] pero respeta exactamente el texto de las
/// columnas (sin convertir a mayusculas), p.ej. "P/U (Bs)".
class _TablaTexto extends StatelessWidget {
  final List<String> columnas;
  final List<DataRow> filas;
  final double anchoTotal;
  const _TablaTexto(
      {required this.columnas,
      required this.filas,
      this.anchoTotal = 900});

  @override
  Widget build(BuildContext context) {
    final oscuro = T.esOscuro(context);
    return Container(
      decoration: BoxDecoration(
        color: T.tarjeta(context),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: anchoTotal),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
                oscuro ? T.darkHover : T.tableHover),
            headingTextStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: .5,
                color: T.texto2(context)),
            dataTextStyle:
                TextStyle(fontSize: 13.5, color: T.texto(context)),
            horizontalMargin: 16,
            columnSpacing: 20,
            dividerThickness: 1,
            border: TableBorder(
                horizontalInside: BorderSide(color: T.borde(context))),
            columns: [
              for (final c in columnas) DataColumn(label: Text(c)),
            ],
            rows: filas,
          ),
        ),
      ),
    );
  }
}
