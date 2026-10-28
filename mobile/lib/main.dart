import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

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
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
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
    String label,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
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
        6,
        10,
        4,
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
            height: 12,
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

const SizedBox(height: 4),

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
            height: 14,
          ),

          // ======================================================
          // WEALTH / CHARM / VIP
          // ======================================================

Card(
  color: Colors.transparent,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  child: Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 16,
      horizontal: 8,
    ),
    child: Row(
      children: [
        statItem('Lv.${user?['level'] ?? 1}', 'Wealth Level'),
        Container(
          width: 1,
          height: 35,
          color: Colors.white24,
        ),
        statItem('Lv.1', 'Charm Level'),
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
            height: 10,
          ),
            
 // ======================================================
// SOCIAL STATS
// ======================================================

Card(
  color: Colors.transparent,
  elevation: 0,
  surfaceTintColor: Colors.transparent,
  child: Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 16,
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
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Following',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
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
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Fans',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
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
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Gift Received',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
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
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Gift Sent',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
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
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Visits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey,
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
final buttonSize = (wheelWidth * 0.125).clamp(40.0, 46.0);
final centerSize = (wheelWidth * 0.16).clamp(52.0, 60.0);

// Wheel alignment
final sideInset = wheelWidth * 0.035;
final leftSide = sideInset;
final rightSide = wheelWidth - buttonSize - sideInset;
final middleSide = (wheelWidth - buttonSize) / 2;
    Widget wheelButton(
      IconData icon,
      String title,
      double left,
      double top,
    ) {
      return Positioned(
        left: left,
        top: top,
        width: buttonSize,
        height: buttonSize,
        child: GestureDetector(
          onTap: () => openComingSoon(title),
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
                  padding: const EdgeInsets.symmetric(horizontal: 2),
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
      height: 220,
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
                    color: const Color(0xFFFFB52E).withOpacity(0.65),
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

wheelButton(Icons.account_balance_wallet, 'Wallet', middleSide, 0),
wheelButton(Icons.shopping_bag, 'Mall', rightSide, 30),
wheelButton(Icons.star, 'Wealth Level', rightSide, 85),
wheelButton(Icons.military_tech, 'HONOR', rightSide, 140),
wheelButton(Icons.business, 'My Agency', middleSide, 175),
wheelButton(Icons.attach_money, 'My Income', leftSide, 140),
wheelButton(Icons.feedback, 'Feedback', leftSide, 85),
wheelButton(Icons.settings, 'Settings', leftSide, 30),

          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: GestureDetector(
                onTap: () => openComingSoon('VIP'),
                child: Container(
                  width: centerSize,
                  height: centerSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xFFFFD12A),
                        Color(0xFFFF2106),
                        Color(0xFF0B0314),
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
          ),
        ],
      ),
    );
  },
),

const SizedBox(height: 4),

          const SizedBox(
            height: 2,
          ),

          // ======================================================
          // LOGOUT
          // ======================================================

          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: confirmLogout,
              icon: const Icon(
                Icons.logout,
              ),
              label: const Text(
                'Logout',
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
        title: const Text('Profile'),
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
