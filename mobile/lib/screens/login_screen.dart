part of '../main.dart';


// Decorative neon music-stage artwork shared by the auth screens.
class MindoAuthBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final glow = Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2;
    final fill = Paint()..style = PaintingStyle.fill;

    // Neon light trails along the lower and middle edges.
    final trail = Path()
      ..moveTo(-10, size.height * .60)
      ..cubicTo(size.width * .18, size.height * .49,
          size.width * .28, size.height * .73, size.width * .50, size.height * .63)
      ..cubicTo(size.width * .70, size.height * .54,
          size.width * .82, size.height * .48, size.width + 10, size.height * .61);
    glow.color = const Color(0xFFFF35D3).withOpacity(.75);
    glow.maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    canvas.drawPath(trail, glow);
    glow.color = const Color(0xFFFFD76A).withOpacity(.70);
    glow.maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    glow.strokeWidth = 1.3;
    canvas.drawPath(trail, glow);

    final lowerTrail = Path()
      ..moveTo(-10, size.height * .91)
      ..quadraticBezierTo(size.width * .25, size.height * .82, size.width * .48, size.height * .93)
      ..quadraticBezierTo(size.width * .75, size.height * 1.02, size.width + 10, size.height * .88);
    glow.color = const Color(0xFFB800FF).withOpacity(.75);
    glow.strokeWidth = 2.5;
    canvas.drawPath(lowerTrail, glow);

    // Simple distant skyline silhouette.
    fill.color = const Color(0xFF090315).withOpacity(.75);
    final skylineY = size.height * .94;
    final buildings = <Rect>[
      Rect.fromLTWH(size.width*.02, skylineY-32, size.width*.08, 50),
      Rect.fromLTWH(size.width*.12, skylineY-52, size.width*.07, 70),
      Rect.fromLTWH(size.width*.22, skylineY-27, size.width*.08, 45),
      Rect.fromLTWH(size.width*.34, skylineY-61, size.width*.07, 79),
      Rect.fromLTWH(size.width*.45, skylineY-38, size.width*.09, 56),
      Rect.fromLTWH(size.width*.59, skylineY-55, size.width*.07, 73),
      Rect.fromLTWH(size.width*.70, skylineY-30, size.width*.08, 48),
      Rect.fromLTWH(size.width*.82, skylineY-60, size.width*.07, 78),
      Rect.fromLTWH(size.width*.92, skylineY-35, size.width*.08, 53),
    ];
    for (final building in buildings) { canvas.drawRect(building, fill); }

    // Scattered music-note and sparkle accents.
    final notePaint = Paint()..color = const Color(0xFFFF35D3).withOpacity(.9);
    final sparkles = <Offset>[
      Offset(size.width*.10, size.height*.15),
      Offset(size.width*.88, size.height*.22),
      Offset(size.width*.78, size.height*.43),
      Offset(size.width*.18, size.height*.38),
      Offset(size.width*.91, size.height*.72),
    ];
    for (final point in sparkles) {
      canvas.drawCircle(point, 1.8, notePaint);
      canvas.drawCircle(point, 5.5, Paint()..color = notePaint.color.withOpacity(.18));
    }
    final noteStyle = const TextStyle(fontSize: 27, color: Color(0xFFFF35D3), fontWeight: FontWeight.w600);
    for (final item in <MapEntry<String, Offset>>[
      MapEntry('♪', Offset(size.width*.07, size.height*.18)),
      MapEntry('♫', Offset(size.width*.83, size.height*.30)),
    ]) {
      final tp = TextPainter(text: TextSpan(text: item.key, style: noteStyle), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, item.value);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ============================================================
// LOGIN
// ============================================================

class LoginScreen
    extends StatefulWidget {
  const LoginScreen({
    super.key,
  });

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {
  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  bool loading = false;
  bool obscure = true;

  Future<void> login() async {
    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    if (email.isEmpty ||
        password.isEmpty) {
      showMessage(
        'Email/phone and password required',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data =
          await api.login(
        email,
        password,
      );

      final token =
          data['token']?.toString();

      if (token == null ||
          token.isEmpty) {
        throw Exception(
          'Token not received',
        );
      }

      final prefs =
          await SharedPreferences
              .getInstance();

      await prefs.setString(
        'token',
        token,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HomeScreen(
            token: token,
          ),
        ),
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(
    String message,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  void socialLogin(String provider) {
    showMessage(
      '$provider login will be connected next.',
    );
  }

  InputDecoration fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF8E8795),
        fontSize: 17,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF5F2DB8),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white.withOpacity(0.92),
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 18,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFFE0D8E8),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: Color(0xFF7B3FC6),
          width: 1.5,
        ),
      ),
    );
  }

@override
Widget build(BuildContext context) {
  const midnight = Color(0xFF10051F);
  const deepPurple = Color(0xFF28103D);
  const gold = Color(0xFFFFD76A);
  const magenta = Color(0xFFFF35D3);
  const royalPurple = Color(0xFF7900FF);

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(22),
    borderSide: const BorderSide(color: gold, width: 1.4),
  );

  return Scaffold(
    backgroundColor: midnight,
    body: Stack(
      children: [
        const Positioned.fill(
          child: CustomPaint(
            painter: MindoAuthBackdropPainter(),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  midnight.withOpacity(0.25),
                  const Color(0xFF160025).withOpacity(0.75),
                  midnight,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  children: [
                    const SizedBox(height: 8),

                    // MINDO logo
                    Container(
                      width: 132,
                      height: 132,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: gold, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: magenta.withOpacity(0.7),
                            blurRadius: 24,
                            spreadRadius: 3,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'ChatGPT Image Oct 8, 2026, 11_35_07 PM.png',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.music_note,
                                color: gold,
                                size: 64,
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    const Text(
                      'MINDO',
                      style: TextStyle(
                        color: gold,
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: magenta, blurRadius: 18),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'VOICE CHAT',
                      style: TextStyle(
                        color: Color(0xFFFF79BF),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Talk  •  Meet  •  Connect',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 26),

                    // Google and Facebook buttons
                    Row(
                      children: [
                        Expanded(
                          child: _socialButton(
                            label: 'Google',
                            icon: Icons.g_mobiledata,
                            onTap: () => socialLogin('Google'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _socialButton(
                            label: 'Facebook',
                            icon: Icons.facebook,
                            onTap: () => socialLogin('Facebook'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: gold.withOpacity(0.65),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: gold,
                              fontWeight: FontWeight.bold,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: gold.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Welcome Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Login to your MINDO account',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: gold,
                      decoration: InputDecoration(
                        hintText: 'Email or Phone',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        filled: true,
                        fillColor: deepPurple.withOpacity(0.88),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 18,
                        ),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: const BorderSide(
                            color: magenta,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: obscure,
                      style: const TextStyle(color: Colors.white),
                      cursorColor: gold,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        hintStyle: const TextStyle(color: Colors.white60),
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() => obscure = !obscure);
                          },
                          icon: Icon(
                            obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.white,
                          ),
                        ),
                        filled: true,
                        fillColor: deepPurple.withOpacity(0.88),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 22,
                          horizontal: 18,
                        ),
                        border: fieldBorder,
                        enabledBorder: fieldBorder,
                        focusedBorder: fieldBorder.copyWith(
                          borderSide: const BorderSide(
                            color: magenta,
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          showMessage(
                            'Password reset will be connected next.',
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 66,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF83AD),
                            Color(0xFFFF009D),
                            Color(0xFF9900FF),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: gold, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: magenta.withOpacity(0.55),
                            blurRadius: 22,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: loading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                          ),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(width: 24),
                                  Icon(
                                    Icons.arrow_forward_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 22),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account? ",
                          style: TextStyle(color: Colors.white70),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'Register Now',
                            style: TextStyle(
                              color: gold,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _socialButton({
  required String label,
  required IconData icon,
  required VoidCallback onTap,
}) {
  return Container(
    height: 60,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [
          Color(0xFF35104D),
          Color(0xFF16051F),
        ],
      ),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: const Color(0xFFFFD76A),
        width: 1.4,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFFF35D3).withOpacity(0.3),
          blurRadius: 12,
        ),
      ],
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 29),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
}
}

