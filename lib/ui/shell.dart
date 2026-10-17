import 'package:flutter/material.dart';
import '../services/sesion.dart';
import 'tema.dart';
import 'dashboard_page.dart';
import 'ventas_page.dart';
import 'inventario_page.dart';
import 'caja_page.dart';
import 'catalogos_page.dart';
import 'conciliacion_page.dart';
import 'auditoria_page.dart';
import 'reportes_page.dart';
import 'usuarios_page.dart';
import 'roles_page.dart';

/// Réplica del layout.html original: sidebar fijo 70px -> 260px al pasar el
/// mouse (o botón en móvil), marca, menú con sección SEGURIDAD y footer con
/// usuario + tema + cerrar sesión.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _NavItem {
  final IconData icon;
  final String label;
  final Widget page;
  final Set<String> roles;
  _NavItem(this.icon, this.label, this.page, this.roles);
}

class _ShellState extends State<Shell> {
  int _idx = 0;
  bool _hover = false;
  bool _drawerAbierto = false;

  List<_NavItem> _items() {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final todos = <String>{'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'};
    return [
      _NavItem(Icons.dashboard, 'Página Principal', const DashboardPage(),
          todos),
      _NavItem(Icons.shopping_cart, 'Ventas', const VentasPage(),
          {'ADMIN', 'CAJERA'}),
      _NavItem(Icons.inventory_2, 'Inventario', const InventarioPage(),
          {'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.payments, 'Caja', const CajaPage(),
          {'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.book, 'Catálogos', const CatalogosPage(), todos),
      _NavItem(Icons.swap_horiz, 'Conciliación', const ConciliacionPage(),
          {'ADMIN', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.verified_user, 'Auditoría', const AuditoriaPage(),
          {'ADMIN', 'AUDITOR'}),
      _NavItem(Icons.bar_chart, 'Reportes', const ReportesPage(), todos),
      _NavItem(Icons.people, 'Usuarios', const UsuariosPage(), {'ADMIN'}),
      _NavItem(Icons.key, 'Roles y permisos', const RolesPage(), {'ADMIN'}),
    ].where((n) => n.roles.contains(rol)).toList();
  }

  bool get _esMovil => MediaQuery.sizeOf(context).width < 900;

  Widget _sidebar(List<_NavItem> items, {bool forzarExpandido = false}) {
    final sesion = sesionOf(context);
    final visible =
        forzarExpandido || _hover || (_esMovil && _drawerAbierto);
    final ancho = visible ? 260.0 : 70.0;

    Widget link(_NavItem n, int i) {
      final activo = i == _idx;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          setState(() {
            _idx = i;
            _drawerAbierto = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: activo
                ? const Color(0x263B82F6)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border(
              left: BorderSide(
                width: 3,
                color: activo || visible
                    ? (activo ? T.accent : Colors.transparent)
                    : Colors.transparent,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Icon(n.icon,
                    size: 17,
                    color: activo ? T.accent : T.sideLink),
              ),
              if (visible) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    n.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: activo ? FontWeight.w600 : FontWeight.w500,
                      color: activo ? T.accent : const Color(0xFFE2E8F0),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return MouseRegion(
      onEnter: (_) {
        if (!_esMovil) setState(() => _hover = true);
      },
      onExit: (_) {
        if (!_esMovil) setState(() => _hover = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: ancho,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [T.sideStart, T.sideEnd],
          ),
          border: Border(right: BorderSide(color: Color(0x0DFFFFFF))),
        ),
        clipBehavior: Clip.antiAlias,
        child: (_esMovil && !_drawerAbierto && !forzarExpandido)
            ? const SizedBox.shrink()
            : Column(
                children: [
                  // Marca
                  Container(
                    height: 60,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: const BoxDecoration(
                        border: Border(
                            bottom: BorderSide(color: Color(0x14FFFFFF))),
                        color: T.sideStart),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: const LinearGradient(
                                colors: [T.accent, T.purple1]),
                          ),
                          child: const Icon(Icons.account_balance,
                              color: Colors.white, size: 18),
                        ),
                        if (visible) ...[
                          const SizedBox(width: 12),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('DDEP',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700)),
                              Text('Educación de Pando',
                                  style: TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Navegación
                  Expanded(
                    child: Builder(
                      builder: (ctx) {
                        final principales = [
                          for (var i = 0; i < items.length; i++)
                            if (items[i].label != 'Usuarios' &&
                                items[i].label != 'Roles y permisos')
                              (i, items[i])
                        ];
                        final seguridad = [
                          for (var i = 0; i < items.length; i++)
                            if (items[i].label == 'Usuarios' ||
                                items[i].label == 'Roles y permisos')
                              (i, items[i])
                        ];
                        return ListView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          children: [
                            for (final (i, n) in principales) link(n, i),
                            if (seguridad.isNotEmpty) ...[
                              if (visible)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 20, top: 14, bottom: 4),
                                  child: Text('SEGURIDAD',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.5,
                                          color: T.texto2(context))),
                                ),
                              for (final (i, n) in seguridad) link(n, i),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                  // Footer usuario
                  Container(
                    padding: const EdgeInsets.only(top: 12),
                    decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Color(0x14FFFFFF)))),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                      colors: [T.accent, T.purple1]),
                                ),
                                child: const Icon(Icons.person,
                                    color: Colors.white, size: 20),
                              ),
                              if (visible) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        sesion.perfil?.nombre ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFFE2E8F0),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        sesion.perfil?.rol ?? '',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                          child: Row(
                            children: [
                              // Tema (oculto sin expandir, como el original)
                              if (visible)
                                IconButton(
                                  tooltip: 'Cambiar tema',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 38, minHeight: 36),
                                  icon: ValueListenableBuilder<ThemeMode>(
                                    valueListenable: modoTema,
                                    builder: (_, m, __) => Icon(
                                        m == ThemeMode.dark
                                            ? Icons.light_mode
                                            : Icons.dark_mode,
                                        size: 17,
                                        color: const Color(0xFF94A3B8)),
                                  ),
                                  onPressed: () => modoTema.value =
                                      modoTema.value == ThemeMode.dark
                                          ? ThemeMode.light
                                          : ThemeMode.dark,
                                ),
                              const SizedBox(width: 8),
                              // Cerrar sesión
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => _confirmarSalida(),
                                  child: Container(
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0x26EF4444),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.logout,
                                            size: 15, color: T.red1),
                                        if (visible) ...[
                                          const SizedBox(width: 10),
                                          const Text('Cerrar sesión',
                                              style: TextStyle(
                                                  color: T.red1,
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w600)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _confirmarSalida() {
    final sesion = sesionOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text(
            '¿Deseas cerrar tu sesión de forma segura? Tendrás que iniciar sesión nuevamente.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: T.red1,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              sesion.salir();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = sesionOf(context);
    final items = _items();
    if (_idx >= items.length) _idx = 0;

    final sidebar = _sidebar(items);

    return Scaffold(
      backgroundColor: T.fondo(context),
      drawer: _esMovil
          ? Drawer(
              width: 260,
              backgroundColor: T.sideStart,
              child: _sidebar(items, forzarExpandido: true))
          : null,
      body: Row(
        children: [
          if (!_esMovil) sidebar,
          Expanded(
            child: Column(
              children: [
                // Content-header
                Container(
                  color: T.tarjeta(context),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        if (_esMovil)
                          Builder(builder: (bctx) => IconButton(
                            icon: Icon(Icons.list,
                                size: 26, color: T.texto(context)),
                            onPressed: () =>
                                Scaffold.of(bctx).openDrawer(),
                          )),
                        const Spacer(),
                        Text(
                          sesion.perfil?.nombre ?? '',
                          style: TextStyle(
                              fontSize: 13, color: T.texto2(context)),
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: T.borde(context)),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(_esMovil ? 12 : 24),
                    child: items[_idx].page,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
