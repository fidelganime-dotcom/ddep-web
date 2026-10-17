import 'package:supabase_flutter/supabase_flutter.dart';

class Api {
  static SupabaseClient get c => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> raw(
    String table, {
    String columns = '*',
    String? eqField,
    dynamic eqVal,
    String? orderCol,
    bool asc = false,
    int? limit,
  }) async {
    dynamic query = c.from(table).select(columns);
    if (eqField != null) query = query.eq(eqField, eqVal);
    if (orderCol != null) query = query.order(orderCol, ascending: asc);
    if (limit != null) query = query.limit(limit);
    final res = await query;
    return (res as List).cast<Map<String, dynamic>>();
  }

  static Future<Map<String, dynamic>> rpc(String fn,
      [Map<String, dynamic>? params]) async {
    final res = await c.rpc(fn, params: params ?? {});
    if (res is Map<String, dynamic>) return res;
    if (res is List && res.isNotEmpty && res.first is Map<String, dynamic>) {
      return res.first as Map<String, dynamic>;
    }
    return {'data': res};
  }

  static String err(Object e) {
    final s = e.toString();
    for (final pat in [
      RegExp(r'Sin disponibilidad[^"]*'),
      RegExp(r'Doble firma[^"]*'),
      RegExp(r'Solo [^"]*'),
      RegExp(r'La caja[^"]*'),
      RegExp(r'La venta[^"]*'),
      RegExp(r'La nota[^"]*'),
      RegExp(r'El día[^"]*'),
      RegExp(r'El pedido[^"]*'),
      RegExp(r'El usuario[^"]*'),
      RegExp(r'El correo[^"]*'),
      RegExp(r'No [^"]*'),
      RegExp(r'Pedido [^"]*'),
      RegExp(r'Venta [^"]*'),
      RegExp(r'Ítem [^"]*'),
      RegExp(r'Cantidad [^"]*'),
      RegExp(r'Falta [^"]*'),
      RegExp(r'Primero [^"]*'),
      RegExp(r'Requiere [^"]*'),
      RegExp(r'Nota [^"]*'),
      RegExp(r'Seleccione[^"]*'),
      RegExp(r'La contraseña[^"]*'),
      RegExp(r'Las contraseñas[^"]*'),
    ]) {
      final m = pat.firstMatch(s);
      if (m != null) {
        var t = m.group(0)!;
        t = t.replaceAll('\\n', ' ').trim();
        return t;
      }
    }
    final i = s.indexOf('message:');
    if (i >= 0) {
      var rest = s.substring(i + 8).trim();
      final end = rest.indexOf(RegExp(r'[,}]'));
      if (end > 0) rest = rest.substring(0, end);
      return rest.replaceAll('\\n', ' ').trim();
    }
    return s.length > 220 ? s.substring(0, 220) : s;
  }
}
