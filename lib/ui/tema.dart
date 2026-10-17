import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tokens de diseño replicados del style.css original (Bootstrap 5 + custom).
class T {
  // Modo claro
  static const bgPrimary = Color(0xFFF1F5F9);
  static const bgCard = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const border = Color(0xFFE2E8F0);
  static const tableHover = Color(0xFFF8FAFC);
  static const accent = Color(0xFF3B82F6);
  static const accentHover = Color(0xFF2563EB);
  static const accentLight = Color(0xFF60A5FA);

  // Modo oscuro
  static const darkBg = Color(0xFF0F172A);
  static const darkCard = Color(0xFF1E293B);
  static const darkText = Color(0xFFE2E8F0);
  static const darkText2 = Color(0xFF94A3B8);
  static const darkBorder = Color(0xFF334155);
  static const darkHover = Color(0xFF334155);

  // Sidebar (siempre oscuro)
  static const sideStart = Color(0xFF0F172A);
  static const sideEnd = Color(0xFF1E293B);
  static const sideLink = Color(0xFF94A3B8);

  // Semáforo
  static const green1 = Color(0xFF22C55E);
  static const green2 = Color(0xFF16A34A);
  static const amber1 = Color(0xFFF59E0B);
  static const amber2 = Color(0xFFD97706);
  static const red1 = Color(0xFFEF4444);
  static const red2 = Color(0xFFDC2626);
  static const purple1 = Color(0xFF8B5CF6);
  static const purple2 = Color(0xFF7C3AED);
  static const cyan1 = Color(0xFF06B6D4);
  static const cyan2 = Color(0xFF0891B2);

  static bool esOscuro(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;
  static Color fondo(BuildContext c) => esOscuro(c) ? darkBg : bgPrimary;
  static Color tarjeta(BuildContext c) => esOscuro(c) ? darkCard : bgCard;
  static Color texto(BuildContext c) => esOscuro(c) ? darkText : textPrimary;
  static Color texto2(BuildContext c) => esOscuro(c) ? darkText2 : textSecondary;
  static Color borde(BuildContext c) => esOscuro(c) ? darkBorder : border;
}

/// Modo claro/oscuro global (como el [data-theme] del original).
final ValueNotifier<ThemeMode> modoTema = ValueNotifier(ThemeMode.light);

ThemeData temaClaro() { final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: T.bgPrimary,
      colorScheme: const ColorScheme.light(
        primary: T.accent,
        secondary: T.accentHover,
        surface: T.bgCard,
        onPrimary: Colors.white,
        onSurface: T.textPrimary,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(backgroundColor: T.bgCard, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: T.bgCard,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.accent, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(color: T.border, space: 1),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: T.textPrimary),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: T.textPrimary),
        bodyMedium: TextStyle(fontSize: 14, color: T.textPrimary),
      ),
    );
    return base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme));
  }

ThemeData temaOscuro() { final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: T.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: T.accent,
        secondary: T.accentLight,
        surface: T.darkCard,
        onPrimary: Colors.white,
        onSurface: T.darkText,
      ),
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(backgroundColor: T.darkCard, elevation: 0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: T.darkCard,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: T.accent, width: 1.5),
        ),
      ),
      dividerTheme:
          const DividerThemeData(color: T.darkBorder, space: 1),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w700, color: T.darkText),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: T.darkText),
        bodyMedium: TextStyle(fontSize: 14, color: T.darkText),
      ),
    );
    return base.copyWith(
        textTheme: GoogleFonts.interTextTheme(base.textTheme));
  }

/// .soft-card / .card del original: tarjeta redondeada con sombra suave.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  const SoftCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20),
      this.margin = const EdgeInsets.symmetric(vertical: 6)});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: T.tarjeta(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: T.esOscuro(context)
                ? Colors.transparent
                : const Color(0x0A000000)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(T.esOscuro(context) ? .3 : .06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Encabezado de sección dentro de una tarjeta (.card-header-section).
class CardHeaderSection extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final Widget? acciones;
  const CardHeaderSection(
      {super.key, required this.icon, required this.titulo, this.acciones});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: T.borde(context)))),
      child: Row(
        children: [
          Icon(icon, color: T.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(titulo,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: T.texto(context))),
          ),
          if (acciones != null) acciones!,
        ],
      ),
    );
  }
}

/// Título de página (.page-title).
class PageTitle extends StatelessWidget {
  final String texto;
  const PageTitle(this.texto, {super.key});
  @override
  Widget build(BuildContext context) => Text(texto,
      style: TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: T.texto(context)));
}

/// .stat-card con ícono circular degradado.
class StatCard extends StatelessWidget {
  final IconData icon;
  final String valor;
  final String etiqueta;
  final Color gradiente1;
  final Color gradiente2;
  final String? cambio;
  final bool positivo;
  const StatCard({
    super.key,
    required this.icon,
    required this.valor,
    required this.etiqueta,
    this.gradiente1 = T.accent,
    this.gradiente2 = T.accentHover,
    this.cambio,
    this.positivo = true,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                  colors: [gradiente1, gradiente2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valor,
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: T.texto(context),
                        height: 1.2)),
                Text(etiqueta,
                    style:
                        TextStyle(fontSize: 14, color: T.texto2(context))),
                if (cambio != null)
                  Text(cambio!,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: positivo ? T.green1 : T.red1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .btn-primary-custom.
class BtnPrimario extends StatelessWidget {
  final String texto;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool cargando;
  const BtnPrimario(this.texto,
      {super.key, this.icon, this.onPressed, this.cargando = false});

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
        backgroundColor: T.accent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

/// .btn-outline-custom.
class BtnSecundario extends StatelessWidget {
  final String texto;
  final IconData? icon;
  final VoidCallback? onPressed;
  const BtnSecundario(this.texto,
      {super.key, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.circle, size: 16),
      label: Text(texto),
      style: OutlinedButton.styleFrom(
        foregroundColor: T.texto(context),
        side: BorderSide(color: T.borde(context)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

/// .btn-danger-custom.
class BtnPeligro extends StatelessWidget {
  final String texto;
  final IconData? icon;
  final VoidCallback? onPressed;
  const BtnPeligro(this.texto, {super.key, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.delete, size: 16),
      label: Text(texto,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: T.red1,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

/// Badges de estado con los colores del sistema (EMITIDO, PAGADA, etc.).
Color colorEstado(String estado, BuildContext context) {
  final e = estado.toUpperCase();
  if (e.contains('ANUL') || e.contains('RECHAZ')) return T.red1;
  if (e.contains('COMPLET') ||
      e.contains('PAGAD') ||
      e.contains('CONCILI') ||
      e.contains('APROBAD') ||
      e.contains('ACTIV') ||
      e.contains('AUTORIZ')) return T.green1;
  if (e.contains('PARCIAL') ||
      e.contains('PENDIENT') ||
      e.contains('EMITID') ||
      e.contains('ABIERT') ||
      e.contains('RECEPCION')) return T.amber1;
  if (e.contains('CERRAD') || e.contains('DESPACH')) return T.purple1;
  return T.texto2(context);
}

class BadgeEstado extends StatelessWidget {
  final String texto;
  const BadgeEstado(this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = colorEstado(texto, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(.35)),
      ),
      child: Text(texto,
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c,
              letterSpacing: .3)),
    );
  }
}

/// Tabla moderna (.table-modern) con hover de filas.
class TablaModerna extends StatelessWidget {
  final List<String> columnas;
  final List<DataRow> filas;
  final double anchoTotal;
  const TablaModerna(
      {super.key,
      required this.columnas,
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
              for (final c in columnas)
                DataColumn(label: Text(c.toUpperCase())),
            ],
            rows: filas,
          ),
        ),
      ),
    );
  }
}
