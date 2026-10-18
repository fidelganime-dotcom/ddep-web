import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/sesion.dart';

/// Réplica del login.html original: panel split con escudo + formulario.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPass = false;

  Future<void> _entrar() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final email = _user.text.trim().contains('@')
          ? _user.text.trim()
          : '${_user.text.trim()}@ddep.bo';
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _pass.text,
      );
      await sesionOf(context).cargar();
    } catch (e) {
      final msg = e is AuthException ? e.message : e.toString();
      setState(() => _error = msg.contains('Invalid login credentials')
          ? 'Usuario o contraseña incorrectos. Intenta de nuevo.'
          : msg);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final apilado = ancho < 900;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: apilado ? _panelApilado() : _split(),
    );
  }

  Widget _split() => Row(
        children: [
          Expanded(flex: 52, child: _panelIzquierdo()),
          Expanded(flex: 48, child: _panelDerecho()),
        ],
      );

  Widget _panelApilado() => SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(height: 40, child: _panelIzquierdo(compacto: true)),
            _panelDerecho(),
          ],
        ),
      );

  // ---------------- PANEL IZQUIERDO ----------------
  Widget _panelIzquierdo({bool compacto = false}) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A18), Color(0xFF0B1A3A), Color(0xFF0F172A)],
        ),
      ),
      child: Stack(
        children: [
          // Resplandor radial
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.4, 0),
                  radius: .9,
                  colors: [
                    const Color(0x1A3B82F6).withOpacity(.45),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Iconos flotantes sutiles
          Positioned.fill(child: CustomPaint(painter: _IconosFlotantes())),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Brand badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0x1F3B82F6),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                          color: const Color(0x4D3B82F6), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.account_balance,
                            size: 14, color: Color(0xFF60A5FA)),
                        SizedBox(width: 10),
                        Text('DDEP · PANDO',
                            style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  // Emblema con escudo
                  if (!compacto) ...[
                    SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Anillo punteado giratorio
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(seconds: 20),
                            builder: (context, v, _) => Transform.rotate(
                              angle: v * 6.283,
                              child: CustomPaint(
                                  size: const Size(250, 250),
                                  painter: _Anillo(dashed: true)),
                            ),
                          ),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(seconds: 16),
                            builder: (context, v, _) => Transform.rotate(
                              angle: -v * 6.283,
                              child: CustomPaint(
                                  size: const Size(214, 214),
                                  painter: _Anillo(dashed: false)),
                            ),
                          ),
                          // Núcleo con escudo
                          Container(
                            width: 206,
                            height: 206,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0x403B82F6),
                                  Color(0xE60F172A),
                                ],
                              ),
                              border: Border.all(
                                  color: const Color(0x6660A5FA), width: 1),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x403B82F6),
                                    blurRadius: 60,
                                    spreadRadius: 4),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.asset(
                              'assets/images/DDEP.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.account_balance,
                                  size: 80,
                                  color: Color(0xFF60A5FA)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  // Tagline
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: GoogleFonts.outfit(
                          fontSize: compacto ? 20 : 28,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          color: const Color(0xFFF1F5F9)),
                      children: [
                        TextSpan(text: 'Venta de valores y trámites '),
                        TextSpan(
                            text: 'educativos',
                            style: TextStyle(
                                foreground: Paint()
                                  ..shader = LinearGradient(
                                    colors: [
                                      Color(0xFF3B82F6),
                                      Color(0xFF60A5FA),
                                    ],
                                  ).createShader(Rect.fromLTWH(
                                      0, 0, 300, 40)))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Text(
                      'Inventario Kardex, caja, conciliación bancaria y reportes en una sola plataforma',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 15, color: const Color(0xFF64748B)),
                    ),
                  ),
                  // Stats
                  const SizedBox(height: 35),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      _Stat(num: '19', label: 'Entidades'),
                      SizedBox(width: 30),
                      _Stat(num: '4', label: 'Roles'),
                      SizedBox(width: 30),
                      _Stat(num: '100%', label: 'Auditable'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- PANEL DERECHO ----------------
  Widget _panelDerecho() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B1220), Color(0xFF111827), Color(0xFF0F172A)],
        ),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header con icon-box
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)]),
                    boxShadow: const [
                      BoxShadow(
                          color: Color(0x593B82F6),
                          blurRadius: 30,
                          offset: Offset(0, 10)),
                    ],
                  ),
                  child: const Icon(Icons.account_balance,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(height: 20),
                Text('Bienvenido de nuevo',
                    style: GoogleFonts.outfit(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF1F5F9))),
                const SizedBox(height: 6),
                Text('Ingresa tus credenciales para acceder al sistema',
                    style: GoogleFonts.outfit(
                        fontSize: 14, color: const Color(0xFF64748B))),
                const SizedBox(height: 36),
                // Alerta de error
                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: const Color(0x1AEF4444),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x4CEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: Color(0xFFFCA5A5)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_error!,
                              style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: const Color(0xFFFCA5A5))),
                        ),
                      ],
                    ),
                  ),
                ],
                // Usuario
                Text('Usuario',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                TextField(
                  controller: _user,
                  autofocus: true,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: const Color(0xFFF1F5F9)),
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu usuario',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    prefixIcon: const Icon(Icons.person,
                        size: 16, color: Color(0xFF475569)),
                    filled: true,
                    fillColor: const Color(0xB30F172A),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0x1F94A3B8), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF3B82F6), width: 1.5),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (_) => _entrar(),
                ),
                const SizedBox(height: 22),
                // Contraseña
                Text('Contraseña',
                    style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8))),
                const SizedBox(height: 8),
                TextField(
                  controller: _pass,
                  obscureText: !_showPass,
                  style: GoogleFonts.outfit(
                      fontSize: 15, color: const Color(0xFFF1F5F9)),
                  decoration: InputDecoration(
                    hintText: 'Ingresa tu contraseña',
                    hintStyle: const TextStyle(color: Color(0xFF475569)),
                    prefixIcon: const Icon(Icons.lock,
                        size: 16, color: Color(0xFF475569)),
                    suffixIcon: IconButton(
                      icon: Icon(
                          _showPass
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 16,
                          color: const Color(0xFF475569)),
                      onPressed: () =>
                          setState(() => _showPass = !_showPass),
                    ),
                    filled: true,
                    fillColor: const Color(0xB30F172A),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0x1F94A3B8), width: 1.5),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                          color: Color(0xFF3B82F6), width: 1.5),
                    ),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onSubmitted: (_) => _entrar(),
                ),
                const SizedBox(height: 26),
                // Botón
                SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF1E40AF)]),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x593B82F6),
                            blurRadius: 30,
                            offset: Offset(0, 10)),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _busy ? null : _entrar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        textStyle: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.login, size: 18),
                      label: Text(_busy
                          ? 'Ingresando...'
                          : 'Ingresar al Sistema'),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                // Footer
                Text(
                  '© 2026 Dirección Departamental de Educación de Pando',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 6),
                Text(
                  '¿Olvidaste tu contraseña? Solicita el restablecimiento al administrador del sistema.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: const Color(0xFF334155)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- helpers de pintura ----------------

class _Stat extends StatelessWidget {
  final String num, label;
  const _Stat({required this.num, required this.label});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(num,
              style: GoogleFonts.outfit(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF60A5FA))),
          Text(label,
              style:
                  GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      );
}

class _Anillo extends CustomPainter {
  final bool dashed;
  _Anillo({required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = dashed
          ? const Color(0x593B82F6)
          : const Color(0x2E60A5FA);
    if (dashed) {
      const dash = 8.0, gap = 6.0;
      final circumference = 2 * 3.14159 * r;
      final count = circumference / (dash + gap);
      for (var i = 0; i < count; i++) {
        final a1 = (i / count) * 6.283;
        final a2 = ((i * (dash + gap) + dash) / circumference) * 6.283;
        canvas.drawArc(Rect.fromCircle(center: c, radius: r), a1, a2 - a1,
            false, paint);
      }
    } else {
      canvas.drawCircle(c, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Anillo old) => old.dashed != dashed;
}

class _IconosFlotantes extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final iconos = <_Ico>[
      _Ico(Icons.school, .06, .12, .06, 74),
      _Ico(Icons.menu_book, .92, .84, .06, 58),
      _Ico(Icons.receipt_long, .88, .48, .06, 88),
      _Ico(Icons.account_balance, .14, .70, .06, 50),
      _Ico(Icons.inventory_2, .74, .22, .06, 44),
      _Ico(Icons.trending_up, .34, .92, .06, 64),
    ];
    for (final i in iconos) {
      final tp = TextPainter(
        text: TextSpan(
            text: String.fromCharCode(i.icon.codePoint),
            style: TextStyle(
                fontSize: i.tam,
                fontFamily: i.icon.fontFamily,
                package: i.icon.fontPackage,
                color: const Color(0x0F60A5FA))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.width * i.x, size.height * i.y));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Ico {
  final IconData icon;
  final double x, y, op, tam;
  _Ico(this.icon, this.x, this.y, this.op, this.tam);
}
