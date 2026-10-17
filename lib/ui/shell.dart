import 'package:flutter/material.dart';
import '../services/sesion.dart';
import 'dashboard_page.dart';
import 'ventas_page.dart';
import 'inventario_page.dart';
import 'caja_page.dart';
import 'catalogos_page.dart';
import 'conciliacion_page.dart';
import 'auditoria_page.dart';
import 'reportes_page.dart';
import 'usuarios_page.dart';

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

  List<_NavItem> _items() {
    final rol = sesionOf(context).perfil?.rol ?? '';
    final todos = <String>{'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'};
    return [
      _NavItem(Icons.dashboard, 'Inicio', const DashboardPage(), todos),
      _NavItem(Icons.point_of_sale, 'Ventas', const VentasPage(),
          {'ADMIN', 'CAJERA'}),
      _NavItem(Icons.inventory_2, 'Inventario', const InventarioPage(),
          {'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.payments, 'Caja', const CajaPage(),
          {'ADMIN', 'CAJERA', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.category, 'Catálogos', const CatalogosPage(), todos),
      _NavItem(Icons.account_balance, 'Conciliación', const ConciliacionPage(),
          {'ADMIN', 'TESORERIA', 'AUDITOR'}),
      _NavItem(Icons.description, 'Reportes', const ReportesPage(), todos),
      _NavItem(Icons.gavel, 'Auditoría', const AuditoriaPage(),
          {'ADMIN', 'AUDITOR'}),
      _NavItem(Icons.people, 'Usuarios', const UsuariosPage(), {'ADMIN'}),
    ].where((n) => n.roles.contains(rol)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sesion = sesionOf(context);
    final items = _items();
    if (_idx >= items.length) _idx = 0;
    final ancho = MediaQuery.sizeOf(context).width;
    final wide = ancho > 900;

    final rail = NavigationRail(
      selectedIndex: _idx,
      onDestinationSelected: (i) => setState(() => _idx = i),
      extended: wide && ancho > 1200,
      backgroundColor: const Color(0xFF1F3864),
      selectedIconTheme: const IconThemeData(color: Colors.white),
      unselectedIconTheme: const IconThemeData(color: Colors.white70),
      selectedLabelTextStyle:
          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
      leading: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Icon(Icons.account_balance, color: Color(0xFFC9A227), size: 36),
      ),
      destinations: [
        for (final n in items)
          NavigationRailDestination(icon: Icon(n.icon), label: Text(n.label)),
      ],
    );

    return Scaffold(
      body: Row(
        children: [
          if (wide) rail else const SizedBox.shrink(),
          Expanded(
            child: Column(
              children: [
                Material(
                  color: const Color(0xFF1F3864),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          if (!wide)
                            Builder(builder: (ctx) {
                              return PopupMenuButton<String>(
                                icon: const Icon(Icons.menu, color: Colors.white),
                                onSelected: (v) {
                                  final i = items
                                      .indexWhere((n) => n.label == v);
                                  if (i >= 0) setState(() => _idx = i);
                                },
                                itemBuilder: (_) => [
                                  for (final n in items)
                                    PopupMenuItem(
                                        value: n.label,
                                        child: Row(
                                          children: [
                                            Icon(n.icon, size: 18),
                                            const SizedBox(width: 8),
                                            Text(n.label),
                                          ],
                                        )),
                                ],
                              );
                            }),
                          if (!wide)
                            const Icon(Icons.account_balance,
                                color: Color(0xFFC9A227)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'DDEP Pando — ${items[_idx].label}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          Text(
                            '${sesion.perfil?.nombre ?? ''} (${sesion.perfil?.rol ?? ''})',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          IconButton(
                            tooltip: 'Cerrar sesión',
                            icon: const Icon(Icons.logout,
                                color: Colors.white, size: 20),
                            onPressed: () => sesion.salir(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
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
