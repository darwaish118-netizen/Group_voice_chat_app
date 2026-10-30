import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl =
    'https://voice-chat-app-gsb9.onrender.com';

void main() {
  runApp(const VoiceChatApp());
}

class VoiceChatApp extends StatelessWidget {
  const VoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Voice Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor:
            const Color(0xFFF7F5FA),
      ),
      home: const AuthGate(),
    );
  }
}

// ============================================================
// API SERVICE
// ============================================================

class ApiService {
  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/auth/login',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/auth/register',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'username': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  Future<List<dynamic>> getRooms(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$apiBaseUrl/api/rooms',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    final data = _handleResponse(response);

    return data['rooms'] ?? [];
  }

Future<Map<String, dynamic>> createRoom(
  String token,
  String name, {
  String? coverImageUrl,
}) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/api/rooms'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    },
    body: jsonEncode({
      'name': name,
      'cover_image_url': coverImageUrl,
    }),
  );

  return _handleResponse(response);
}
    
  Future<Map<String, dynamic>> me(
    String token,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$apiBaseUrl/api/me',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  // ==========================================================
  // SAVE PROFILE DETAILS
  // ==========================================================

  Future<Map<String, dynamic>> saveProfileDetails(
    String token,
    String displayName,
    String signature,
    String birthday, {
    String? country,
    String? gender,
  }) async {
    final response = await http.put(
      Uri.parse(
        '$apiBaseUrl/api/me/profile',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'display_name':
            displayName.trim(),
        'signature':
            signature.trim(),
        'birthday':
            birthday.trim().isEmpty
                ? null
                : birthday.trim(),
        'country':
            country?.trim().isEmpty ?? true
                ? null
                : country!.trim(),
        'gender':
            gender?.trim().isEmpty ?? true
                ? null
                : gender!.trim(),
      }),
    );

    return _handleResponse(response);
  }

  // ==========================================================
  // SAVE PROFILE PHOTO
  // ==========================================================

  Future<Map<String, dynamic>> saveProfilePhoto(
    String token,
    String avatarUrl,
  ) async {
    final response = await http.put(
      Uri.parse(
        '$apiBaseUrl/api/me/avatar',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'avatar_url': avatarUrl,
      }),
    );

    return _handleResponse(response);
  }

  // ==========================================================
  // ROOM SEATS
  // ==========================================================

  Future<Map<String, dynamic>> getRoomMembers(
    String token,
    String roomId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$apiBaseUrl/api/rooms/$roomId/members',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> joinRoomSeat(
    String token,
    String roomId,
    int seatNumber,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/rooms/$roomId/seats/$seatNumber/join',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> leaveRoomSeat(
    String token,
    String roomId,
    int seatNumber,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/rooms/$roomId/seats/$seatNumber/leave',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> leaveRoom(
    String token,
    String roomId,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/rooms/$roomId/leave',
      ),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

    
  Future<Map<String, dynamic>> getDiamondExchange(String token) async {
    final headers = {'Authorization': 'Bearer $token'};
    final configResponse = await http.get(
      Uri.parse('$apiBaseUrl/api/wallet/diamond-exchange-config'),
      headers: headers,
    );
    final configData = _handleResponse(configResponse);
    final balanceResponse = await http.get(
      Uri.parse('$apiBaseUrl/api/wallet/balance'),
      headers: headers,
    );
    final balanceData = _handleResponse(balanceResponse);
    return {
      'config': configData['config'] ?? configData,
      'balance': balanceData['balance'] ?? balanceData['user'] ?? balanceData,
    };
  }

  Future<Map<String, dynamic>> getCoinHistory(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/wallet/coin-history'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> exchangeDiamonds(String token, int diamonds) async {
    final response = await http.post(Uri.parse('$apiBaseUrl/api/wallet/diamond-exchange'), headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'}, body: jsonEncode({'diamonds': diamonds}));
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getDiamondHistory(String token) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/api/wallet/diamond-history'), headers: {'Authorization': 'Bearer $token'});
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getLevelProgress(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/levels/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getLevelConfig(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/levels/config'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    dynamic body;

    try {
      body = jsonDecode(response.body);
    } catch (_) {
      body = {};
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      if (body is Map<String, dynamic>) {
        return body;
      }

      return {};
    }

    String message =
        'Something went wrong';

    if (body is Map &&
        body['message'] != null) {
      message =
          body['message'].toString();
    } else if (body is Map &&
        body['error'] != null) {
      message =
          body['error'].toString();
    }

    throw Exception(message);
  }
}

final ApiService api = ApiService();

// ============================================================
// CLOUDINARY PROFILE PHOTO UPLOAD
// ============================================================

Future<String?> uploadProfilePhotoToCloudinary(
  String imagePath,
) async {
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/tfeew7qa/image/upload',
      ),
    );

    request.fields['upload_preset'] =
        'mindo_profile_photos';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imagePath,
      ),
    );

    final response =
        await request.send();

    final responseBody =
        await response.stream.bytesToString();

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      final data =
          jsonDecode(responseBody);

      return data['secure_url']
          ?.toString();
    }

    return null;
  } catch (_) {
    return null;
  }
}

// ROOM COVER IMAGE UPLOAD
Future<String?> uploadRoomCoverToCloudinary(
  String imagePath,
) async {
  try {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(
        'https://api.cloudinary.com/v1_1/tfeew7qa/image/upload',
      ),
    );

    request.fields['upload_preset'] = 'mindo_room_covers';

    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        imagePath,
      ),
    );

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      final data = jsonDecode(responseBody);
      return data['secure_url']?.toString();
    }

    return null;
  } catch (e) {
    return null;
  }
}

// ============================================================
// AUTH GATE
// ============================================================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() =>
      _AuthGateState();
}

class _AuthGateState
    extends State<AuthGate> {
  bool loading = true;
  String? token;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }


Future<void> checkLogin() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    if (!mounted) return;

    setState(() {
      token = savedToken;
      loading = false;
    });
  } catch (e) {
    debugPrint('AuthGate checkLogin error: $e');

    if (!mounted) return;

    setState(() {
      token = null;
      loading = false;
    });
  }
}


  String countryFlag(String country) {
    const flags = {
      'Pakistan': '🇵🇰',
      'India': '🇮🇳',
      'United Arab Emirates': '🇦🇪',
      'United Kingdom': '🇬🇧',
      'Saudi Arabia': '🇸🇦',
      'Bangladesh': '🇧🇩',
      'Nepal': '🇳🇵',
      'Qatar': '🇶🇦',
      'Kuwait': '🇰🇼',
      'Oman': '🇴🇲',
      'Bahrain': '🇧🇭',
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'Australia': '🇦🇺',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Turkey': '🇹🇷',
    };
    return flags[country] ?? '🌍';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (token == null ||
        token!.isEmpty) {
      return const LoginScreen();
    }

    return HomeScreen(
      token: token!,
    );
  }
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
  const royalPurple = Color(0xFF7026A8);
  const gold = Color(0xFFFFD76A);
  const magenta = Color(0xFFE83EAD);

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(18),
    borderSide: BorderSide(
      color: gold.withOpacity(0.38),
      width: 1,
    ),
  );

return Scaffold(
  backgroundColor: midnight,
  body: Container(
    decoration: BoxDecoration(
      image: DecorationImage(
        image: AssetImage('assets/auth_background_new.png'),
        fit: BoxFit.cover,
      ),
    ),
    child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 30),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: gold,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: magenta.withOpacity(0.40),
                          blurRadius: 28,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/ChatGPT Image Oct 8, 2026, 11_35_07 PM.png',
                        width: 112,
                        height: 112,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'MINDO',
                    style: TextStyle(
                      color: gold,
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'VOICE CHAT',
                    style: TextStyle(
                      color: Color(0xFFE7B9FF),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'Talk  •  Meet  •  Connect',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.70),
                      fontSize: 14,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 34),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => socialLogin('Google'),
                          icon: const Icon(
                            Icons.g_mobiledata_rounded,
                            size: 30,
                          ),
                          label: const Text('Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: deepPurple,
                            side: BorderSide(
                              color: gold.withOpacity(0.55),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: loading
                              ? null
                              : () => socialLogin('Facebook'),
                          icon: const Icon(
                            Icons.facebook_rounded,
                            size: 25,
                          ),
                          label: const Text('Facebook'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: deepPurple,
                            side: BorderSide(
                              color: gold.withOpacity(0.55),
                            ),
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.28),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withOpacity(0.28),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Welcome Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Login to your MINDO account',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.66),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: gold,
                    decoration: InputDecoration(
                      hintText: 'Email or Phone',
                      hintStyle: const TextStyle(
                        color: Colors.white60,
                      ),
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        color: gold,
                      ),
                      filled: true,
                      fillColor: deepPurple.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 19,
                        horizontal: 18,
                      ),
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: gold,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextField(
                    controller: passwordController,
                    obscureText: obscure,
                    style: const TextStyle(color: Colors.white),
                    cursorColor: gold,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: const TextStyle(
                        color: Colors.white60,
                      ),
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: gold,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            obscure = !obscure;
                          });
                        },
                        icon: Icon(
                          obscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: gold,
                        ),
                      ),
                      filled: true,
                      fillColor: deepPurple.withOpacity(0.85),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 19,
                        horizontal: 18,
                      ),
                      border: fieldBorder,
                      enabledBorder: fieldBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: gold,
                          width: 1.8,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFE83EAD),
                          Color(0xFF9229D0),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: gold.withOpacity(0.80),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: magenta.withOpacity(0.30),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: loading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        disabledBackgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text(
                              'LOGIN',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 27),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                        ),
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
    ),
  );
}
}

// ============================================================
// REGISTER
// ============================================================

class RegisterScreen
    extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final nameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final passwordController =
      TextEditingController();

  final ImagePicker _picker =
      ImagePicker();

  XFile? selectedImage;
  String birthday = '';
  String country = '';
  String gender = '';
  bool loading = false;

  final List<String> countries = const [
    'Pakistan',
    'India',
    'United Arab Emirates',
    'United Kingdom',
    'Saudi Arabia',
    'Bangladesh',
    'Nepal',
    'Qatar',
    'Kuwait',
    'Oman',
    'Bahrain',
    'United States',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Turkey',
  ];

  final List<String> genders = const [
    'Male',
    'Female',
  ];

  Future<void> pickBirthday() async {
    final now = DateTime.now();
    DateTime initialDate =
        DateTime(now.year - 18, now.month, now.day);

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Select your birthday',
    );

    if (selected == null || !mounted) return;

    final month = selected.month.toString().padLeft(2, '0');
    final day = selected.day.toString().padLeft(2, '0');

    setState(() {
      birthday = '${selected.year}-$month-$day';
    });
  }

  Future<void> pickProfileImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null || !mounted) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      showMessage('Image select failed: $e');
    }
  }

  void showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  pickProfileImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  pickProfileImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage('Please fill all fields');
      return;
    }

    if (birthday.isEmpty) {
      showMessage('Please choose your birthday');
      return;
    }

    if (country.isEmpty) {
      showMessage('Please choose your country');
      return;
    }

    if (gender.isEmpty) {
      showMessage('Please choose your gender');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must be at least 6 characters');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data = await api.register(
        name,
        email,
        password,
      );

      final token = data['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception(
          'Registration successful but token missing',
        );
      }

      // Save the registration profile details after the account
      // is created because the auth endpoint creates the account first.
      await api.saveProfileDetails(
        token,
        name,
        '',
        birthday,
        country: country,
        gender: gender,
      );

      if (selectedImage != null) {
        final avatarUrl =
            await uploadProfilePhotoToCloudinary(
          selectedImage!.path,
        );

        if (avatarUrl == null) {
          throw Exception('Profile photo upload failed');
        }

        await api.saveProfilePhoto(
          token,
          avatarUrl,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => HomeScreen(token: token),
        ),
        (route) => false,
      );
    } catch (e) {
      showMessage(
        e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
    
Widget _registerField({
  required TextEditingController controller,
  required String label,
  required String hint,
  required IconData icon,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
}) {
  const gold = Color(0xFFFFD76A);

  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    style: const TextStyle(color: Colors.white),
    cursorColor: gold,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: gold),
      hintStyle: const TextStyle(color: Colors.white60),
      prefixIcon: Icon(icon, color: gold),
      filled: true,
      fillColor: const Color(0xFF38205A),
      contentPadding: const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: gold.withOpacity(0.35),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: gold.withOpacity(0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: gold,
          width: 1.8,
        ),
      ),
    ),
  );
}

Widget _registerDropdown({
  required String label,
  required IconData icon,
  required String value,
  required List<String> items,
  required ValueChanged<String?> onChanged,
}) {
  const gold = Color(0xFFFFD76A);

  return DropdownButtonFormField<String>(
    value: items.contains(value) ? value : null,
    dropdownColor: const Color(0xFF38205A),
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: gold),
      prefixIcon: Icon(icon, color: gold),
      filled: true,
      fillColor: const Color(0xFF38205A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: gold.withOpacity(0.35),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: gold,
          width: 1.8,
        ),
      ),
    ),
    items: items.map((item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(item),
      );
    }).toList(),
    onChanged: onChanged,
  );
}

Widget _registerDisplayField({
  required String label,
  required String value,
  required IconData icon,
}) {
  const gold = Color(0xFFFFD76A);

  return InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: gold),
      prefixIcon: Icon(icon, color: gold),
      filled: true,
      fillColor: const Color(0xFF38205A),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: gold.withOpacity(0.35),
        ),
      ),
    ),
    child: Text(
      value,
      style: TextStyle(
        color: value == 'Select your birthday'
            ? Colors.white60
            : Colors.white,
      ),
    ),
  );
}

Widget build(BuildContext context) {
  ImageProvider<Object>? avatarImage;

  if (selectedImage != null) {
    avatarImage = FileImage(File(selectedImage!.path));
  }

  return Scaffold(
    backgroundColor: const Color(0xFF09051B),
    appBar: AppBar(
      backgroundColor: const Color(0xFF09051B),
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title: const Text(
        'Create Account',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

body: Container(
  decoration: const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/auth_background_new.png'),
      fit: BoxFit.cover,
    ),
  ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 30),
          child: Column(
            children: [
              GestureDetector(
                onTap: loading ? null : showImageOptions,
                child: Container(
                  width: 138,
                  height: 138,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFFD76A),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF35D3)
                            .withOpacity(0.35),
                        blurRadius: 28,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF21103D),
                    backgroundImage: avatarImage,
                    child: avatarImage == null
                        ? const Icon(
                            Icons.person,
                            size: 72,
                            color: Color(0xFFCC8BFF),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Add Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 24),

              _registerField(
                controller: nameController,
                label: 'Name',
                hint: 'Enter your name',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 12),

              _registerField(
                controller: emailController,
                label: 'Email',
                hint: 'Enter your email',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              _registerDropdown(
                label: 'Country',
                icon: Icons.language,
                value: country,
                items: countries,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => country = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              _registerDropdown(
                label: 'Gender',
                icon: Icons.people_outline,
                value: gender,
                items: genders,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => gender = value);
                  }
                },
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: loading ? null : pickBirthday,
                borderRadius: BorderRadius.circular(16),
                child: _registerDisplayField(
                  label: 'Birthday',
                  value: birthday.isEmpty
                      ? 'Select your birthday'
                      : birthday,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(height: 12),

              _registerField(
                controller: passwordController,
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 58,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFF3EAA),
                        Color(0xFFB600FF),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: const Color(0xFFFFD76A),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF29CB)
                            .withOpacity(0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: loading ? null : register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'CREATE ACCOUNT  →',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: Colors.white70),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text(
                      'Login Now',
                      style: TextStyle(
                        color: Color(0xFFFFD76A),
                        fontWeight: FontWeight.bold,
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
  );
}
}

// ============================================================
// HOME
// ============================================================

class HomeScreen
    extends StatefulWidget {
  final String token;

  const HomeScreen({
    super.key,
    required this.token,
  });

  @override
  State<HomeScreen> createState() =>
      _HomeScreenState();
}

class _HomeScreenState
    extends State<HomeScreen> {
  int selectedIndex = 0;

final titles = const [
  'Voice Rooms',
  'Events',
  'Messages',
  'Profile',
];

  @override
  Widget build(
    BuildContext context,
  ) {
final pages = [
  RoomsScreen(
    token: widget.token,
  ),
  const EventsScreen(),
  MessagesScreen(),
  ProfileScreen(
    token: widget.token,
  ),
];

    return Scaffold(
      extendBodyBehindAppBar: selectedIndex == 3,
      appBar: AppBar(
        toolbarHeight: selectedIndex == 3 ? 48 : null,
        backgroundColor: selectedIndex == 3
            ? Colors.transparent
            : null,
        surfaceTintColor: selectedIndex == 3
            ? Colors.transparent
            : null,
        elevation: selectedIndex == 3 ? 0 : null,
        foregroundColor: selectedIndex == 3
            ? const Color(0xFFFFD54F)
            : null,
        title: Text(
          titles[selectedIndex],
          style: selectedIndex == 3
              ? const TextStyle(
                  color: Color(0xFFFFD54F),
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
        centerTitle: true,
      ),
      body: pages[selectedIndex],
bottomNavigationBar: NavigationBar(
  backgroundColor: Colors.transparent,
  surfaceTintColor: Colors.transparent,
  indicatorColor: const Color(0xFF8E24AA).withOpacity(0.35),
  elevation: 0,
  selectedIndex: selectedIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            selectedIndex =
                index;
          });
        },
destinations: const [
  NavigationDestination(
    icon: Icon(Icons.groups_outlined),
    selectedIcon: Icon(Icons.groups),
    label: 'Rooms',
  ),
  NavigationDestination(
    icon: Icon(Icons.event_outlined),
    selectedIcon: Icon(Icons.event),
    label: 'Events',
  ),
  NavigationDestination(
    icon: Icon(Icons.message_outlined),
    selectedIcon: Icon(Icons.message),
    label: 'Messages',
  ),
  NavigationDestination(
    icon: Icon(Icons.person_outline),
    selectedIcon: Icon(Icons.person),
    label: 'Profile',
  ),
],
      ),
    );
  }
}

// ============================================================
// ROOMS
// ============================================================


class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF180526),
            Color(0xFF39085A),
            Color(0xFF10051D),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event,
              size: 70,
              color: Color(0xFFFFD45C),
            ),
            SizedBox(height: 16),
            Text(
              'MINDO EVENTS',
              style: TextStyle(
                color: Color(0xFFFFD45C),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Events coming soon',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ROOMS

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF18052D),
            Color(0xFF390A55),
            Color(0xFF10021F),
          ],
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.forum_rounded,
              color: Color(0xFFFFD45C),
              size: 72,
            ),
            SizedBox(height: 16),
            Text(
              'MINDO MESSAGES',
              style: TextStyle(
                color: Color(0xFFFFD45C),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Your conversations will appear here',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomsScreen
    extends StatefulWidget {
  final String token;

  const RoomsScreen({
    super.key,
    required this.token,
  });

  @override
  State<RoomsScreen> createState() =>
      _RoomsScreenState();
}

class _RoomsScreenState
    extends State<RoomsScreen> {
  List<dynamic> rooms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    setState(() {
      loading = true;
    });

    try {
      final result =
          await api.getRooms(
        widget.token,
      );

      if (mounted) {
        setState(() {
          rooms = result;
        });
      }
    } catch (e) {
      if (mounted) {
        showMessage(
          e.toString().replaceFirst(
                'Exception: ',
                '',
              ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> createRoom() async {
    final controller =
        TextEditingController();

      XFile? selectedCover;
      
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Create Voice Room'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.deepPurple,
                    child: selectedCover == null
                        ? const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 38,
                          )
                        : ClipOval(
                            child: Image.file(
                              File(selectedCover!.path),
                              width: 76,
                              height: 76,
                              fit: BoxFit.cover,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final image =
                          await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );

                      if (image != null) {
                        setDialogState(() {
                          selectedCover = image;
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.photo_library_outlined,
                    ),
                    label: const Text('Choose Room Cover'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Room name',
                      hintText: 'Example: Friends Chat',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      controller.text.trim(),
                    );
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );


try {
  String? coverImageUrl;

  if (selectedCover != null) {
    coverImageUrl = await uploadRoomCoverToCloudinary(
      selectedCover!.path,
    );

    if (coverImageUrl == null) {
      throw Exception('Room cover upload failed');
    }
  }

  await api.createRoom(
    widget.token,
    name!,
    coverImageUrl: coverImageUrl,
  );

  await loadRooms();

      if (mounted) {
        showMessage(
          'Room created',
        );
      }
    } catch (e) {
      showMessage(
        e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
      );
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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body:
          RefreshIndicator(
        onRefresh: loadRooms,
        child: loading
            ? const Center(
                child:
                    CircularProgressIndicator(),
              )
            : rooms.isEmpty
                ? ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(
                        height: 100,
                      ),
                      Icon(
                        Icons.mic_none,
                        size: 80,
                        color:
                            Colors.grey,
                      ),
                      SizedBox(
                        height: 20,
                      ),
                      Center(
                        child: Text(
                          'No voice rooms yet',
                          style:
                              TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 8,
                      ),
                      Center(
                        child: Text(
                          'Create the first room',
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets
                            .all(16),
                    itemCount:
                        rooms.length,
                    itemBuilder:
                        (context, index) {
                      final room =
                          rooms[index];

                            final ownerUid =
    room['owner_public_uid']?.toString() ?? '';
                      final id =
                          
                          room['id']
                                  ?.toString() ??
                              '';

                      final name =
                          room['name']
                                  ?.toString() ??
                              'Voice Room';

                      return Card(
                        margin:
                            const EdgeInsets
                                .only(
                          bottom: 12,
                        ),
                        child:
                            ListTile(
                          contentPadding:
                              const EdgeInsets
                                  .all(
                            14,
                          ),
                          leading:
CircleAvatar(
  radius: 28,
  backgroundColor: Colors.deepPurple.shade100,
  backgroundImage:
      (room['cover_image_url'] != null &&
              room['cover_image_url'].toString().isNotEmpty)
          ? NetworkImage(room['cover_image_url'].toString())
          : null,
  child:
      (room['cover_image_url'] == null ||
              room['cover_image_url'].toString().isEmpty)
          ? const Icon(
              Icons.mic,
              color: Colors.deepPurple,
            )
          : null,
),
                          title: Text(
                            name,
                            style:
                                const TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                          subtitle:
                              const Text(
                            'Voice room',
                          ),
                          trailing:
                              const Icon(
                            Icons
                                .arrow_forward_ios,
                            size: 18,
                          ),
                          onTap: () async {
                              final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('token') ?? '';
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        VoiceRoomScreen(
                                            token: token,
                                  roomId:
                                      id,
                                            ownerPublicUid: ownerUid,
                                  roomName:
                                      name,
coverImageUrl: room['cover_image_url']?.toString(),
                                            seatCount:
    int.tryParse(
          room['seat_count']?.toString() ?? '',
        ) ??
        10,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton:
          FloatingActionButton(
        onPressed:
            createRoom,
        child:
            const Icon(Icons.add),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }
}

// ============================================================
// CREATE ROOM FLOATING BUTTON
// ============================================================

class RoomsScreenWithButton
    extends StatelessWidget {
  final String token;

  const RoomsScreenWithButton({
    super.key,
    required this.token,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return RoomsScreen(
      token: token,
    );
  }
}

// ============================================================
// FRIENDS
// ============================================================

class FriendsScreen
    extends StatelessWidget {
  const FriendsScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding:
          const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading:
                const CircleAvatar(
              child:
                  Icon(Icons.person),
            ),
            title:
                const Text('Friends'),
            subtitle:
                const Text(
              'Friends system will be connected here.',
            ),
            trailing:
                IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.search,
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 15,
        ),
        const Center(
          child: Text(
            'No friends yet',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================
// MINDO WALLET — balance, recharge packages, history shortcuts
// ============================================================
class MindoWalletScreen extends StatefulWidget {
  final String token;
  const MindoWalletScreen({super.key, required this.token});

  @override
  State<MindoWalletScreen> createState() => _MindoWalletScreenState();
}

class _MindoWalletScreenState extends State<MindoWalletScreen> {
  static const gold = Color(0xFFFFD66B);
  static const dark = Color(0xFF080A18);
  bool loading = true;
  String? error;
  String balance = '—';
  int selectedPackage = 0;

  // Visual sample values only. Real prices/coin amounts must come from the
  // backend/Admin Dashboard before secure recharge can be enabled.
  static const List<Map<String, String>> _samplePackages = [
    {'name': 'Package 1', 'coins': '500 M Coins', 'bonus': '+ 50 Bonus Coins', 'price': '\$0.99'},
    {'name': 'Package 2', 'coins': '1,200 M Coins', 'bonus': '+ 120 Bonus Coins', 'price': '\$1.99'},
    {'name': 'Package 3', 'coins': '2,500 M Coins', 'bonus': '+ 300 Bonus Coins', 'price': '\$3.99'},
    {'name': 'Package 4', 'coins': '5,000 M Coins', 'bonus': '+ 700 Bonus Coins', 'price': '\$7.99'},
    {'name': 'Package 5', 'coins': '10,000 M Coins', 'bonus': '+ 1,500 Bonus Coins', 'price': '\$14.99'},
  ];

  @override
  void initState() {
    super.initState();
    refreshBalance();
  }

  Future<void> refreshBalance() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await api.me(widget.token);
      final user = response['user'];
      if (user is! Map) throw Exception('Wallet account data missing');
      if (!mounted) return;
      setState(() { balance = user['coins']?.toString() ?? '0'; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  void _notReady(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('$feature will be enabled after secure backend/payment setup.'),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dark,
      appBar: AppBar(
        backgroundColor: const Color(0xFF101329),
        foregroundColor: gold,
        title: const Text('MINDO Wallet', style: TextStyle(fontWeight: FontWeight.w900, color: gold, fontSize: 23)),
        centerTitle: true,
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/Futuristic Gold Carbon Fiber Frame.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const ColoredBox(color: dark),
          ),
          Container(color: const Color(0xE6080A18)),
          RefreshIndicator(
            color: gold,
            backgroundColor: const Color(0xFF151027),
            onRefresh: refreshBalance,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xE9161027), Color(0xE6080A18), Color(0xE9221035)]),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: gold, width: 1.6),
                    boxShadow: const [BoxShadow(color: Color(0x66FFB52E), blurRadius: 18, spreadRadius: 1)],
                  ),
                  child: Column(children: [
                    _mCoinLogo(size: 116),
                    const SizedBox(height: 10),
                    const Text('My Coin Balance', style: TextStyle(color: Color(0xFFFFE7A0), fontSize: 19, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    if (loading)
                      const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: gold))
                    else
                      Text(balance, style: const TextStyle(color: gold, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    if (error != null)
                      Padding(padding: const EdgeInsets.only(top: 5), child: Text(error!, textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.orangeAccent, fontSize: 12))),
                    const SizedBox(height: 5),
                    OutlinedButton.icon(
                      onPressed: refreshBalance,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: const Text('Refresh Balance'),
                      style: OutlinedButton.styleFrom(foregroundColor: gold, side: const BorderSide(color: gold),
                        shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _walletAction(Icons.history_rounded, 'Coin History', () => _openWalletInfo('Coin History'))),
                  const SizedBox(width: 12),
                  Expanded(child: _walletAction(Icons.diamond_rounded, 'Diamonds', () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiamondWalletScreen(token: widget.token))))),
                ]),
                const SizedBox(height: 23),
                const Text('Recharge Coins', style: TextStyle(color: gold, fontSize: 25, fontWeight: FontWeight.w900)),
                const SizedBox(height: 13),
                for (var i = 0; i < _samplePackages.length; i++)
                  _packageCard(i),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _notReady('Secure recharge/payment'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('RECHARGE NOW', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: .5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gold, foregroundColor: const Color(0xFF211328),
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    elevation: 8, shadowColor: const Color(0x99FFB52E),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Colors.white70, width: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


Widget _mCoinLogo({required double size}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const RadialGradient(
        colors: [
          Color(0xFFFFF1A8),
          Color(0xFFFFC83D),
          Color(0xFF9A4D08),
        ],
      ),
      border: Border.all(
        color: const Color(0xFFFFF5A5),
        width: 1.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99FFB52E),
          blurRadius: 18,
          spreadRadius: 2,
        ),
      ],
    ),
    child: Container(
      margin: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF6B2C2),
            Color(0xFFFF90C3),
            Color(0xFF7FA2B0),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFF6D6),
          width: 2,
        ),
      ),
      child: Center(
        child: FittedBox(
          child: Text(
            'M',
            style: TextStyle(
              color: const Color(0xFFFFD700),
              fontSize: size * 0.55,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  );
}
    

  Widget _packageCard(int index) {
    final p = _samplePackages[index];
    final selected = selectedPackage == index;
    return GestureDetector(
      onTap: () => setState(() => selectedPackage = index),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xF51B112B), Color(0xF5101020), Color(0xF52A123B)]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? gold : const Color(0xFF8D6A32), width: selected ? 2 : 1),
          boxShadow: selected ? const [BoxShadow(color: Color(0x55FFB52E), blurRadius: 12)] : null,
        ),
        child: Row(children: [
          _mCoinLogo(size: 48),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 2),
            Text(p['coins']!, style: const TextStyle(color: gold, fontWeight: FontWeight.w900, fontSize: 16)),
            Text(p['bonus']!, style: const TextStyle(color: Color(0xFFBD80FF), fontWeight: FontWeight.w600, fontSize: 12)),
          ])),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(p['price']!, style: const TextStyle(color: gold, fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            SizedBox(height: 34, child: ElevatedButton(
              onPressed: () { setState(() => selectedPackage = index); _notReady('Payment for ${p['name']}'); },
              style: ElevatedButton.styleFrom(backgroundColor: gold, foregroundColor: const Color(0xFF211328), padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: const Text('Recharge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
            )),
          ]),
        ]),
      ),
    );
  }

  Widget _walletAction(IconData icon, String title, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: gold),
      label: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        backgroundColor: const Color(0xCC100B20),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 6),
        side: const BorderSide(color: gold, width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _openWalletInfo(String title) {
    if (title == 'Diamond Wallet') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DiamondWalletScreen(token: widget.token)));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CoinHistoryScreen(token: widget.token)),
    );
  }
}

class CoinHistoryScreen extends StatefulWidget {
  final String token;
  const CoinHistoryScreen({super.key, required this.token});

  @override
  State<CoinHistoryScreen> createState() => _CoinHistoryScreenState();
}

class _CoinHistoryScreenState extends State<CoinHistoryScreen> {
  static const gold = Color(0xFFFFD66B);
  static const dark = Color(0xFF080A18);
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() { super.initState(); load(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.getCoinHistory(widget.token);
      if (!mounted) return;
      setState(() { transactions = data['transactions'] as List? ?? data['history'] as List? ?? []; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { loading = false; });
    }
  }

  String _date(dynamic raw) {
    final parsed = DateTime.tryParse('$raw')?.toLocal();
    if (parsed == null) return raw == null ? 'Date unavailable' : '$raw';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)}  ${two(parsed.hour)}:${two(parsed.minute)}:${two(parsed.second)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: dark,
      appBar: AppBar(
        title: const Text('Coin History'),
        backgroundColor: const Color(0xFF101329),
        foregroundColor: gold,
        actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(20), child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent))))
              : transactions.isEmpty
                  ? const Center(child: Text('No coin transactions yet', style: TextStyle(color: Colors.white70)))
                  : RefreshIndicator(
                      color: gold,
                      onRefresh: load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final t = Map<String, dynamic>.from(transactions[index] as Map);
                          final delta = int.tryParse('${t['coins_delta'] ?? t['amount'] ?? t['coins'] ?? 0}') ?? 0;
                          final type = '${t['type'] ?? t['transaction_type'] ?? t['description'] ?? 'Coin transaction'}';
                          final status = '${t['status'] ?? 'success'}';
                          final time = t['created_at'] ?? t['timestamp'] ?? t['createdAt'];
                          return Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(color: const Color(0xFF171225), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF8D6A32))),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                const Icon(Icons.monetization_on_rounded, color: gold, size: 28),
                                const SizedBox(width: 9),
                                Expanded(child: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
                                Text(delta >= 0 ? '+$delta' : '$delta', style: TextStyle(color: delta >= 0 ? Colors.greenAccent : Colors.redAccent, fontWeight: FontWeight.w900)),
                              ]),
                              const SizedBox(height: 8),
                              Text(_date(time), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 5),
                              Text('Status: ${status.toUpperCase()}', style: TextStyle(color: status.toLowerCase() == 'success' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                              if (t['id'] != null) Text('Transaction ID: ${t['id']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                              if (t['balance_after'] != null || t['coins_balance_after'] != null)
                                Text('Balance after: ${t['balance_after'] ?? t['coins_balance_after']} M Coins', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                            ]),
                          );
                        },
                      ),
                    ),
    );
  }
}


class DiamondWalletScreen extends StatefulWidget {
  final String token;
  const DiamondWalletScreen({super.key, required this.token});
  @override
  State<DiamondWalletScreen> createState() => _DiamondWalletScreenState();
}

class _DiamondWalletScreenState extends State<DiamondWalletScreen> {
  static const gold = Color(0xFFFFD66B);
  static const dark = Color(0xFF080A18);
  final controller = TextEditingController(text: '1000');
  Map<String, dynamic> config = {};
  int diamonds = 0;
  int coins = 0;
  bool loading = true;
  bool exchanging = false;
  String? error;
  int get amount => int.tryParse(controller.text.trim()) ?? 0;
  int get estimatedCoins {
    final perD = int.tryParse('${config['diamonds_per_exchange'] ?? 1000}') ?? 1000;
    final perC = int.tryParse('${config['coins_per_exchange'] ?? 800}') ?? 800;
    return perD > 0 && amount > 0 && amount % perD == 0 ? (amount ~/ perD) * perC : 0;
  }

  @override void initState() { super.initState(); load(); }
  @override void dispose() { controller.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await api.getDiamondExchange(widget.token);
      final b = data['balance'] as Map? ?? {};
      if (!mounted) return;
      setState(() { config = Map<String, dynamic>.from(data['config'] as Map? ?? {}); diamonds = int.tryParse('${b['diamonds'] ?? 0}') ?? 0; coins = int.tryParse('${b['coins'] ?? 0}') ?? 0; });
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); }); }
    finally { if (mounted) setState(() { loading = false; }); }
  }

  Future<void> exchange() async {
    if (amount <= 0 || estimatedCoins <= 0) { setState(() { error = 'Enter a valid amount in the configured exchange multiple.'; }); return; }
    final min = int.tryParse('${config['min_diamonds'] ?? 1}') ?? 1;
    final max = int.tryParse('${config['max_diamonds'] ?? 100000}') ?? 100000;
    if (amount < min || amount > max) { setState(() { error = 'Amount must be between $min and $max diamonds.'; }); return; }
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: const Color(0xFF171225), title: const Text('Confirm Exchange', style: TextStyle(color: gold)), content: Text('Exchange $amount diamonds for $estimatedCoins M Coins?', style: const TextStyle(color: Colors.white70)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Exchange'))]));
    if (confirm != true) return;
    setState(() { exchanging = true; error = null; });
    try {
      final result = await api.exchangeDiamonds(widget.token, amount);
      await load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Success! ${result['diamonds_exchanged']} diamonds exchanged for ${result['coins_received']} M Coins.')));
    } catch (e) { if (mounted) setState(() { error = e.toString().replaceFirst('Exception: ', ''); }); }
    finally { if (mounted) setState(() { exchanging = false; }); }
  }

  @override Widget build(BuildContext context) {
    final enabled = config['enabled'] == true;
    return Scaffold(backgroundColor: dark, appBar: AppBar(title: const Text('Diamond Exchange', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: const Color(0xFF101329), foregroundColor: gold, actions: [IconButton(tooltip: 'Diamond History', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DiamondHistoryScreen(token: widget.token))), icon: const Icon(Icons.history_rounded))]),
      body: Stack(fit: StackFit.expand, children: [Image.asset('assets/Futuristic Gold Carbon Fiber Frame.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const ColoredBox(color: dark)), Container(color: const Color(0xE6080A18)), RefreshIndicator(color: gold, onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xE9221035), Color(0xE6080A18)]), borderRadius: BorderRadius.circular(24), border: Border.all(color: gold)), child: Column(children: [const Icon(Icons.diamond_rounded, size: 76, color: Color(0xFFB58CFF), shadows: [Shadow(color: Color(0xFF8A2BE2), blurRadius: 22)]), const SizedBox(height: 8), const Text('MY DIAMONDS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), Text(loading ? '...' : '$diamonds', style: const TextStyle(color: Color(0xFFD9B7FF), fontSize: 34, fontWeight: FontWeight.w900)), const SizedBox(height: 12), const Divider(color: Colors.white24), Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 34, height: 34, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [Color(0xFFFFF1A8), Color(0xFFFFC83D), Color(0xFF9A4D08)])), child: const Center(child: Text('M', style: TextStyle(color: Color(0xFF371B08), fontWeight: FontWeight.w900, fontSize: 21)))), const SizedBox(width: 9), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('MY M COINS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)), Text('$coins', style: const TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w900))])])])),
        const SizedBox(height: 20), const Text('EXCHANGE DIAMONDS', style: TextStyle(color: gold, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xE9151027), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF8D6A32))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Diamonds to exchange', style: TextStyle(color: Colors.white70)), const SizedBox(height: 8), TextField(controller: controller, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {}), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), decoration: InputDecoration(prefixIcon: const Icon(Icons.diamond_rounded, color: Color(0xFFD9B7FF)), filled: true, fillColor: const Color(0xFF080A18), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), hintText: 'Enter diamonds', hintStyle: const TextStyle(color: Colors.white38))), const SizedBox(height: 12), Text('Rate: ${config['diamonds_per_exchange'] ?? 1000} Diamonds = ${config['coins_per_exchange'] ?? 800} M Coins', style: const TextStyle(color: gold, fontWeight: FontWeight.bold)), const SizedBox(height: 12), Row(children: [const Expanded(child: Text('You will receive', style: TextStyle(color: Colors.white70))), const Icon(Icons.arrow_forward_rounded, color: gold), const SizedBox(width: 8), const Text('M', style: TextStyle(color: gold, fontSize: 22, fontWeight: FontWeight.w900)), const SizedBox(width: 6), Text('$estimatedCoins', style: const TextStyle(color: gold, fontSize: 24, fontWeight: FontWeight.w900))]), if (error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(error!, style: const TextStyle(color: Colors.redAccent))), ])),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: loading || exchanging || !enabled ? null : exchange,
            icon: exchanging
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(!enabled ? 'EXCHANGE DISABLED' : exchanging ? 'PROCESSING...' : 'CONFIRM EXCHANGE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: const Color(0xFF211328),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ]))]));
  }
}


class DiamondHistoryScreen extends StatefulWidget {
  final String token;

  const DiamondHistoryScreen({
    super.key,
    required this.token,
  });

  @override
  State<DiamondHistoryScreen> createState() =>
      _DiamondHistoryScreenState();
}

class _DiamondHistoryScreenState
    extends State<DiamondHistoryScreen> {
  static const gold = Color(0xFFFFD66B);

  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final data = await api.getDiamondHistory(widget.token);

      if (!mounted) return;

      setState(() {
        transactions = data['transactions'] as List? ?? [];
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  String fmt(dynamic raw) {
    final d = DateTime.tryParse('$raw')?.toLocal();
    if (d == null) return '$raw';

    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    final ss = d.second.toString().padLeft(2, '0');

    return '${d.year}-$mm-$dd  $hh:$min:$ss';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A18),
      appBar: AppBar(
        title: const Text('Diamond History'),
        backgroundColor: const Color(0xFF101329),
        foregroundColor: gold,
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: gold),
            )
          : error != null
              ? Center(
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                )
              : transactions.isEmpty
                  ? const Center(
                      child: Text(
                        'No diamond transactions yet',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : RefreshIndicator(
                      color: gold,
                      onRefresh: load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(14),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final t = Map<String, dynamic>.from(
                            transactions[i] as Map,
                          );

                          final deltaD = int.tryParse(
                                '${t['diamonds_delta'] ?? 0}',
                              ) ??
                              0;

                          final deltaC = int.tryParse(
                                '${t['coins_delta'] ?? 0}',
                              ) ??
                              0;

                          final status = '${t['status'] ?? 'success'}';

                          return Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: const Color(0xFF171225),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF8D6A32),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.diamond_rounded,
                                      color: Color(0xFFD9B7FF),
                                      size: 28,
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Diamond Exchange',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      status.toUpperCase(),
                                      style: TextStyle(
                                        color: status.toLowerCase() == 'success'
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  fmt(t['created_at']),
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Diamonds exchanged',
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      deltaD < 0 ? '${-deltaD}' : '$deltaD',
                                      style: const TextStyle(
                                        color: Color(0xFFD9B7FF),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'M Coins received',
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      deltaC > 0 ? '+$deltaC' : '$deltaC',
                                      style: const TextStyle(
                                        color: gold,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Transaction ID: ${t['id']}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 10,
                                  ),
                                ),
                                Text(
                                  'Balances after: '
                                  '${t['diamonds_balance_after']} diamonds · '
                                  '${t['coins_balance_after']} M Coins',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}



// ============================================================
// PERSONAL PROFILE
// ============================================================

class ProfileScreen extends StatefulWidget {
  final String token;

  const ProfileScreen({
    super.key,
    required this.token,
  });

  @override
  State<ProfileScreen> createState() =>
      _ProfileScreenState();
}

class _ProfileScreenState
    extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  bool loading = true;
    
    double _cosWheel(double radians) => math.cos(radians);
double _sinWheel(double radians) => math.sin(radians);

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final result =
          await api.me(widget.token);

      if (!mounted) return;

      setState(() {
        user = Map<String, dynamic>.from(
          result['user'] ?? {},
        );
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
              'Exception: ',
              '',
            ),
          ),
        ),
      );
    } finally {
      if (!mounted) return;

      setState(() {
        loading = false;
      });
    }
  }

  Future<void> openEditProfile() async {
    if (user == null) return;

    final updatedUser =
        await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          token: widget.token,
          user: user!,
        ),
      ),
    );

    if (!mounted) return;

    if (updatedUser != null) {
      setState(() {
        user = updatedUser;
      });
    } else {
      await loadProfile();
    }
  }

  Future<void> confirmLogout() async {
    final shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Logout',
          ),
          content: const Text(
            'Are you sure you want to logout?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child: const Text(
                'Confirm',
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove('token');

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void openComingSoon(
    String title,
  ) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be connected next.',
        ),
      ),
    );
  }

  Widget profileAction(
    IconData icon,
    String title, {
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Colors.deepPurple.shade50,
          child: Icon(
            icon,
            color: Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right,
        ),
        onTap: onTap ??
            () => openComingSoon(title),
      ),
    );
  }

  Widget statItem(
    String value,
    String label, {
    String? iconUrl,
  }) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (iconUrl != null && iconUrl.isNotEmpty)
                ClipOval(child: Image.network(iconUrl, width: 19, height: 19, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, color: Color(0xFFFFD34D), size: 18)))
              else
                const Icon(Icons.workspace_premium, color: Color(0xFFFFD34D), size: 18),
              const SizedBox(width: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFD34D),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  String countryFlag(String country) {
    const flags = {
      'Pakistan': '🇵🇰',
      'India': '🇮🇳',
      'United Arab Emirates': '🇦🇪',
      'United Kingdom': '🇬🇧',
      'Saudi Arabia': '🇸🇦',
      'Bangladesh': '🇧🇩',
      'Nepal': '🇳🇵',
      'Qatar': '🇶🇦',
      'Kuwait': '🇰🇼',
      'Oman': '🇴🇲',
      'Bahrain': '🇧🇭',
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'Australia': '🇦🇺',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Turkey': '🇹🇷',
    };

    return flags[country] ?? '🌍';
  }
  @override
  Widget build(
    BuildContext context,
  ) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final displayName =
        user?['display_name']
                ?.toString()
                .trim() ??
            '';

    final username =
        user?['username']
                ?.toString() ??
            'User';

    final name =
        displayName.isNotEmpty
            ? displayName
            : username;

    final uid =
        user?['public_uid']
                ?.toString() ??
            '';

    final avatarUrl =
        user?['avatar_url']
                ?.toString() ??
            '';

    final signature =
        user?['signature']
                ?.toString()
                .trim() ??
            '';

    final country =
        user?['country']
                ?.toString()
                .trim() ??
            '';

    final flag =
        country.isNotEmpty
            ? countryFlag(country)
            : '';
final gender =
    user?['gender']?.toString().trim() ?? '';
      
return RefreshIndicator(
  onRefresh: loadProfile,
  child: Container(
    decoration: const BoxDecoration(
      image: DecorationImage(
        image: AssetImage(
          'assets/Royal Blue and Gold Fantasy Stage.png',
        ),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
      ),
    ),
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        10,
        62,
        10,
        2,
      ),
      children: [
          // ======================================================
          // TOP PROFILE
          // ======================================================

          Center(
            child: GestureDetector(
              onTap: openEditProfile,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 58,
                    backgroundImage:
                        avatarUrl.isNotEmpty
                            ? NetworkImage(
                                avatarUrl,
                              )
                            : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(
                            Icons.person,
                            size: 58,
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding:
                          const EdgeInsets.all(
                        8,
                      ),
                      decoration:
                          const BoxDecoration(
                        color:
                            Colors.deepPurple,
                        shape:
                            BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 6,
          ),

Center(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedRainbowText(
              text: name,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),

if (gender.isNotEmpty) ...[
  const SizedBox(width: 5),
Container(
  width: 26,
  height: 26,
  decoration: BoxDecoration(
    color: gender.toLowerCase() == 'male'
        ? Colors.blue
        : Colors.pink,
    borderRadius: BorderRadius.circular(5),
  ),
  alignment: Alignment.center,
  child: Text(
    gender.toLowerCase() == 'male' ? '🚹' : '🚺',
    style: const TextStyle(
      fontSize: 19,
    ),
  ),
),

],

          ],
        ),
      ),
    ],
  ),
),

const SizedBox(height: 2),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
if (flag.isNotEmpty) ...[
  Text(
    flag,
    style: const TextStyle(fontSize: 20),
  ),
  const SizedBox(width: 6),
],
                const Text(
                  'UID: ',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
AnimatedRainbowText(
  text: uid.isEmpty ? '-------' : uid,
  fontSize: 15,
  fontWeight: FontWeight.bold,
),
                if (uid.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () async {
                      await Clipboard.setData(
                        ClipboardData(text: uid),
                      );
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('UID copied'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.copy_outlined,
                        size: 18,
                        color: Colors.deepPurple,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (signature.isNotEmpty) ...[
            const SizedBox(
              height: 5,
            ),
            Center(
              child: Text(
                signature,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),
          ],

          const SizedBox(
            height: 6,
          ),

          // ======================================================
          // WEALTH / CHARM / VIP
          // ======================================================

Card(
  color: const Color(0xB30A1B3D),
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(
      color: const Color(0xFFFFD36A).withOpacity(0.45),
      width: 1,
    ),
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 6,
      horizontal: 8,
    ),
    child: Row(
      children: [
        statItem('Lv.${user?['wealth_level'] ?? user?['level'] ?? 1}', 'Wealth Level', iconUrl: user?['wealth_level_icon_url']?.toString()),
        Container(
          width: 1,
          height: 35,
          color: Colors.white24,
        ),
        statItem('Lv.${user?['charm_level'] ?? 1}', 'Charm Level', iconUrl: user?['charm_level_icon_url']?.toString()),
        Container(
          width: 1,
          height: 35,
          color: Colors.white24,
        ),
        statItem('VIP 0', 'VIP'),
      ],
    ),
  ),
),

          const SizedBox(
            height: 4,
          ),
            
 // ======================================================
// SOCIAL STATS
// ======================================================

Card(
  color: const Color(0xB30A1B3D),
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide(
      color: const Color(0xFFFFD36A).withOpacity(0.45),
      width: 1,
    ),
  ),
  child: Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 6,
      horizontal: 4,
    ),
    child: Row(
      children: [
        // Following
        Expanded(
          child: InkWell(
            onTap: () {
              openComingSoon('Following');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              child: Column(
                children: [
                  const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD34D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Following',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Fans
        Expanded(
          child: InkWell(
            onTap: () {
              openComingSoon('Fans');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              child: Column(
                children: [
                  const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD34D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fans',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Gift Received - COINS ONLY
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            child: Column(
              children: [
                const Text(
                  '0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD34D),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Gift Received',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Gift Sent - COINS ONLY
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            child: Column(
              children: [
                const Text(
                  '0',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFFD34D),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Gift Sent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ),

        // Visits
        Expanded(
          child: InkWell(
            onTap: () {
              openComingSoon('Visits');
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 2,
              ),
              child: Column(
                children: [
                  const Text(
                    '0',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFFFD34D),
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Visits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),

          // ======================================================
          // PROFILE FEATURES
          // ======================================================


LayoutBuilder(
  builder: (context, constraints) {
    final wheelWidth = constraints.maxWidth;
    final wheelHeight = 290.0;

    final buttonSize =
        (wheelWidth * 0.145).clamp(46.0, 54.0);
    final centerSize =
        (wheelWidth * 0.16).clamp(52.0, 60.0);

    final centerX = (wheelWidth - centerSize) / 2;
    final centerY = (wheelHeight - centerSize) / 2;

    // Circular wheel: 8 buttons around the VIP center.
    final radiusX = wheelWidth * 0.30;
    final radiusY = wheelHeight * 0.36;

    Widget wheelButton(
      IconData icon,
      String title,
      double angle,
    ) {
      final radians = angle * 3.141592653589793 / 180;

      final left = (wheelWidth / 2) +
          radiusX * _cosWheel(radians) -
          buttonSize / 2;

      final top = (wheelHeight / 2) +
          radiusY * _sinWheel(radians) -
          buttonSize / 2;

      return Positioned(
        left: left,
        top: top,
        width: buttonSize,
        height: buttonSize,
        child: GestureDetector(
          onTap: () {
            if (title == 'Wallet') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MindoWalletScreen(token: widget.token),
              ));
            } else if (title == 'Mall') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MindoMallScreen(token: widget.token),
              ));
            } else if (title == 'HONOR') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const MindoHonorScreen(),
              ));
            } else if (title == 'Wealth Level') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => MindoWealthLevelScreen(token: widget.token),
              ));
            } else if (title == 'My Agency') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const AgencyDirectoryScreen(),
              ));
            } else if (title == 'My Income') {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => const HostMyIncomeScreen(),
              ));
            } else {
              openComingSoon(title);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1D4E89),
                  Color(0xFF102A56),
                  Color(0xFF08152E),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFFFD36A),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66FFD36A),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Color(0x660080FF),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFFFFD66B),
                  size: buttonSize * 0.34,
                ),
                const SizedBox(height: 2),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      title,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: wheelHeight,
      width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Center(
              child: Container(
                width: wheelWidth * 0.82,
                height: wheelWidth * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFB52E)
                        .withOpacity(0.65),
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x556690FF),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Top, upper-right, lower-right, bottom,
          // lower-left, upper-left and the two side positions.
          wheelButton(
            Icons.account_balance_wallet,
            'Wallet',
            -90,
          ),
          wheelButton(Icons.shopping_bag, 'Mall', -45),
          wheelButton(Icons.star, 'Wealth Level', 0),
          wheelButton(Icons.military_tech, 'HONOR', 45),
          wheelButton(Icons.business, 'My Agency', 90),
          wheelButton(Icons.attach_money, 'My Income', 135),
          wheelButton(Icons.feedback, 'Feedback', 180),
          wheelButton(Icons.settings, 'Settings', 225),

          // VIP stays exactly at the wheel center.
          Positioned(
            left: centerX,
            top: centerY,
            width: centerSize,
            height: centerSize,
            child: GestureDetector(
              onTap: () => openComingSoon('VIP'),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [
                      Color(0xFFFFD12A),
                      Color(0xFFFF2106),
                      Color(0xFFB0314B),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFFFD36A),
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFFFF8A00),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Color(0xFFB000FF),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.workspace_premium,
                      color: const Color(0xFFFFD36A),
                      size: centerSize * 0.34,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'VIP',
                      style: TextStyle(
                        color: const Color(0xFFFFD36A),
                        fontSize: centerSize * 0.17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  },
),

const SizedBox(height: 16),

          // ======================================================
          // LOGOUT
          // ======================================================

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: confirmLogout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7B2CBF),
                foregroundColor: Colors.white,
                elevation: 5,
                side: const BorderSide(
                  color: Color(0xFFFFD36A),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
                  ],
      ),
    ),
  );
}
}


// ============================================================
// MINDO MALL — PROPS SHOP + MY PROPS
// UI and confirmation flow are ready. Live purchases, inventory
// and transfers will be connected to the backend after restore.
// ============================================================


// ============================================================
// WEALTH / CHARM LEVEL CENTER
// ============================================================

class MindoWealthLevelScreen extends StatefulWidget {
  final String token;
  const MindoWealthLevelScreen({super.key, required this.token});

  @override
  State<MindoWealthLevelScreen> createState() => _MindoWealthLevelScreenState();
}

class _MindoWealthLevelScreenState extends State<MindoWealthLevelScreen> {
  int _tab = 0;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _progress = {};
  List<dynamic> _config = [];

  static const Color _purple = Color(0xFF9B35E8);
  static const Color _pink = Color(0xFFE66BFF);
  static const Color _gold = Color(0xFFFFD27A);
  static const Color _background = Color(0xFF100319);

  static const List<Map<String, dynamic>> _tiers = [
    {'label': '1–9', 'level': 1, 'color': Color(0xFF19C6C8)},
    {'label': '10–19', 'level': 10, 'color': Color(0xFFFFC928)},
    {'label': '20–29', 'level': 20, 'color': Color(0xFFFFA31A)},
    {'label': '30–39', 'level': 30, 'color': Color(0xFF159DFF)},
    {'label': '40–49', 'level': 40, 'color': Color(0xFF2875E8)},
    {'label': '50–59', 'level': 50, 'color': Color(0xFFFF654B)},
    {'label': '60–69', 'level': 60, 'color': Color(0xFFE83C55)},
    {'label': '70–79', 'level': 70, 'color': Color(0xFFD93664)},
    {'label': '80–89', 'level': 80, 'color': Color(0xFFFF477D)},
    {'label': '90–99', 'level': 90, 'color': Color(0xFF56D7E8)},
    {'label': '100–110', 'level': 100, 'color': Color(0xFFFFC33B)},
  ];

  @override
  void initState() {
    super.initState();
    _loadLevels();
  }

  Future<void> _loadLevels() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        api.getLevelProgress(widget.token),
        api.getLevelConfig(widget.token),
      ]);
      if (!mounted) return;
      setState(() {
        _progress = Map<String, dynamic>.from(results[0]['levels'] ?? {});
        _config = List<dynamic>.from(results[1]['levels'] ?? []);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Level information is temporarily unavailable. It will load when the server is online.';
      });
    }
  }

  Map<String, dynamic> get _current {
    final key = _tab == 0 ? 'wealth' : 'charm';
    final raw = _progress[key];
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String get _type => _tab == 0 ? 'wealth' : 'charm';
  String get _title => _tab == 0 ? 'Wealth Level' : 'Charm Level';
  int _number(dynamic value, [int fallback = 0]) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
  String _format(dynamic value) {
    final number = _number(value);
    return number.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }

  @override
  Widget build(BuildContext context) {
    final level = _number(_current['level'], 1).clamp(1, 110).toInt();
    final value = _number(_current['value']);
    final nextLevel = _current['next_level'] == null ? null : _number(_current['next_level']);
    final remaining = _current['remaining'] == null ? null : _number(_current['remaining']);
    final progress = (_current['progress'] is num ? (_current['progress'] as num).toDouble() : 0.0).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: const Color(0xFF16051F),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: _pink), onPressed: () => Navigator.pop(context)),
        title: Text(_title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        actions: [IconButton(onPressed: _loadLevels, icon: const Icon(Icons.refresh, color: Colors.white70))],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF170022), Color(0xFF09010F), Color(0xFF21002D)]),
        ),
        child: Column(children: [
          Row(children: [
            _tabButton('Wealth Level', 0),
            _tabButton('Charm Level', 1),
          ]),
          Expanded(
            child: RefreshIndicator(
              color: _pink,
              onRefresh: _loadLevels,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 26), children: [
                _progressCard(level, value, nextLevel, remaining, progress),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12), textAlign: TextAlign.center),
                ],
                const SizedBox(height: 18),
                _descriptionCard(),
                const SizedBox(height: 18),
                _tierTable(level),
                if (_loading) const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator(color: _pink))),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final selected = _tab == index;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _tab = index),
      child: Container(height: 58, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? _pink : Colors.transparent, width: 2.5))),
        child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white54, fontSize: 16, fontWeight: selected ? FontWeight.w700 : FontWeight.w400)),
      ),
    ));
  }

  Widget _progressCard(int level, int value, int? nextLevel, int? remaining, double progress) {
    final iconUrl = _current['icon_url']?.toString();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7900B9), Color(0xFF310052), Color(0xFF160020)]),
        border: Border.all(color: const Color(0xFFB54AFF).withOpacity(.65)),
        boxShadow: [BoxShadow(color: _purple.withOpacity(.22), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFFE8C2), border: Border.all(color: _gold, width: 2)), child: const Center(child: Text('😺', style: TextStyle(fontSize: 42)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('LV.$level', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(width: 9), _levelPill(level, iconUrl)],),
            const SizedBox(height: 7),
            Text('${_tab == 0 ? 'Wealth' : 'Charm'} Value: ${_format(value)}', style: const TextStyle(color: Color(0xFFE8B7FF), fontSize: 16, fontWeight: FontWeight.w500)),
          ])),
        ]),
        const SizedBox(height: 26),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('LV.$level', style: const TextStyle(color: Color(0xFFE9C5FF), fontSize: 14)),
          Text(nextLevel == null ? 'MAX / CONFIG PENDING' : 'LV.$nextLevel', style: const TextStyle(color: Color(0xFFE9C5FF), fontSize: 14)),
        ]),
        const SizedBox(height: 9),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 11, backgroundColor: Colors.white, valueColor: const AlwaysStoppedAnimation<Color>(_pink))),
        const SizedBox(height: 11),
        Center(child: Text(remaining == null ? 'Next level threshold will be set by Admin' : '${_format(remaining)} coins required for upgrade', style: const TextStyle(color: Color(0xFFE8B7FF), fontSize: 14), textAlign: TextAlign.center)),
      ]),
    );
  }

  Widget _levelPill(int level, String? iconUrl) {
    final tier = _tiers.lastWhere((t) => level >= (t['level'] as int), orElse: () => _tiers.first);
    final color = tier['color'] as Color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [color.withOpacity(.95), color.withOpacity(.55)]), border: Border.all(color: Colors.white70, width: .8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (iconUrl != null && iconUrl.isNotEmpty) ClipOval(child: Image.network(iconUrl, width: 23, height: 23, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, color: Colors.white, size: 21)))
        else const Icon(Icons.workspace_premium, color: Colors.white, size: 21),
        const SizedBox(width: 5), Text('$level', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _descriptionCard() {
    final description = _tab == 0
      ? 'Wealth Level grows when you send gold-coin gifts. Every eligible coin spent on gifts adds to your Wealth Value. Your level badge updates automatically, and higher levels can unlock more dazzling room-entry effects.'
      : 'Charm Level grows when you receive gold-coin gifts. Every eligible coin received adds to your Charm Value. Your level badge updates automatically as your received-gift total increases.';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: const Color(0xFF21002E).withOpacity(.94), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFF7B25B4).withOpacity(.7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.workspace_premium, color: _pink, size: 22), const SizedBox(width: 7), Text('$_title Description', style: const TextStyle(color: Color(0xFFE5A5FF), fontSize: 18, fontWeight: FontWeight.w600))]),
        const SizedBox(height: 12),
        Text(description, style: const TextStyle(color: Color(0xFFE4B9F5), fontSize: 15, height: 1.55)),
        if (_tab == 0) ...[
          const SizedBox(height: 10),
          const Text('Higher Wealth Levels may unlock upgraded room-entry special effects.', style: TextStyle(color: Color(0xFFE4B9F5), fontSize: 14, height: 1.45)),
        ],
      ]),
    );
  }

  Widget _tierTable(int currentLevel) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 15, 12, 12),
      decoration: BoxDecoration(color: const Color(0xFF1A0328), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFF9B45D5), width: 1.3)),
      child: Column(children: [
        const Padding(padding: EdgeInsets.fromLTRB(12, 5, 12, 15), child: Row(children: [Expanded(child: Text('Level', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEAC7FF), fontSize: 17, fontWeight: FontWeight.w600))), Expanded(child: Text('Icon', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFEAC7FF), fontSize: 17, fontWeight: FontWeight.w600)))])),
        for (int i = 0; i < _tiers.length; i++) ...[
          Divider(height: 1, color: const Color(0xFF71349B).withOpacity(.45)),
          _tierRow(_tiers[i], currentLevel),
        ],
      ]),
    );
  }

  Widget _tierRow(Map<String, dynamic> tier, int currentLevel) {
    final firstLevel = tier['level'] as int;
    final configRows = _config.where((item) => item is Map && item['level_type'] == _type && _number(item['level_number']) == firstLevel).toList();
    final iconUrl = configRows.isNotEmpty ? configRows.first['icon_url']?.toString() : null;
    final color = tier['color'] as Color;
    final isCurrentTier = currentLevel >= firstLevel && (firstLevel == 100 || currentLevel < firstLevel + 10);
    return Container(
      color: isCurrentTier ? _purple.withOpacity(.12) : Colors.transparent,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(children: [
        Expanded(child: Text(tier['label'].toString(), textAlign: TextAlign.center, style: TextStyle(color: isCurrentTier ? Colors.white : const Color(0xFFE7C8F6), fontSize: 16, fontWeight: isCurrentTier ? FontWeight.bold : FontWeight.normal))),
        Expanded(child: Center(child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), gradient: LinearGradient(colors: [color, color.withOpacity(.65)]), border: Border.all(color: Colors.white54, width: .7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (iconUrl != null && iconUrl.isNotEmpty) ClipOval(child: Image.network(iconUrl, width: 24, height: 24, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, color: Colors.white, size: 23)))
            else const Icon(Icons.workspace_premium, color: Colors.white, size: 23),
            const SizedBox(width: 7), Text('$firstLevel', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
        ))),
      ]),
    );
  }
}

// ============================================================
// HONOR / BADGE CENTER
// ============================================================

class MindoHonorScreen extends StatefulWidget {
  const MindoHonorScreen({super.key});

  @override
  State<MindoHonorScreen> createState() => _MindoHonorScreenState();
}

class _MindoHonorScreenState extends State<MindoHonorScreen> {
  int _category = 0;

  final List<Map<String, dynamic>> _badges = [
    {'name': 'Charm No 1', 'category': 'Achievement', 'owned': true, 'active': false},
    {'name': 'Wealth No 1', 'category': 'Achievement', 'owned': true, 'active': false},
    {'name': 'Popular Host', 'category': 'Achievement', 'owned': false, 'active': false},
    {'name': 'Top Gifter', 'category': 'Achievement', 'owned': false, 'active': false},
    {'name': 'Charm No 1', 'category': 'Activity', 'owned': true, 'active': false},
    {'name': 'Daily Active', 'category': 'Activity', 'owned': true, 'active': false},
    {'name': 'Room Star', 'category': 'Activity', 'owned': false, 'active': false},
    {'name': 'Social Star', 'category': 'Activity', 'owned': false, 'active': false},
  ];

  static const Color _pink = Color(0xFFFF168D);
  static const Color _purple = Color(0xFFB45AFF);
  static const Color _gold = Color(0xFFFFD76A);

  @override
  Widget build(BuildContext context) {
    final categoryName = _category == 0 ? 'Achievement' : 'Activity';
    final visible = _badges.where((b) => b['category'] == categoryName).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF242424),
      appBar: AppBar(
        backgroundColor: const Color(0xFF303030),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _pink),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Badge', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Row(children: [
            _categoryTab('Achievement Badges', 0),
            _categoryTab('Activity Badges', 1),
          ]),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              itemCount: visible.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 16,
                childAspectRatio: 0.91,
              ),
              itemBuilder: (context, index) {
                final badge = visible[index];
                return _badgeCard(badge, showOwned: false);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
              child: SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    elevation: 0,
                  ),
                  onPressed: _openMyBadges,
                  child: const Text('My Badges', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryTab(String title, int index) {
    final selected = _category == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _category = index),
        child: Container(
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: selected ? Colors.white : Colors.transparent, width: 3)),
          ),
          child: FittedBox(
            child: Text(title, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ),
        ),
      ),
    );
  }

  Widget _badgeCard(Map<String, dynamic> badge, {required bool showOwned}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF303030), borderRadius: BorderRadius.circular(25)),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(child: Center(child: _badgeEmblem())),
          const SizedBox(height: 8),
          Text('${badge['name']}', textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
          if (showOwned) ...[
            const SizedBox(height: 8),
            Text(badge['active'] == true ? 'ACTIVE' : 'INACTIVE',
              style: TextStyle(color: badge['active'] == true ? const Color(0xFF72E6A1) : Colors.white60, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }

  Widget _badgeEmblem() {
    return Container(
      width: 118, height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: _gold.withOpacity(0.18), blurRadius: 18, spreadRadius: 2)],
      ),
      child: Stack(alignment: Alignment.center, children: [
        const Icon(Icons.workspace_premium, size: 112, color: Color(0xFFD8B45A)),
        Container(
          width: 57, height: 66,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF3B24), Color(0xFFB90019)]),
            border: Border.all(color: const Color(0xFFFFE18A), width: 3),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.shield, color: Colors.white24, size: 35),
        ),
        const Positioned(top: 0, child: Icon(Icons.workspace_premium, color: _gold, size: 30)),
      ]),
    );
  }

  void _openMyBadges() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => MindoMyBadgesScreen(
        badges: _badges,
        onToggle: (badge, active) {
          setState(() => badge['active'] = active);
        },
      ),
    ));
  }
}

class MindoMyBadgesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> badges;
  final void Function(Map<String, dynamic>, bool) onToggle;

  const MindoMyBadgesScreen({super.key, required this.badges, required this.onToggle});

  @override
  State<MindoMyBadgesScreen> createState() => _MindoMyBadgesScreenState();
}

class _MindoMyBadgesScreenState extends State<MindoMyBadgesScreen> {
  int _category = 0;

  @override
  Widget build(BuildContext context) {
    final categoryName = _category == 0 ? 'Achievement' : 'Activity';
    final owned = widget.badges.where((b) => b['category'] == categoryName && b['owned'] == true).toList();
    return Scaffold(
      backgroundColor: const Color(0xFF242424),
      appBar: AppBar(
        backgroundColor: const Color(0xFF303030), centerTitle: true, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFFF168D)), onPressed: () => Navigator.pop(context)),
        title: const Text('My Badges', style: TextStyle(color: Colors.white)),
      ),
      body: Column(children: [
        Row(children: [
          _tab('Achievement Badges', 0),
          _tab('Activity Badges', 1),
        ]),
        Expanded(
          child: owned.isEmpty
            ? const Center(child: Text('No badges assigned yet', style: TextStyle(color: Colors.white70)))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: owned.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final badge = owned[index];
                  final active = badge['active'] == true;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF303030), borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      SizedBox(width: 76, height: 82, child: _smallEmblem()),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${badge['name']}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 5),
                        Text(active ? 'Shown on public profile' : 'Not shown on public profile',
                          style: TextStyle(color: active ? const Color(0xFF72E6A1) : Colors.white60, fontSize: 12)),
                      ])),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: active ? const Color(0xFF555555) : const Color(0xFFB45AFF),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          setState(() => badge['active'] = !active);
                          widget.onToggle(badge, !active);
                        },
                        child: Text(active ? 'DEACTIVATE' : 'ACTIVE'),
                      ),
                    ]),
                  );
                },
              ),
        ),
      ]),
    );
  }

  Widget _tab(String title, int index) {
    final selected = _category == index;
    return Expanded(child: InkWell(
      onTap: () => setState(() => _category = index),
      child: Container(height: 58, alignment: Alignment.center,
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? Colors.white : Colors.transparent, width: 3))),
        child: FittedBox(child: Text(title, style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: selected ? FontWeight.w600 : FontWeight.normal))),
      ),
    ));
  }

  Widget _smallEmblem() {
    return const Icon(Icons.workspace_premium, size: 70, color: Color(0xFFFFD76A));
  }
}

class MindoMallScreen extends StatefulWidget {
  final String token;

  const MindoMallScreen({super.key, required this.token});

  @override
  State<MindoMallScreen> createState() => _MindoMallScreenState();
}

class _MindoMallScreenState extends State<MindoMallScreen> {
  static const Color _bg = Color(0xFF090316);
  static const Color _panel = Color(0xFF19092D);
  static const Color _purple = Color(0xFF9D35E8);
  static const Color _pink = Color(0xFFFF2998);
  static const Color _gold = Color(0xFFFFD36A);

  final List<String> _categories = const [
    'Frame',
    'Entry',
    'Chat Bubble',
    'Unique ID',
  ];

  int _tab = 0; // 0 = Props, 1 = My Props
  String _category = 'Frame';
  int? _selectedProduct;

  // Temporary visual catalogue. These are demo products, not live store data.
  final List<Map<String, dynamic>> _products = [
    {'id': 1, 'name': 'Golden Wings', 'category': 'Frame', 'days': 100, 'price': 500, 'icon': Icons.workspace_premium_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 2, 'name': 'Rose Love', 'category': 'Frame', 'days': 100, 'price': 600, 'icon': Icons.favorite_rounded, 'owned': true, 'source': 'Purchased'},
    {'id': 3, 'name': 'Crystal Crown', 'category': 'Frame', 'days': 30, 'price': 300, 'icon': Icons.diamond_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 4, 'name': 'Blue Butterfly', 'category': 'Frame', 'days': 100, 'price': 500, 'icon': Icons.auto_awesome_rounded, 'owned': true, 'source': 'Event Reward'},
    {'id': 5, 'name': 'Royal Entrance', 'category': 'Entry', 'days': 30, 'price': 800, 'icon': Icons.flash_on_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 6, 'name': 'Love Entrance', 'category': 'Entry', 'days': 100, 'price': 1000, 'icon': Icons.favorite, 'owned': false, 'source': 'Shop'},
    {'id': 7, 'name': 'Neon Bubble', 'category': 'Chat Bubble', 'days': 30, 'price': 250, 'icon': Icons.chat_bubble_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 8, 'name': 'Royal Bubble', 'category': 'Chat Bubble', 'days': 100, 'price': 450, 'icon': Icons.forum_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 9, 'name': 'Golden ID', 'category': 'Unique ID', 'days': 100, 'price': 700, 'icon': Icons.badge_rounded, 'owned': false, 'source': 'Shop'},
    {'id': 10, 'name': 'Pink ID', 'category': 'Unique ID', 'days': 30, 'price': 350, 'icon': Icons.fingerprint_rounded, 'owned': false, 'source': 'Shop'},
  ];

  final Set<int> _activeIds = {2};

  List<Map<String, dynamic>> get _visibleProducts {
    return _products.where((p) {
      final matchesCategory = p['category'] == _category;
      final matchesTab = _tab == 0 || p['owned'] == true;
      return matchesCategory && matchesTab;
    }).toList();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF35104F),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmAction({
    required String title,
    required Map<String, dynamic> product,
    required String action,
    required String detail,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: _purple.withOpacity(0.8)),
        ),
        title: Text(
          title,
          style: const TextStyle(color: _gold, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _productArtwork(product, size: 104),
            const SizedBox(height: 12),
            Text(
              '${product['name']}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'Validity: ${product['days']} Days',
              style: const TextStyle(color: Colors.white70),
            ),
            if (action == 'BUY') ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monetization_on_rounded, color: _gold),
                  const SizedBox(width: 6),
                  Text('${product['price']} Coins', style: const TextStyle(color: _gold, fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(detail, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              action == 'BUY'
                  ? 'CONFIRM BUY'
                  : action == 'USE'
                      ? 'CONFIRM ACTIVATE'
                      : action == 'DEACTIVATE'
                          ? 'CONFIRM DEACTIVATE'
                          : 'CONFIRM SEND',
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _buySelected() async {
    final matches = _visibleProducts;
    if (_selectedProduct == null) {
      _message('Please select a product first.');
      return;
    }
    final product = matches.firstWhere((p) => p['id'] == _selectedProduct);
    final confirmed = await _confirmAction(
      title: 'Confirm Purchase',
      product: product,
      action: 'BUY',
      detail: 'Coins will only be deducted after the secure store connection is enabled.',
    );
    if (confirmed && mounted) {
      _message('Purchase confirmation is ready. Live coin deduction will be connected after server restoration.');
    }
  }

  Future<void> _togglePropStatus(Map<String, dynamic> product) async {
    final id = product['id'] as int;
    final isActive = _activeIds.contains(id);

    final confirmed = await _confirmAction(
      title: isActive ? 'Deactivate Prop?' : 'Activate Prop?',
      product: product,
      action: isActive ? 'DEACTIVATE' : 'USE',
      detail: isActive
          ? 'This prop will be removed from your active profile display.'
          : 'This prop will be applied to your profile.',
    );

    if (!confirmed || !mounted) return;

    setState(() {
      if (isActive) {
        _activeIds.remove(id);
      } else {
        _activeIds.add(id);
      }
    });

    _message(isActive
        ? '${product['name']} has been deactivated.'
        : '${product['name']} has been activated.');
  }

  Future<void> _openSendSheet() async {
    if (_selectedProduct == null) {
      _message('Please select the prop you want to send first.');
      return;
    }
    final idController = TextEditingController();
    String? searchedId;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _panel,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              18, 20, 18, MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(5)))),
                const SizedBox(height: 18),
                const Text('SEND PROP TO USER', style: TextStyle(color: _gold, fontSize: 19, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                const Text('Enter the receiver’s MINDO User ID', style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 14),
                TextField(
                  controller: idController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by User ID',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: _purple),
                    filled: true,
                    fillColor: const Color(0xFF0D0619),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _purple)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: _purple.withOpacity(0.6))),
                  ),
                  onChanged: (_) => setSheetState(() => searchedId = null),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (idController.text.trim().isEmpty) {
                        setSheetState(() => searchedId = '');
                      } else {
                        setSheetState(() => searchedId = idController.text.trim());
                      }
                    },
                    icon: const Icon(Icons.search),
                    label: const Text('SEARCH USER ID'),
                    style: ElevatedButton.styleFrom(backgroundColor: _purple, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13)),
                  ),
                ),
                if (searchedId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(color: const Color(0xFF0D0619), borderRadius: BorderRadius.circular(14), border: Border.all(color: _pink.withOpacity(0.6))),
                    child: Text(
                      searchedId!.isEmpty
                          ? 'Please enter a valid User ID.'
                          : 'User lookup for ID $searchedId will be enabled when the server is restored. No item has been sent.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
    idController.dispose();
  }

  Widget _productArtwork(Map<String, dynamic> product, {double size = 132}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(colors: [Color(0xFF59118B), Color(0xFF19052D), Color(0xFF080312)]),
        border: Border.all(color: _gold, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xAAE82DFF), blurRadius: 15, spreadRadius: 1),
          BoxShadow(color: Color(0x88FFB52E), blurRadius: 10),
        ],
      ),
      child: Icon(
        product['icon'] as IconData,
        size: size * 0.48,
        color: _gold,
        shadows: const [Shadow(color: _pink, blurRadius: 16)],
      ),
    );
  }

  Widget _categoryChip(String category) {
    final selected = _category == category;
    return Padding(
      padding: const EdgeInsets.only(right: 9),
      child: ChoiceChip(
        label: Text(category),
        selected: selected,
        onSelected: (_) => setState(() {
          _category = category;
          _selectedProduct = null;
        }),
        selectedColor: _purple,
        backgroundColor: const Color(0xFF28113D),
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold),
        side: BorderSide(color: selected ? _gold : _purple.withOpacity(0.55)),
        shape: const StadiumBorder(),
      ),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final id = product['id'] as int;
    final selected = _selectedProduct == id;
    final owned = product['owned'] == true;
    return GestureDetector(
      onTap: () => setState(() => _selectedProduct = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: const Color(0xE8170928),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: selected ? _gold : _purple.withOpacity(0.65), width: selected ? 2 : 1),
          boxShadow: selected ? const [BoxShadow(color: Color(0x66FFB52E), blurRadius: 13)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 5),
              child: Row(
                children: [
                  Expanded(child: Text('${product['days']} Days', style: const TextStyle(color: Color(0xFFD9A6FF), fontSize: 12, fontWeight: FontWeight.bold))),
                  if (owned) Icon(Icons.verified_rounded, color: _gold, size: 16),
                ],
              ),
            ),
            Expanded(
              child: Center(child: _productArtwork(product, size: 116)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('${product['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(height: 7),
            Container(
              margin: const EdgeInsets.fromLTRB(7, 0, 7, 8),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7618B7), Color(0xFFB044F0)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _tab == 0
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.monetization_on_rounded, color: _gold, size: 18),
                      const SizedBox(width: 5),
                      Text('${product['price']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ])
                  : GestureDetector(
                      onTap: () => _togglePropStatus(product),
                      child: Text(
                        _activeIds.contains(id) ? 'DEACTIVATE' : 'ACTIVATE',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final products = _visibleProducts;
    return Scaffold(
      backgroundColor: _bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF30064B), _bg, Color(0xFF10051D)]),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
                child: Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _gold)),
                    const Expanded(child: Column(children: [
                      Text('MINDO', style: TextStyle(color: _gold, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 2)),
                      Text('VOICE CHAT', style: TextStyle(color: Color(0xFFD9A6FF), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 3)),
                    ])),
                    const Icon(Icons.monetization_on_rounded, color: _gold),
                    const SizedBox(width: 5),
                    const Text('—', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: const Color(0xFF0D0619), borderRadius: BorderRadius.circular(30), border: Border.all(color: _purple)),
                  child: Row(children: [
                    Expanded(child: _topTab('Props', 0)),
                    Expanded(child: _topTab('My Props', 1)),
                  ]),
                ),
              ),
              const SizedBox(height: 13),
              Container(
                width: 74, height: 74,
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _pink, width: 2.5), boxShadow: const [BoxShadow(color: _pink, blurRadius: 16)]),
                child: const CircleAvatar(backgroundColor: Color(0xFF260B3D), child: Icon(Icons.person_rounded, color: _gold, size: 40)),
              ),
              const SizedBox(height: 13),
              SizedBox(
                height: 43,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  scrollDirection: Axis.horizontal,
                  children: _categories.map(_categoryChip).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: products.isEmpty
                    ? Center(child: Text(_tab == 0 ? 'No products in this category yet.' : 'No owned items in this category yet.', style: const TextStyle(color: Colors.white70)))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                        itemCount: products.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.76),
                        itemBuilder: (_, index) => _productCard(products[index]),
                      ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                decoration: BoxDecoration(color: const Color(0xF5090316), border: Border(top: BorderSide(color: _purple.withOpacity(0.5)))),
                child: _tab == 0
                    ? Row(children: [
                        Expanded(child: _bottomAction('Send', Icons.card_giftcard_rounded, _purple, _openSendSheet)),
                        const SizedBox(width: 12),
                        Expanded(child: _bottomAction('Buy', Icons.shopping_bag_rounded, _pink, _buySelected)),
                      ])
                    : Center(child: SizedBox(width: 190, child: _bottomAction('Send', Icons.card_giftcard_rounded, _purple, _openSendSheet))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topTab(String label, int index) {
    final selected = _tab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _tab = index;
        _selectedProduct = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [_purple, Color(0xFFCE35C9)]) : null,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _bottomAction(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: color.withOpacity(0.6),
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}


// ============================================================
// PUBLIC PROFILE SCREEN
// ============================================================

class PublicProfileScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const PublicProfileScreen({
    super.key,
    required this.user,
  });

  void showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  showReportReasons(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Blacklist'),
                onTap: () {
                  Navigator.pop(context);
                  showBlacklistConfirmation(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  void showReportReasons(BuildContext context) {
    const reasons = [
      'Politically Sensitive',
      'Pornographic vulgarity',
      'User Harassment',
      'Country Disrespect',
      'Religious Disrespect',
      'Cancel',
    ];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                child: Text(
                  'Report User',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ...reasons.map(
                (reason) => ListTile(
                  title: Text(reason),
                  onTap: () {
                    Navigator.pop(context);
                    if (reason != 'Cancel') {
                      showMessage(
                        context,
                        'Report reason: $reason',
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void showBlacklistConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Blacklist'),
          content: const Text(
            'Blacklist ke baad woh user aapko text nahi bhej sakega '
            'aur aapki personal profile visit nahi kar sakega.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                showMessage(context, 'User blacklisted');
              },
              child: const Text('Blacklist'),
            ),
          ],
        );
      },
    );
  }

  Widget actionButton(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: OutlinedButton.icon(
          onPressed: () => showMessage(
            context,
            '$label will be connected next',
          ),
          icon: Icon(icon, size: 18),
          label: Text(label),
        ),
      ),
    );
  }

  Widget infoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.deepPurple.shade50,
          child: Icon(
            icon,
            color: Colors.deepPurple,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(value),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = user['display_name']?.toString().trim().isNotEmpty == true
        ? user['display_name'].toString().trim()
        : user['username']?.toString() ?? 'User';

    final uid = user['public_uid']?.toString() ?? '------';
    final signature = user['signature']?.toString().trim() ?? '';
    final country = user['country']?.toString().trim() ?? '';
    final avatarUrl = user['avatar_url']?.toString().trim() ?? '';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFFFFD54F),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => showMoreMenu(context),
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
          child: Column(
            children: [
              CircleAvatar(
                radius: 62,
                backgroundImage: avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl.isEmpty
                    ? const Icon(Icons.person, size: 62)
                    : null,
              ),

              const SizedBox(height: 14),

              Row(
                mainAxisSize: MainAxisSize.min,
                children: [

Flexible(
  child: AnimatedRainbowText(
    text: name,
    fontSize: 25,
    fontWeight: FontWeight.bold,
  ),
),
                  if (country.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    const Text(
                      '🌍',
                      style: TextStyle(fontSize: 20),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 5),

              Text(
                'UID: $uid',
                style: const TextStyle(
                  color: Colors.deepPurple,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),

              if (signature.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  signature,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              Row(
                children: [
                  actionButton(
                    context,
                    Icons.track_changes,
                    'Track',
                  ),
                  actionButton(
                    context,
                    Icons.mic,
                    'Room',
                  ),
                  actionButton(
                    context,
                    Icons.person_add_alt_1,
                    'Follow',
                  ),
                  actionButton(
                    context,
                    Icons.chat_bubble_outline,
                    'Chat',
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.business,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agency',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Agency information',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Profile Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 10),

              infoCard(
                icon: Icons.crop_square,
                title: 'Frame',
                value: 'Profile frame',
              ),

              infoCard(
                icon: Icons.login,
                title: 'Entry',
                value: 'Entry effect',
              ),

              infoCard(
                icon: Icons.card_giftcard,
                title: 'Gifts',
                value: 'Received gifts',
              ),

              const SizedBox(height: 8),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Received Gifts',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.card_giftcard,
                              color: Colors.deepPurple,
                              size: 34,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${user['gift_count'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.redeem,
                              color: Colors.deepPurple,
                              size: 34,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${user['gift_count_2'] ?? 0}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Birthday and coins are intentionally NOT shown
              // on another user's public profile.
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// EDIT PROFILE SCREEN
// ============================================================

class EditProfileScreen
    extends StatefulWidget {
  final String token;
  final Map<String, dynamic> user;

  const EditProfileScreen({
    super.key,
    required this.token,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  late final TextEditingController
      nameController;

  late final TextEditingController
      signatureController;

  String birthday = '';
  String country = '';
  String gender = '';

  String currentAvatarUrl = '';

  final ImagePicker _picker =
      ImagePicker();

  XFile? selectedImage;

  bool saving = false;

  final List<String> countries = const [
    'Pakistan',
    'India',
    'United Arab Emirates',
    'United Kingdom',
    'Saudi Arabia',
    'Bangladesh',
    'Nepal',
    'Qatar',
    'Kuwait',
    'Oman',
    'Bahrain',
    'United States',
    'Canada',
    'Australia',
    'Germany',
    'France',
    'Turkey',
  ];

  final List<String> genders = const [
    'Male',
    'Female',
  ];

  @override
  void initState() {
    super.initState();

    final displayName =
        widget.user['display_name']
                ?.toString()
                .trim() ??
            '';

    final username =
        widget.user['username']
                ?.toString() ??
            '';

    nameController =
        TextEditingController(
      text: displayName.isNotEmpty
          ? displayName
          : username,
    );

    signatureController =
        TextEditingController(
      text: widget.user['signature']
              ?.toString() ??
          '',
    );

    birthday =
        widget.user['birthday']
                ?.toString() ??
            '';

    country =
        widget.user['country']
                ?.toString() ??
            '';

    gender =
        widget.user['gender']
                ?.toString() ??
            '';

    currentAvatarUrl =
        widget.user['avatar_url']
                ?.toString() ??
            '';
  }

  @override
  void dispose() {
    nameController.dispose();
    signatureController.dispose();
    super.dispose();
  }

  // ==========================================================
  // IMAGE PICKER
  // ==========================================================

  Future<void> pickProfileImage(
    ImageSource source,
  ) async {
    try {
      final image =
          await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null) {
        return;
      }

      if (!mounted) return;

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Image select failed: $e',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // IMAGE OPTIONS
  // ==========================================================

  void showImageOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading:
                    const Icon(
                  Icons.photo_library,
                ),
                title:
                    const Text(
                  'Choose from Gallery',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  pickProfileImage(
                    ImageSource
                        .gallery,
                  );
                },
              ),
              ListTile(
                leading:
                    const Icon(
                  Icons.camera_alt,
                ),
                title:
                    const Text(
                  'Take Photo',
                ),
                onTap: () {
                  Navigator.pop(
                    context,
                  );

                  pickProfileImage(
                    ImageSource
                        .camera,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // DATE PICKER
  // ==========================================================

  Future<void> pickBirthday() async {
    DateTime initialDate =
        DateTime(2000, 1, 1);

    if (birthday.isNotEmpty) {
      try {
        final parsed =
            DateTime.tryParse(
          birthday,
        );

        if (parsed != null) {
          initialDate = parsed;
        }
      } catch (_) {}
    }

    final now = DateTime.now();

    if (initialDate.isAfter(now)) {
      initialDate = now;
    }

    final selected =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate:
          DateTime(1900),
      lastDate: now,
      helpText:
          'Select your birthday',
    );

    if (selected == null) {
      return;
    }

    if (!mounted) return;

    final month =
        selected.month
            .toString()
            .padLeft(2, '0');

    final day =
        selected.day
            .toString()
            .padLeft(2, '0');

    setState(() {
      birthday =
          '${selected.year}-$month-$day';
    });
  }

  String countryFlag(String value) {
    const flags = {
      'Pakistan': '🇵🇰',
      'India': '🇮🇳',
      'United Arab Emirates': '🇦🇪',
      'United Kingdom': '🇬🇧',
      'Saudi Arabia': '🇸🇦',
      'Bangladesh': '🇧🇩',
      'Nepal': '🇳🇵',
      'Qatar': '🇶🇦',
      'Kuwait': '🇰🇼',
      'Oman': '🇴🇲',
      'Bahrain': '🇧🇭',
      'United States': '🇺🇸',
      'Canada': '🇨🇦',
      'Australia': '🇦🇺',
      'Germany': '🇩🇪',
      'France': '🇫🇷',
      'Turkey': '🇹🇷',
    };
    return flags[value] ?? '🌍';
  }

  // ==========================================================
  // SAVE PROFILE
  // ==========================================================

  Future<void> saveProfile() async {
    final name =
        nameController.text.trim();

    final signature =
        signatureController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content:
              Text('Name is required'),
        ),
      );

      return;
    }

    if (country.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose your country',
          ),
        ),
      );
      return;
    }

    if (gender.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose your gender',
          ),
        ),
      );
      return;
    }

    if (name.length > 50) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Name must be 50 characters or less',
          ),
        ),
      );

      return;
    }

    if (signature.length > 150) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Signature must be 150 characters or less',
          ),
        ),
      );

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      // ------------------------------------------------------
      // STEP 1: SAVE NAME / SIGNATURE / BIRTHDAY
      // ------------------------------------------------------

      await api.saveProfileDetails(
        widget.token,
        name,
        signature,
        birthday,
        country: country,
        gender: gender,
      );

      // ------------------------------------------------------
      // STEP 2: UPLOAD NEW DP IF SELECTED
      // ------------------------------------------------------

      if (selectedImage != null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(
            const SnackBar(
              content: Text(
                'Uploading profile photo...',
              ),
            ),
          );
        }

        final avatarUrl =
            await uploadProfilePhotoToCloudinary(
          selectedImage!.path,
        );

        if (avatarUrl == null) {
          throw Exception(
            'Profile photo upload failed',
          );
        }

        await api.saveProfilePhoto(
          widget.token,
          avatarUrl,
        );
      }

      // ------------------------------------------------------
      // STEP 3: LOAD COMPLETE UPDATED USER
      // ------------------------------------------------------

      final result =
          await api.me(
        widget.token,
      );

      final updatedUser =
          result['user'];

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile updated successfully',
          ),
        ),
      );

      final updatedUserMap =
          Map<String, dynamic>.from(
        updatedUser,
      );

      updatedUserMap['country'] = country;
      updatedUserMap['gender'] = gender;

      Navigator.pop(
        context,
        updatedUserMap,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst(
                  'Exception: ',
                  '',
                ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  // ==========================================================
  // EDIT PROFILE UI
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    ImageProvider<Object>?
        avatarImage;

    if (selectedImage != null) {
      avatarImage =
          FileImage(
        File(
          selectedImage!.path,
        ),
      );
    } else if (currentAvatarUrl
        .isNotEmpty) {
      avatarImage =
          NetworkImage(
        currentAvatarUrl,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Edit Profile',
        ),
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // PROFILE PHOTO
              // ==================================================

              GestureDetector(
                onTap:
                    saving
                        ? null
                        : showImageOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 65,
                      backgroundImage:
                          avatarImage,
                      child: avatarImage ==
                              null
                          ? const Icon(
                              Icons.person,
                              size: 65,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child:
                          Container(
                        padding:
                            const EdgeInsets
                                .all(10),
                        decoration:
                            const BoxDecoration(
                          color: Colors
                              .deepPurple,
                          shape:
                              BoxShape
                                  .circle,
                        ),
                        child:
                            const Icon(
                          Icons
                              .camera_alt,
                          color: Colors
                              .white,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Tap photo to change',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // NAME
              // ==================================================

              TextField(
                controller:
                    nameController,
                maxLength: 50,
                textCapitalization:
                    TextCapitalization
                        .words,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Name',
                  hintText:
                      'Enter your name',
                  prefixIcon:
                      Icon(
                    Icons
                        .person_outline,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // SIGNATURE
              // ==================================================

              TextField(
                controller:
                    signatureController,
                maxLength: 150,
                maxLines: 3,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Signature',
                  hintText:
                      'Write something about yourself',
                  prefixIcon:
                      Icon(
                    Icons
                        .edit_note,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              // ==================================================
              // COUNTRY
              // ==================================================

              DropdownButtonFormField<String>(
                value: countries.contains(country)
                    ? country
                    : null,
                decoration:
                    const InputDecoration(
                  labelText: 'Country',
                  prefixIcon:
                      Icon(Icons.public),
                  border:
                      OutlineInputBorder(),
                ),
                items: countries.map(
                  (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        '${countryFlag(item)}  $item',
                      ),
                    );
                  },
                ).toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          country = value;
                        });
                      },
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // GENDER
              // ==================================================

              DropdownButtonFormField<String>(
                value: genders.contains(gender)
                    ? gender
                    : null,
                decoration:
                    InputDecoration(
                  labelText: 'Gender',
prefixIcon: Container(
  margin: const EdgeInsets.all(10),
  width: 28,
  height: 28,
  decoration: BoxDecoration(
    color: gender == 'Male'
        ? Colors.blue
        : Colors.pink,
    borderRadius: BorderRadius.circular(5),
  ),
  child: Icon(
    gender == 'Male'
        ? Icons.male
        : Icons.female,
    color: Colors.white,
    size: 20,
  ),
),
                  border:
                      OutlineInputBorder(),
                ),
                items: genders.map(
                  (item) {
                    return DropdownMenuItem<String>(
                      value: item,
                      child: Text(item),
                    );
                  },
                ).toList(),
                onChanged: saving
                    ? null
                    : (value) {
                        if (value == null) return;
                        setState(() {
                          gender = value;
                        });
                      },
              ),

              const SizedBox(
                height: 15,
              ),

              // ==================================================
              // BIRTHDAY
              // ==================================================

              InkWell(
                onTap:
                    saving
                        ? null
                        : pickBirthday,
                borderRadius:
                    BorderRadius
                        .circular(12),
                child:
                    InputDecorator(
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Birthday',
                    prefixIcon:
                        Icon(
                      Icons
                          .cake_outlined,
                    ),
                    suffixIcon:
                        Icon(
                      Icons
                          .calendar_month,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                  child: Text(
                    birthday.isEmpty
                        ? 'Select birthday'
                        : birthday,
                    style:
                        TextStyle(
                      color:
                          birthday.isEmpty
                              ? Colors
                                  .grey
                              : Colors
                                  .black87,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 30,
              ),

              // ==================================================
              // SAVE BUTTON
              // ==================================================

              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton.icon(
                  onPressed:
                      saving
                          ? null
                          : saveProfile,
                  icon: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth:
                                2,
                            color: Colors
                                .white,
                          ),
                        )
                      : const Icon(
                          Icons.save,
                        ),
                  label: Text(
                    saving
                        ? 'Saving...'
                        : 'Save Profile',
                  ),
                ),
              ),

              const SizedBox(
                height: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoomSettingsScreen extends StatefulWidget {
  final String roomName;
  final int seatCount;
  final String greeting;
  final String roomPassword;

  const RoomSettingsScreen({
    super.key,
    required this.roomName,
    required this.seatCount,
    required this.greeting,
    required this.roomPassword,
  });

  @override
  State<RoomSettingsScreen> createState() =>
      _RoomSettingsScreenState();
}

class _RoomSettingsScreenState
    extends State<RoomSettingsScreen> {
  late TextEditingController nameController;
  late TextEditingController greetingController;
  late TextEditingController passwordController;

  late int selectedSeats;
  bool passwordEnabled = false;
   
    final ImagePicker _roomImagePicker = ImagePicker();
XFile? _selectedRoomImage;

  @override
  void initState() {
    super.initState();
    nameController =
        TextEditingController(text: widget.roomName);
    greetingController =
        TextEditingController(text: widget.greeting);
    passwordController =
        TextEditingController(text: widget.roomPassword);
    selectedSeats = widget.seatCount;
    passwordEnabled = widget.roomPassword.isNotEmpty;
  }

  @override
  void dispose() {
    nameController.dispose();
    greetingController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void editText({
    required String title,
    required TextEditingController controller,
    int maxLength = 100,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF382D30),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          maxLength: maxLength,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.pink),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.pink),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              setState(() {});
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget settingRow({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.pinkAccent),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios,
              color: Colors.white70, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.pinkAccent,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Room Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF382D30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                settingRow(
                  icon: Icons.image_outlined,
                  title: 'Room Picture',
                  value: 'Change',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor:
                          const Color(0xFF382D30),
                      builder: (sheetContext) =>
                          SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                              ),
                              title: const Text(
                                'Camera',
                                style: TextStyle(
                                    color: Colors.white),
                              ),
                                
onTap: () async {
  Navigator.pop(sheetContext);

  final XFile? image = await _roomImagePicker.pickImage(
    source: ImageSource.camera,
    imageQuality: 80,
    maxWidth: 800,
    maxHeight: 800,
  );

  if (image != null && mounted) {
    setState(() {
      _selectedRoomImage = image;
    });
  }
},
                            ),
                            ListTile(
                              leading: const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                              ),
                              title: const Text(
                                'Gallery',
                                style: TextStyle(
                                    color: Colors.white),
                              ),
onTap: () async {
Navigator.pop(sheetContext);

final XFile? image = await _roomImagePicker.pickImage(
source: ImageSource.gallery,
imageQuality: 80,
maxWidth: 800,
maxHeight: 800,
);

if (image != null && mounted) {
setState(() {
_selectedRoomImage = image;
});
}
},

                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                settingRow(
                  icon: Icons.edit,
                  title: 'Room Name',
                  value: nameController.text,
                  onTap: () => editText(
                    title: 'Room Name',
                    controller: nameController,
                    maxLength: 30,
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                settingRow(
                  icon: Icons.lock_outline,
                  title: 'Room Password',
                  value: passwordEnabled ? 'Locked' : 'Unlocked',
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) =>
                          StatefulBuilder(
                        builder: (context, updateDialog) =>
                            AlertDialog(
                          backgroundColor:
                              const Color(0xFF382D30),
                          title: const Text(
                            'Room Password',
                            style: TextStyle(color: Colors.white),
                          ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Enable room lock',
                                  style: TextStyle(
                                      color: Colors.white),
                                ),
                                value: passwordEnabled,
                                activeThumbColor:
                                    Colors.pinkAccent,
                                onChanged: (value) {
                                  updateDialog(() {
                                    passwordEnabled = value;
                                  });
                                  setState(() {});
                                },
                              ),
                              if (passwordEnabled)
                                TextField(
                                  controller: passwordController,
                                  obscureText: true,
                                  style: const TextStyle(
                                      color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Enter password',
                                    hintStyle: TextStyle(
                                        color: Colors.white54),
                                  ),
                                ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.pop(dialogContext),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                settingRow(
                  icon: Icons.event_seat_outlined,
                  title: 'Seat Layout',
                  value: '$selectedSeats Seats',
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      backgroundColor:
                          const Color(0xFF382D30),
                      builder: (sheetContext) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [5, 10, 15, 20, 25, 30]
                              .map((count) => ListTile(
                                    title: Text(
                                      '$count Seats',
                                      style: const TextStyle(
                                          color: Colors.white),
                                    ),
                                    trailing:
                                        selectedSeats == count
                                            ? const Icon(
                                                Icons.check,
                                                color: Colors.pinkAccent,
                                              )
                                            : null,
                                    onTap: () {
                                      setState(() {
                                        selectedSeats = count;
                                      });
                                      Navigator.pop(sheetContext);
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(color: Colors.white12, height: 1),
                settingRow(
                  icon: Icons.waving_hand_outlined,
                  title: 'Greetings',
                  value: greetingController.text.isEmpty
                      ? 'Add message'
                      : 'Edit message',
                  onTap: () => editText(
                    title: 'Greetings Message',
                    controller: greetingController,
                    maxLength: 100,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            onPressed: () {
              Navigator.pop(context, {
                'roomName': nameController.text.trim(),
                'seatCount': selectedSeats,
                'greeting': greetingController.text.trim(),
                'roomPassword': passwordEnabled
                    ? passwordController.text
                    : '',
              });
            },
            child: const Text(
              'Save Settings',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// VOICE ROOM UI
// ============================================================

class VoiceRoomScreen
    extends StatefulWidget {
  final String roomId;
    final String token;
  final String roomName;
  final int seatCount;
    final String ownerPublicUid;
    final String? coverImageUrl;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
      required this.token,
    required this.roomName,
    required this.seatCount,
    required this.ownerPublicUid,
      this.coverImageUrl,
  });

  @override
  State<VoiceRoomScreen> createState() =>
      _VoiceRoomScreenState();
}

class _VoiceRoomScreenState
    extends State<VoiceRoomScreen> {
  bool microphoneOn = false;

  final List<String> speakers = List.generate(
    10,
    (index) => 'Seat ${index + 1}',
  );
final Map<int, Map<String, dynamic>> seatMembers = {};

Future<void> loadRoomMembers() async {
  try {
    final result = await api.getRoomMembers(
      widget.token,
      widget.roomId,
    );

    final List<dynamic> seats = result['seats'] ?? [];
    final Map<int, Map<String, dynamic>> updated = {};

    for (final seat in seats) {
      final user = seat['user'];
      if (user != null) {
        updated[int.parse(seat['seatNumber'].toString())] =
            Map<String, dynamic>.from(user);
      }
    }

    if (mounted) {
      setState(() {
        seatMembers
          ..clear()
          ..addAll(updated);
      });
    }
  } catch (e) {
    debugPrint('Load room members error: $e');
  }
}
    @override
void initState() {
  super.initState();
  loadRoomMembers();
}
  Widget _roomLevelBadge(String prefix, dynamic rawLevel, {String? iconUrl}) {
    final level = rawLevel is num ? rawLevel.toInt() : int.tryParse('$rawLevel') ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF4B176B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD36A), width: .6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (iconUrl != null && iconUrl.isNotEmpty)
          ClipOval(child: Image.network(iconUrl, width: 11, height: 11, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.workspace_premium, size: 10, color: Color(0xFFFFD36A))))
        else
          const Icon(Icons.workspace_premium, size: 10, color: Color(0xFFFFD36A)),
        const SizedBox(width: 2),
        Text('$prefix$level', style: const TextStyle(color: Color(0xFFFFE2A0), fontSize: 8, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF211A35),
      appBar: AppBar(
          automaticallyImplyLeading: false,
        backgroundColor:
            const Color(0xFF211A35),
        foregroundColor:
            Colors.white,

title: SizedBox(
  height: 76,
  child: Stack(
    children: [
      Positioned(
        left: 0,
        right: 40,
        top: 0,
        bottom: 0,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F1DF),
            borderRadius: BorderRadius.circular(38),
            border: Border.all(
              color: const Color(0xFFD6A64F),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: ScrollingRainbowRoomName(
                    text: widget.roomName,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedRainbowText(
                  text: 'ID: ${widget.ownerPublicUid}',
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ],
            ),
          ),
        ),
      ),
      Positioned(
        left: 5,
        top: 10,
        child: CircleAvatar(
          radius: 28,
          backgroundColor: Colors.deepPurple,
          backgroundImage:
              widget.coverImageUrl != null &&
                      widget.coverImageUrl!.isNotEmpty
                  ? NetworkImage(widget.coverImageUrl!)
                  : null,
          child: widget.coverImageUrl == null ||
                  widget.coverImageUrl!.isEmpty
              ? const Icon(
                  Icons.home_work,
                  color: Colors.white,
                  size: 28,
                )
              : null,
        ),
      ),
    ],
  ),
),
actions: [
  // Share
  IconButton(
    onPressed: () {},
    icon: const Icon(
      Icons.share,
    ),
  ),

  // Off / Room Options
  IconButton(
    onPressed: () {
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF171225),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        builder: (context) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Room Options',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 15),


                  ListTile(
                    leading: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white,
                    ),
                    title: const Text(
                      'Minimize Room',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.exit_to_app_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      'Exit Room',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);

                      showDialog(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            backgroundColor:
                                const Color(0xFF211A35),
                            title: const Text(
                              'Exit Room?',
                              style: TextStyle(
                                color: Colors.white,
                              ),
                            ),
                            content: const Text(
                              'Are you sure you want to leave this room?',
                              style: TextStyle(
                                color: Colors.white70,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                },
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Exit',
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  ListTile(
                    leading: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                    ),
                    title: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
    icon: const Icon(
      Icons.power_settings_new_rounded,
    ),
  ),
],
      ),
      body: Column(
        children: [

          const SizedBox(
            height: 20,
          ),
          const SizedBox(
            height: 25,
          ),
          Expanded(
            child:
                GridView.builder(
              padding:
                  const EdgeInsets.all(
                      20),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing:
                    15,
                mainAxisSpacing:
                    25,
              ),
              itemCount:
                  speakers.length,
              itemBuilder:
                  (context, index) {
                final speaker =
                    speakers[index];

final member = seatMembers[index + 1];
return InkWell(
  onTap: () async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in again')),
        );
        return;
      }

      final result = await api.joinRoomSeat(
        token,
        widget.roomId,
        index + 1,
      );

      if (!mounted) return;

        await loadRoomMembers();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['message']?.toString() ?? 'Seat request completed',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  },
child: Column(
  children: [
    Builder(
      builder: (context) {
        final member = seatMembers[index + 1];
        final avatarUrl = member?['avatar_url']?.toString() ?? '';
        final displayName =
            member?['display_name']?.toString().trim();
        final username = member?['username']?.toString().trim();

        final name = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (username != null && username.isNotEmpty)
                ? username
                : speaker;

        return CircleAvatar(
          radius: 32,
          backgroundColor: Colors.deepPurple.shade300,
          backgroundImage: avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl.isEmpty
              ? const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 32,
                )
              : null,
        );
      },
    ),
    const SizedBox(height: 7),
    Text(
      (() {
        final member = seatMembers[index + 1];
        final displayName = member?['display_name']?.toString().trim();
        final username = member?['username']?.toString().trim();

        if (displayName != null && displayName.isNotEmpty) {
          return displayName;
        }
        if (username != null && username.isNotEmpty) {
          return username;
        }
        return speaker;
      })(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
      ),
    ),
    if (seatMembers[index + 1] != null) ...[
      const SizedBox(height: 3),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _roomLevelBadge('W', seatMembers[index + 1]?['wealth_level'], iconUrl: seatMembers[index + 1]?['wealth_level_icon_url']?.toString()),
        const SizedBox(width: 3),
        _roomLevelBadge('C', seatMembers[index + 1]?['charm_level'], iconUrl: seatMembers[index + 1]?['charm_level_icon_url']?.toString()),
      ]),
    ],
  ],
),
);
                      
              },
            ),
          ),

Container(
    transform: Matrix4.translationValues(0, -20, 0),
  padding: const EdgeInsets.symmetric(
    horizontal: 4,
    vertical: 0,
  ),

  child: Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roomButton(
              icon: Icons.chat_bubble_outline,
              label: '',
              onTap: () {},
            ),
            _roomButton(
              icon: Icons.volume_up_outlined,
              label: '',
              onTap: () {},
            ),
            _roomButton(
              icon: microphoneOn ? Icons.mic : Icons.mic_off,
              label: '',
              onTap: () {
                setState(() {
                  microphoneOn = !microphoneOn;
                });
              },
            ),
            _roomButton(
              icon: Icons.emoji_emotions_outlined,
              label: '',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF171225),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  builder: (sheetContext) {
                    final emojis = [
                      '😀', '😍', '😂', '🥰',
                      '😎', '😭', '😘', '🤗',
                      '👏', '❤️', '🔥', '👍',
                      '🎉', '🥳', '😜', '💖',
                    ];

                    return SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Choose Emoji',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),
                            GridView.builder(
                              shrinkWrap: true,
                              physics:
                                  const NeverScrollableScrollPhysics(),
                              itemCount: emojis.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                              ),
                              itemBuilder: (context, index) {
                                return InkWell(
                                  onTap: () {
                                    final selected = emojis[index];
                                    Navigator.pop(sheetContext);
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Selected $selected',
                                        ),
                                        duration:
                                            const Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  child: Center(
                                    child: Text(
                                      emojis[index],
                                      style: const TextStyle(
                                        fontSize: 30,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            _roomButton(
              icon: Icons.weekend,
              label: '',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    backgroundColor: const Color(0xFF171225),
                    title: const Text(
                      'Seat Apply Requests',
                      style: TextStyle(color: Colors.white),
                    ),
                    content: const Text(
                      'No seat requests yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.pop(dialogContext),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                );
              },
            ),
            _roomButton(
              icon: Icons.settings,
              label: '',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: const Color(0xFF171225),
                  builder: (sheetContext) {
                    return SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(
                              Icons.settings,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Room Settings',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              Navigator.push(
                                this.context,
                                MaterialPageRoute(
                                  builder: (pageContext) =>
                                      RoomSettingsScreen(
                                    roomName: widget.roomName,
                                    seatCount: widget.seatCount,
                                    greeting: '',
                                    roomPassword: '',
                                  ),
                                ),
                              );
                            },
                          ),
                          ListTile(
                            leading: const Icon(
                              Icons.music_note,
                              color: Colors.white,
                            ),
                            title: const Text(
                              'Music Player',
                              style: TextStyle(color: Colors.white),
                            ),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(this.context)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Music Player will be connected later.',
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(width: 6),
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF171225),
                  title: const Text(
                    'Games',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Game feature will be connected here.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: const SizedBox(
              width: 54,
              height: 54,
              child: Icon(
                Icons.sports_esports,
                color: Color(0xFFFFD54F),
                size: 60,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              showDialog(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  backgroundColor: const Color(0xFF171225),
                  title: const Text(
                    'Send Gift',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'Gift system will be connected here.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () =>
                          Navigator.pop(dialogContext),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: Color(0xFF58C900),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.card_giftcard,
                  color: Color(0xFFFFE082),
                  size: 36,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  ),
),
],
),
);
}
    
Widget _roomButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool active = false,
  bool danger = false,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Icon(
      icon,
      color: danger
          ? Colors.red
          : active
              ? Colors.red
              : Colors.white,
      size: 28,
    ),
  );
}
}

class ScrollingRainbowRoomName extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const ScrollingRainbowRoomName({
    super.key,
    required this.text,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  State<ScrollingRainbowRoomName> createState() =>
      _ScrollingRainbowRoomNameState();
}

class _ScrollingRainbowRoomNameState
    extends State<ScrollingRainbowRoomName> {
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _startScrolling();
  }

  void _startScrolling() {
    _scrollTimer?.cancel();

    _scrollTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (timer) async {
        if (!_scrollController.hasClients) return;

        final position = _scrollController.position;

        if (position.maxScrollExtent <= 0) return;

double nextOffset = _scrollController.offset + 1.0;

if (nextOffset >= position.maxScrollExtent) {
  _scrollController.jumpTo(0);
  return;
}

        await _scrollController.animateTo(
          nextOffset,
          duration: const Duration(milliseconds: 40),
          curve: Curves.linear,
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) {
        return const LinearGradient(
          colors: [
            Color(0xFFFFD700),
            Color(0xFFFF69B4),
            Color(0xFF00E5FF),
            Color(0xFFFFD700),
          ],
        ).createShader(bounds);
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(
          widget.text,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class AnimatedRainbowText extends StatefulWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;

  const AnimatedRainbowText({
    super.key,
    required this.text,
    required this.fontSize,
    required this.fontWeight,
  });

  @override
  State<AnimatedRainbowText> createState() =>
      _AnimatedRainbowTextState();
}

class _AnimatedRainbowTextState
    extends State<AnimatedRainbowText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      return ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) {
          final progress = _controller.value;
          return LinearGradient(
            begin: Alignment(-1 + 2 * progress, 0),
            end: Alignment(1 + 2 * progress, 0),
            colors: const [
              Color(0xFFFFD700),
              Color(0xFFFF69B4),
              Color(0xFF00E5FF),
              Color(0xFFFFD700),
            ],
          ).createShader(bounds);
        },
        child: Text(
          widget.text,
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: widget.fontWeight,
            color: Colors.white,
          ),
        ),
      );
    },
  );
}
}


// ============================================================
// MINDO AGENCY UI (LOCAL DEMO WORKFLOW - BACKEND LATER)
// ============================================================

class AgencyDirectoryScreen extends StatefulWidget {
  const AgencyDirectoryScreen({super.key});

  @override
  State<AgencyDirectoryScreen> createState() => _AgencyDirectoryScreenState();
}

class _AgencyDirectoryScreenState extends State<AgencyDirectoryScreen> {
  static final List<Map<String, dynamic>> _agencies = [
    {'name': 'Agency Rio Star', 'uid': '123456', 'country': 'Angola', 'flag': '🇦🇴', 'members': 62, 'status': 'Approved', 'dp': null},
    {'name': 'Mindo Royal', 'uid': '234567', 'country': 'United Arab Emirates', 'flag': '🇦🇪', 'members': 48, 'status': 'Approved', 'dp': null},
    {'name': 'Pink Galaxy', 'uid': '345678', 'country': 'Pakistan', 'flag': '🇵🇰', 'members': 35, 'status': 'Approved', 'dp': null},
  ];
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _agencies.where((a) {
      final q = _query.trim().toLowerCase();
      return a['status'] == 'Approved' &&
          (q.isEmpty || a['name'].toString().toLowerCase().contains(q) || a['uid'].toString().contains(q));
    }).toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFFF1685)), onPressed: () => Navigator.pop(context)),
        centerTitle: true, title: const Text('Agency', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(38), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 4))]),
              child: Row(children: [
                const Icon(Icons.search, size: 28, color: Colors.black),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _search, onChanged: (v) => setState(() => _query = v), decoration: const InputDecoration(border: InputBorder.none, hintText: 'Search By ID Or Nick', hintStyle: TextStyle(color: Colors.black87)))),
                ElevatedButton(onPressed: () => setState(() => _query = _search.text), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC66AF0), foregroundColor: Colors.white, shape: const StadiumBorder()), child: const Text('Search')),
              ]),
            ),
          ),
          Expanded(child: visible.isEmpty
              ? const Center(child: Text('No approved agencies found'))
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 16, childAspectRatio: .83),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final a = visible[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AgencyPublicDetailScreen(agency: a))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 3))]),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 104, height: 104, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFFF1685), width: 3)), child: CircleAvatar(backgroundColor: const Color(0xFFF5E9FA), backgroundImage: a['dp'] is String ? FileImage(File(a['dp'])) : null, child: a['dp'] == null ? const Icon(Icons.business, size: 48, color: Color(0xFFC66AF0)) : null)),
                          const SizedBox(height: 14),
                          Text(a['name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(a['flag'], style: const TextStyle(fontSize: 22)), const SizedBox(width: 12), const Icon(Icons.person, color: Colors.grey, size: 22), const SizedBox(width: 5), Text('${a['members']}', style: const TextStyle(color: Colors.grey, fontSize: 16))]),
                        ]),
                      ),
                    );
                  },
                )),
        ]),
        Positioned(right: 24, bottom: 22, child: Column(children: [
          FloatingActionButton(onPressed: () async {
            final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const AgencyCreateScreen()));
            if (result != null && mounted) setState(() => _agencies.add(result));
          }, backgroundColor: const Color(0xFFC66AF0), child: const Icon(Icons.add, size: 34, color: Colors.white)),
          const SizedBox(height: 5), const Text('Create', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ])),
      ]),
    );
  }
}

class AgencyCreateScreen extends StatefulWidget {
  const AgencyCreateScreen({super.key});
  @override
  State<AgencyCreateScreen> createState() => _AgencyCreateScreenState();
}

class _AgencyCreateScreenState extends State<AgencyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _adminId = TextEditingController();
  final _picker = ImagePicker();
  String? _country;
  String? _agencyDp, _idFront, _idBack;
  bool _submitting = false;
  final List<String> _countries = const ['United Arab Emirates', 'Pakistan', 'India', 'Bangladesh', 'Angola', 'Saudi Arabia', 'United States', 'United Kingdom', 'Indonesia', 'Philippines'];

  Future<void> _pick(String type) async {
    final image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (image == null) return;
    setState(() { if (type == 'dp') _agencyDp = image.path; if (type == 'front') _idFront = image.path; if (type == 'back') _idBack = image.path; });
  }

  Widget _uploadBox(String label, String? path, VoidCallback onTap, {double height = 112}) => InkWell(
    onTap: onTap,
    child: Container(height: height, decoration: BoxDecoration(color: const Color(0xFFFFFDF5), border: Border.all(color: const Color(0xFFE5E0D5), style: BorderStyle.solid), borderRadius: BorderRadius.circular(12)),
      child: path == null ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.camera_alt, size: 48, color: Colors.black), const SizedBox(height: 5), Text(label, style: const TextStyle(color: Colors.grey))]) : ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(File(path), fit: BoxFit.cover, width: double.infinity)),
    ),
  );

  InputDecoration _decoration(String hint) => InputDecoration(hintText: hint, filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 19), border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none));
  Widget _section(String title, String subtitle) => Padding(padding: const EdgeInsets.only(top: 30, bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)), const SizedBox(height: 5), Text(subtitle, style: const TextStyle(fontSize: 15))]));

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_agencyDp == null || _idFront == null || _idBack == null || _country == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agency DP, country aur ID ke front/back images upload karein'))); return;
    }
    setState(() => _submitting = true);
    final result = {'name': _name.text.trim(), 'uid': DateTime.now().millisecondsSinceEpoch.toString().substring(7), 'country': _country!, 'flag': '🌐', 'members': 1, 'status': 'Pending', 'dp': _agencyDp, 'phone': _phone.text.trim(), 'address': _address.text.trim(), 'adminId': _adminId.text.trim(), 'idFront': _idFront, 'idBack': _idBack};
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.pop(context, result);
  }

  @override
  void dispose() { _name.dispose(); _phone.dispose(); _address.dispose(); _adminId.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F2F7),
    appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFFF1685)), onPressed: () => Navigator.pop(context)), centerTitle: true, title: const Text('Agency', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
    body: Form(key: _formKey, child: ListView(padding: const EdgeInsets.fromLTRB(18, 22, 18, 30), children: [
      Center(child: SizedBox(width: 150, child: _uploadBox('+ Upload', _agencyDp, () => _pick('dp'), height: 150))),
      _section('＊Agency name and country', 'Cannot be modified once created'),
      TextFormField(controller: _name, maxLength: 20, decoration: _decoration('No more than 20 characters').copyWith(counterText: ''), validator: (v) => v == null || v.trim().isEmpty ? 'Agency name required' : null),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(value: _country, decoration: _decoration('Chose a country'), items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _country = v), validator: (v) => v == null ? 'Country select karein' : null),
      _section('＊ID Information', 'Please upload real and valid information'),
      Row(children: [Expanded(child: Column(children: [_uploadBox('ID Front', _idFront, () => _pick('front')), const SizedBox(height: 8), const Text('ID Front', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))])), const SizedBox(width: 16), Expanded(child: Column(children: [_uploadBox('ID Back', _idBack, () => _pick('back')), const SizedBox(height: 8), const Text('ID Back', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))]))]),
      _section('Phone and Address', 'Cannot be modified once created'),
      TextFormField(controller: _phone, keyboardType: TextInputType.phone, decoration: _decoration('Phone Number'), validator: (v) => v == null || v.trim().isEmpty ? 'Phone number required' : null),
      const SizedBox(height: 12),
      TextFormField(controller: _address, maxLines: 2, decoration: _decoration('Address'), validator: (v) => v == null || v.trim().isEmpty ? 'Address required' : null),
      _section('Admin ID (Optional)', 'You can leave this field empty'),
      TextFormField(controller: _adminId, decoration: _decoration('Admin ID')),
      const SizedBox(height: 25),
      Center(child: ElevatedButton(onPressed: _submitting ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC66AF0), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 17), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(_submitting ? 'Please wait...' : 'Submit Review', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
    ])),
  );
}

class AgencyOwnerDashboardScreen extends StatelessWidget {
  final Map<String, dynamic> agency;
  const AgencyOwnerDashboardScreen({super.key, required this.agency});

  @override
  Widget build(BuildContext context) {
    final pending = agency['status'] == 'Pending';
    final items = ['Member Request', 'Member Income', 'Member Invite', 'Member active days', 'Agency data query', 'Agency Leave Request'];
    final icons = [Icons.mark_email_unread, Icons.database, Icons.person_add_alt_1, Icons.calendar_month, Icons.storage, Icons.logout];
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2F7),
      appBar: AppBar(backgroundColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFFF1685)), onPressed: () => Navigator.pop(context)), centerTitle: true, title: const Text('Agency', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700))),
      body: pending ? Center(child: Container(margin: const EdgeInsets.all(24), padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: const Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.hourglass_top, color: Color(0xFFC66AF0), size: 54), SizedBox(height: 12), Text('Agency Under Review', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Your agency has been submitted. The dashboard will be available after main admin approval.', textAlign: TextAlign.center)])))
      : ListView(children: [
        Container(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF5AA5), Color(0xFFFF0080)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(34))), child: Column(children: [
          Row(children: [CircleAvatar(radius: 29, backgroundColor: Colors.white, backgroundImage: agency['dp'] is String ? FileImage(File(agency['dp'])) : null, child: agency['dp'] == null ? const Icon(Icons.business, color: Color(0xFFC66AF0)) : null), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Name: ${agency['name']}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text('ID: ${agency['uid']}', style: const TextStyle(color: Colors.white, fontSize: 17))]))]),
          const SizedBox(height: 18), Container(width: double.infinity, padding: const EdgeInsets.all(18), decoration: BoxDecoration(border: Border.all(color: Colors.white54), borderRadius: BorderRadius.circular(16), color: Colors.white.withOpacity(.08)), child: Column(children: [const Text('Balance', style: TextStyle(color: Colors.white, fontSize: 22)), const SizedBox(height: 8), const Text('0.00 USD', style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)), const SizedBox(height: 16), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Column(children: [Text('Total Coins', style: TextStyle(color: Colors.white)), Text('0', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold))]), Column(children: [Text('Members', style: TextStyle(color: Colors.white)), Text('1', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.bold))])])]))
        ])),
        const SizedBox(height: 8),
        ...List.generate(items.length, (i) => ListTile(tileColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12), leading: Icon(icons[i], color: const Color(0xFFC66AF0), size: 31), title: Text(items[i], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)), trailing: const Icon(Icons.chevron_right, color: Color(0xFFFF1685), size: 32), onTap: () {
          final Widget page = switch (i) {
            0 => AgencyMemberRequestsScreen(agency: agency),
            1 => AgencyMemberIncomeScreen(agency: agency),
            2 => AgencyMemberInviteScreen(agency: agency),
            3 => AgencyActiveDaysScreen(agency: agency),
            4 => AgencyDataQueryScreen(agency: agency),
            _ => AgencyLeaveRequestsScreen(agency: agency),
          };
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        }))),
      ]),
    );
  }
}

// Host My Income screen. UI/demo data only; live income and leave requests
// will be connected to the backend after the Flutter workflow is complete.
class HostMyIncomeScreen extends StatefulWidget {
  const HostMyIncomeScreen({super.key});
  @override
  State<HostMyIncomeScreen> createState() => _HostMyIncomeScreenState();
}

class _HostMyIncomeScreenState extends State<HostMyIncomeScreen> {
  DateTime selectedMonth = DateTime.now();
  final int totalCoins = 133475;
  final int totalActiveDays = 12;
  final int targetCoins = 163475;
  final double surplusSalary = 150.00;
  bool leaveRequestSubmitted = false;

  int get remainingCoins => math.max(0, targetCoins - totalCoins);
  String get monthLabel => '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';

  final List<Map<String, String>> records = const [
    {'date':'2026-10-29','duration':'05H 21M','coins':'12,500','days':'1'},
    {'date':'2026-10-28','duration':'04H 12M','coins':'18,200','days':'1'},
    {'date':'2026-10-27','duration':'06H 05M','coins':'9,750','days':'1'},
    {'date':'2026-10-26','duration':'03H 45M','coins':'15,000','days':'1'},
    {'date':'2026-10-25','duration':'07H 10M','coins':'21,300','days':'1'},
    {'date':'2026-10-24','duration':'02H 55M','coins':'8,400','days':'1'},
  ];

  void _changeMonth(int delta) {
    setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + delta, 1));
  }

  Future<void> _requestAgencyLeave() async {
    if (leaveRequestSubmitted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your agency leave request is already pending.')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Leave Agency?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('If you leave the agency, your target progress may be lost. Do you want to send an agency leave request?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCEL')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE83E91), foregroundColor: Colors.white), onPressed: () => Navigator.pop(dialogContext, true), child: const Text('CONFIRM LEAVE')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      setState(() => leaveRequestSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agency leave request submitted. Your membership and target remain unchanged until the owner approves.')));
    }
  }

  Widget _mCoin({double size = 18}) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFFFD66B), Color(0xFFFFA51F)])),
    alignment: Alignment.center,
    child: Text('M', style: TextStyle(color: Colors.white, fontSize: size * .58, fontWeight: FontWeight.w900)),
  );

  Widget _summaryCard(String label, String value, {bool coin = false}) => Expanded(
    child: Container(padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 8), decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(14)), child: Column(children: [
      Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 7),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [if (coin) ...[_mCoin(size: 20), const SizedBox(width: 5)], Flexible(child: Text(value, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)))])
    ])),
  );

  @override
  Widget build(BuildContext context) {
    final progress = targetCoins <= 0 ? 0.0 : (totalCoins / targetCoins).clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF4F3F7),
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Color(0xFFE83E91)), onPressed: () => Navigator.pop(context)),
        title: const Text('My Income', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), centerTitle: true,
        actions: [Padding(padding: const EdgeInsets.only(right: 10), child: Center(child: TextButton(onPressed: _requestAgencyLeave, style: TextButton.styleFrom(backgroundColor: const Color(0xFFFFE4F0), foregroundColor: const Color(0xFFE83E91), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)), child: Text(leaveRequestSubmitted ? 'Request Sent' : 'Agency Leave', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))))],
      ),
      body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Container(padding: const EdgeInsets.fromLTRB(16, 14, 16, 22), decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFFF6BAE), Color(0xFFE83E91)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left, color: Colors.white)), Text(monthLabel, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right, color: Colors.white))]),
          Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white.withOpacity(.16), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white.withOpacity(.3))), child: Column(children: [const Text('Surplus Salary', style: TextStyle(color: Colors.white, fontSize: 17)), const SizedBox(height: 5), Text('\$${surplusSalary.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 31, fontWeight: FontWeight.w800)), const SizedBox(height: 14), Row(children: [_summaryCard('Total Coins', totalCoins.toString(), coin: true), const SizedBox(width: 10), _summaryCard('Total Active Days', '$totalActiveDays Days')])])),
        ])),
        Container(margin: const EdgeInsets.fromLTRB(14, 16, 14, 12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 7)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Achieve the target to need coins:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF34313A))),
          const SizedBox(height: 9), Row(children: [_mCoin(size: 23), const SizedBox(width: 8), Text(remainingCoins.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFE83E91))), const Spacer(), Text('${(progress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF77717D)))]),
          const SizedBox(height: 9), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: const Color(0xFFF4DCE8), valueColor: const AlwaysStoppedAnimation(Color(0xFFE83E91)))),
        ])),
        Container(color: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 5), child: const Row(children: [Expanded(flex: 3, child: Text('DATE', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), Expanded(flex: 2, child: Text('DURATION', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))), Expanded(flex: 2, child: Text('COINS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))), Expanded(flex: 2, child: Text('VALID DAYS', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)))])),
        ...records.map((r) => Container(color: records.indexOf(r).isEven ? const Color(0xFFE8E7EA) : Colors.white, padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 5), child: Row(children: [Expanded(flex: 3, child: Text(r['date']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))), Expanded(flex: 2, child: Text(r['duration']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))), Expanded(flex: 2, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [_mCoin(size: 16), const SizedBox(width: 4), Flexible(child: Text(r['coins']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))])), Expanded(flex: 2, child: Text(r['days']!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)))]))),
      ]),
    );
  }
}

// Agency dashboard sub-screens. Local demo UI only; backend integration later.
const Color _agencyPink = Color(0xFFFF1685);
const Color _agencyPurple = Color(0xFFC66AF0);
const Color _agencyBg = Color(0xFFF3F2F7);
PreferredSizeWidget _agencyBar(BuildContext c, String title) => AppBar(
  backgroundColor: Colors.white, elevation: 0, centerTitle: true,
  leading: IconButton(icon: const Icon(Icons.arrow_back, color: _agencyPink), onPressed: () => Navigator.pop(c)),
  title: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
);
Widget _agencyBtn(String label, VoidCallback tap) => ElevatedButton(
  onPressed: tap, style: ElevatedButton.styleFrom(backgroundColor: _agencyPurple, foregroundColor: Colors.white, shape: const StadiumBorder()), child: Text(label));
void _agencyToast(BuildContext c, String text) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(text)));

class AgencyMemberRequestsScreen extends StatefulWidget {
  final Map<String,dynamic> agency; const AgencyMemberRequestsScreen({super.key,required this.agency});
  @override State<AgencyMemberRequestsScreen> createState()=>_AgencyMemberRequestsScreenState();
}
class _AgencyMemberRequestsScreenState extends State<AgencyMemberRequestsScreen>{
  final rows=List.generate(5,(i)=>{'name':['Hori ♛','Mindo Star','Royal Host','Luna','Ayesha'][i],'id':['179121','284512','391820','451209','562310'][i]});
  void decide(int i,bool accept){setState(()=>rows.removeAt(i));_agencyToast(context,accept?'Member request accepted (demo).':'Member request rejected (demo).');}
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Member Requests'),body:ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Container(color:Colors.white,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),child:Row(children:[const CircleAvatar(radius:30,child:Icon(Icons.person)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['name']!,style:const TextStyle(fontSize:18)),Text('ID: ${r['id']}')])),_agencyBtn('Agree',()=>decide(i,true)),IconButton(onPressed:()=>decide(i,false),icon:const Icon(Icons.close,color:_agencyPink,size:30))]));}));
}

class AgencyMemberIncomeScreen extends StatefulWidget {
 final Map<String,dynamic> agency; const AgencyMemberIncomeScreen({super.key,required this.agency});
 @override State<AgencyMemberIncomeScreen> createState()=>_AgencyMemberIncomeScreenState();
}
class _AgencyMemberIncomeScreenState extends State<AgencyMemberIncomeScreen>{
 String month='2026-10',duration='Monthly';
 final rows=List.generate(10,(i)=>{'name':['Hori ♛','Mindo Star','Royal Host','Luna'][i%4],'id':['179121','284512','391820','451209'][i%4],'coins':['2292.3','18500','76400','125000'][i%4],'salary':['0.00','12.00','35.00','50.00'][i%4],'commission':['0.00','1.20','3.50','5.00'][i%4]});
 @override Widget build(BuildContext c){final total=rows.fold<double>(0,(v,r)=>v+(double.tryParse(r['coins']!)??0));return Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Member Income'),body:Column(children:[Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:const BoxDecoration(gradient:LinearGradient(colors:[Color(0xFFFF5AA5),Color(0xFFFF0080)]),borderRadius:BorderRadius.vertical(bottom:Radius.circular(30))),child:Column(children:[DropdownButton<String>(value:month,dropdownColor:_agencyPurple,underline:const SizedBox(),items:List.generate(6,(i){final d=DateTime(2026,10-i);final v='${d.year}-${d.month.toString().padLeft(2,'0')}';return DropdownMenuItem(value:v,child:Text(v,style:const TextStyle(color:Colors.white)));}),onChanged:(v)=>setState(()=>month=v!)),Row(children:[Expanded(child:_metric('Monthly Coins',total.toStringAsFixed(2))),Container(width:1,height:55,color:Colors.white54),Expanded(child:_metric('Estimated Salary','\$50.00'))]),const SizedBox(height:12),Chip(label:Text('Target Duration: $duration'),backgroundColor:Colors.white),const Text('Target duration and salary rules are controlled by Main Admin',style:TextStyle(color:Colors.white70,fontSize:11))])),Container(color:Colors.white,padding:const EdgeInsets.symmetric(vertical:14,horizontal:3),child:const Row(children:[Expanded(flex:3,child:Text('HOST',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold))),Expanded(flex:2,child:Text('TOTAL COINS',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),Expanded(child:Text('SALARY',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:11))),Expanded(child:Text('COMMISSION',textAlign:TextAlign.center,style:TextStyle(fontWeight:FontWeight.bold,fontSize:10)))])),Expanded(child:ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Container(color:i.isEven?const Color(0xFFE5E5E5):Colors.white,padding:const EdgeInsets.symmetric(vertical:13,horizontal:4),child:Row(children:[Expanded(flex:3,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['name']!),Text('ID: ${r['id']}') ])),Expanded(flex:2,child:Text(r['coins']!,textAlign:TextAlign.center)),Expanded(child:Text('\$${r['salary']}',textAlign:TextAlign.center)),Expanded(child:Text('\$${r['commission']}',textAlign:TextAlign.center))]));}))]));}
 Widget _metric(String t,String v)=>Column(children:[Text(t,textAlign:TextAlign.center,style:const TextStyle(color:Colors.white,fontSize:17)),Text(v,style:const TextStyle(color:Colors.white,fontSize:22,fontWeight:FontWeight.bold))]);
}

class AgencyMemberInviteScreen extends StatefulWidget {final Map<String,dynamic> agency;const AgencyMemberInviteScreen({super.key,required this.agency});@override State<AgencyMemberInviteScreen> createState()=>_AgencyMemberInviteScreenState();}
class _AgencyMemberInviteScreenState extends State<AgencyMemberInviteScreen>{final id=TextEditingController();bool found=false;@override void dispose(){id.dispose();super.dispose();}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Member Invite'),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[TextField(controller:id,keyboardType:TextInputType.number,decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search by User ID',filled:true,fillColor:Colors.white,border:OutlineInputBorder(borderRadius:BorderRadius.circular(30),borderSide:BorderSide.none))),const SizedBox(height:14),SizedBox(width:double.infinity,child:_agencyBtn('Search',(){setState(()=>found=id.text.trim().isNotEmpty);if(!found)_agencyToast(c,'User ID enter karein.');})),if(found)...[const SizedBox(height:24),Container(color:Colors.white,padding:const EdgeInsets.all(18),child:Row(children:[const CircleAvatar(child:Icon(Icons.person)),const SizedBox(width:12),Expanded(child:Text('User ID: ${id.text}\nDemo User',style:const TextStyle(fontSize:17)))])),const SizedBox(height:16),SizedBox(width:double.infinity,child:_agencyBtn('Send Invitation',()=>_agencyToast(c,'Invitation sent. Default validity 24 hours; Main Admin can change expiry.')))] ])));}

class AgencyActiveDaysScreen extends StatefulWidget {final Map<String,dynamic> agency;const AgencyActiveDaysScreen({super.key,required this.agency});@override State<AgencyActiveDaysScreen> createState()=>_AgencyActiveDaysScreenState();}
class _AgencyActiveDaysScreenState extends State<AgencyActiveDaysScreen>{String range='This Week';final rows=List.generate(12,(i)=>{'name':['Hori ♛','Mindo Star','Royal Host'][i%3],'id':['179121','284512','391820'][i%3],'days':'${i%6+1}','time':['05H21M','12H40M','02H15M'][i%3]});@override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Member Active Days'),body:Column(children:[Container(color:_agencyPink,padding:const EdgeInsets.all(15),alignment:Alignment.centerRight,child:DropdownButton<String>(value:range,underline:const SizedBox(),dropdownColor:_agencyPurple,items:['Today','This Week','This Month','Last 7 Days','Last 30 Days'].map((v)=>DropdownMenuItem(value:v,child:Text(v,style:const TextStyle(color:Colors.white)))).toList(),onChanged:(v)=>setState(()=>range=v!))),Container(color:Colors.white,padding:const EdgeInsets.all(15),child:const Row(children:[Expanded(child:Text('Anchor',textAlign:TextAlign.center)),Expanded(child:Text('Valid Days',textAlign:TextAlign.center)),Expanded(child:Text('Valid Time',textAlign:TextAlign.center))])),Expanded(child:ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Container(color:i.isEven?const Color(0xFFC8C8C8):Colors.white,padding:const EdgeInsets.all(14),child:Row(children:[Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['name']!),Text('ID: ${r['id']}')])),Expanded(child:Text(r['days']!,textAlign:TextAlign.center)),Expanded(child:Text(r['time']!,textAlign:TextAlign.center))]));}))]));}

class AgencyDataQueryScreen extends StatefulWidget {final Map<String,dynamic> agency;const AgencyDataQueryScreen({super.key,required this.agency});@override State<AgencyDataQueryScreen> createState()=>_AgencyDataQueryScreenState();}
class _AgencyDataQueryScreenState extends State<AgencyDataQueryScreen>{DateTime? start,end;bool show=false;Future<void> pick(bool first)async{final now=DateTime.now();final d=await showDatePicker(context:context,initialDate:first?(start??now):(end??now),firstDate:DateTime(now.year,now.month-2,1),lastDate:now);if(d!=null)setState((){if(first)start=d;else end=d;show=false;});}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Agency Database'),body:ListView(children:[Container(color:Colors.white,padding:const EdgeInsets.all(20),child:Column(children:[Container(width:double.infinity,padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:const Color(0xFF00D8D0),borderRadius:BorderRadius.circular(8)),child:const Text('Only the data of the past two months can be queried',textAlign:TextAlign.center,style:TextStyle(fontSize:17))),const SizedBox(height:25),_date('Time of Start',start,()=>pick(true)),const SizedBox(height:15),_date('End Time',end,()=>pick(false)),const SizedBox(height:20),_agencyBtn('Get Data',(){if(start==null||end==null||end!.isBefore(start!)){_agencyToast(c,'Please select a valid date range.');return;}if(start!.isBefore(DateTime.now().subtract(const Duration(days:62)))){_agencyToast(c,'Only last two months are available to agency owners.');return;}setState(()=>show=true);})])),if(show)Container(color:Colors.white,margin:const EdgeInsets.only(top:24),padding:const EdgeInsets.all(20),child:Column(children:[const Text('Search Results',style:TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const Text('13347.5',style:TextStyle(fontSize:30,fontWeight:FontWeight.bold)),const Text('Coins'),const Divider(),...List.generate(5,(i)=>ListTile(title:Text(['Hori ♛','Mindo Star','Royal Host','Luna','Ayesha'][i]),subtitle:Text('ID: ${179121+i}'),trailing:Text(['2292.3','3100','2750','2900','2305.2'][i])))]))]));}
Widget _date(String label,DateTime? d,VoidCallback tap)=>Row(children:[Expanded(child:Text(label,style:const TextStyle(fontSize:17))),InkWell(onTap:tap,child:Container(width:185,padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:_agencyBg,borderRadius:BorderRadius.circular(28)),child:Text(d==null?'Select date':'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}')))]);

class AgencyLeaveRequestsScreen extends StatefulWidget {final Map<String,dynamic> agency;const AgencyLeaveRequestsScreen({super.key,required this.agency});@override State<AgencyLeaveRequestsScreen> createState()=>_AgencyLeaveRequestsScreenState();}
class _AgencyLeaveRequestsScreenState extends State<AgencyLeaveRequestsScreen>{final rows=List.generate(5,(i)=>{'name':['Hori ♛','Mindo Star','Royal Host','Luna','Ayesha'][i],'id':['179121','284512','391820','451209','562310'][i]});void decide(int i,bool ok){setState(()=>rows.removeAt(i));_agencyToast(context,ok?'Agency leave approved (demo).':'Agency leave rejected (demo).');}@override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Member Leave Requests'),body:ListView.builder(itemCount:rows.length,itemBuilder:(c,i){final r=rows[i];return Container(color:Colors.white,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(14),child:Row(children:[const CircleAvatar(radius:30,child:Icon(Icons.person)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(r['name']!,style:const TextStyle(fontSize:18)),Text('ID: ${r['id']}')])),_agencyBtn('Agree',()=>decide(i,true)),IconButton(onPressed:()=>decide(i,false),icon:const Icon(Icons.close,color:_agencyPink,size:30))]));}));}


class AgencyPublicDetailScreen extends StatelessWidget {
  final Map<String,dynamic> agency;
  const AgencyPublicDetailScreen({super.key,required this.agency});
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:_agencyBg,appBar:_agencyBar(c,'Agency'),body:Center(child:Container(margin:const EdgeInsets.all(24),padding:const EdgeInsets.all(24),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(22),boxShadow:const [BoxShadow(color:Color(0x22000000),blurRadius:12)]),child:Column(mainAxisSize:MainAxisSize.min,children:[CircleAvatar(radius: 60,backgroundColor:const Color(0xFFFCE3F1),backgroundImage:agency['dp'] is String?FileImage(File(agency['dp'])):null,child:agency['dp']==null?const Icon(Icons.business,size:55,color:_agencyPurple):null),const SizedBox(height:18),Text('${agency['name']}',style:const TextStyle(fontSize:24,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text('${agency['flag']??'🌐'}  ${agency['country']}'),Text('Agency ID: ${agency['uid']}'),Text('Members: ${agency['members']}'),const SizedBox(height:24),SizedBox(width:double.infinity,child:_agencyBtn('Join',()=>_agencyToast(c,'Joining request sent to agency owner. Pending requests expire after the Main Admin configured duration (default 24 hours).'))),const SizedBox(height:8),const Text('One account can join only one agency.',style:TextStyle(color:Colors.grey))]))));
}
