import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/perfil.dart';
import 'api.dart';

class Sesion extends ChangeNotifier {
  Perfil? perfil;
  bool _cargando = false;

  Future<void> cargar() async {
    if (_cargando) return;
    _cargando = true;
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) {
        perfil = null;
        notifyListeners();
        return;
      }
      final rows = await Api.raw('usuario_sistema',
          columns: '*, rol(nombre)',
          eqField: 'auth_uid',
          eqVal: uid,
          limit: 1);
      perfil = rows.isEmpty ? null : Perfil.fromMap(rows.first);
      if (perfil != null) {
        try {
          await Api.rpc('sp_touch_acceso');
        } catch (_) {}
      }
      notifyListeners();
    } finally {
      _cargando = false;
    }
  }

  Future<void> salir() async {
    await Supabase.instance.client.auth.signOut();
    perfil = null;
    notifyListeners();
  }
}

class SesionScope extends InheritedNotifier<Sesion> {
  const SesionScope({super.key, required Sesion sesion, required super.child})
      : super(notifier: sesion);
}

Sesion sesionOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<SesionScope>()!.notifier!;
