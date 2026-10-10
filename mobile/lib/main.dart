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
    String name,
  ) async {
    final response = await http.post(
      Uri.parse(
        '$apiBaseUrl/api/rooms',
      ),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
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
    final prefs =
        await SharedPreferences
            .getInstance();

    final savedToken =
        prefs.getString('token');

    if (!mounted) return;

    setState(() {
      token = savedToken;
      loading = false;
    });
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
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF8FD),
              Color(0xFFF4ECFA),
              Color(0xFFEDE4F7),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.fromLTRB(
              24,
              28,
              24,
              30,
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // MINDO VOICE CHAT logo area
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(
                      0xFFE8D7F8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple
                            .withOpacity(0.12),
                        blurRadius: 20,
                        offset:
                            const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.mic_rounded,
                    size: 54,
                    color: Color(0xFF6D35B8),
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'MINDO',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight:
                        FontWeight.w900,
                    letterSpacing: 2,
                    color:
                        Color(0xFF24162D),
                  ),
                ),

                const Text(
                  'VOICE CHAT',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.w700,
                    letterSpacing: 3,
                    color:
                        Color(0xFF6D35B8),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Talk • Meet • Connect',
                  style: TextStyle(
                    color: Color(0xFF8E8795),
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 30),

                // Social login buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () =>
                                socialLogin(
                                  'Google',
                                ),
                        icon: const Icon(
                          Icons
                              .g_mobiledata_rounded,
                          size: 27,
                        ),
                        label: const Text(
                          'Google',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFF302936,
                          ),
                          backgroundColor:
                              Colors.white
                                  .withOpacity(
                            0.86,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Color(0xFFE0D8E8),
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 15,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: loading
                            ? null
                            : () =>
                                socialLogin(
                                  'Facebook',
                                ),
                        icon: const Icon(
                          Icons.facebook_rounded,
                          size: 23,
                        ),
                        label: const Text(
                          'Facebook',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(
                            0xFF302936,
                          ),
                          backgroundColor:
                              Colors.white
                                  .withOpacity(
                            0.86,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Color(0xFFE0D8E8),
                          ),
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            vertical: 15,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    const Expanded(
                      child: Divider(
                        color:
                            Color(0xFFD6CDD9),
                      ),
                    ),
                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 14,
                      ),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color:
                              Colors.grey.shade600,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color:
                            Color(0xFFD6CDD9),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Align(
                  alignment:
                      Alignment.centerLeft,
                  child: const Text(
                    'Login to your account',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(0xFF24162D),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller:
                      emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  decoration:
                      fieldDecoration(
                    hint: 'Email or Phone',
                    icon:
                        Icons.person_outline,
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller:
                      passwordController,
                  obscureText: obscure,
                  decoration:
                      fieldDecoration(
                    hint: 'Password',
                    icon:
                        Icons.lock_outline_rounded,
                    suffixIcon:
                        IconButton(
                      onPressed: () {
                        setState(() {
                          obscure =
                              !obscure;
                        });
                      },
                      icon: Icon(
                        obscure
                            ? Icons
                                .visibility_rounded
                            : Icons
                                .visibility_off_rounded,
                        color: const Color(
                          0xFF5F2DB8,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Align(
                  alignment:
                      Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      showMessage(
                        'Password reset will be connected next.',
                      );
                    },
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(
                        color:
                            Color(0xFF6D35B8),
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        loading ? null : login,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(
                        0xFFD34C9A,
                      ),
                      foregroundColor:
                          Colors.white,
                      elevation: 3,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),
                    ),
                    child: loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'LOGIN',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Don't have an account? ",
                      style: TextStyle(
                        color:
                            Color(0xFF746D78),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const RegisterScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Register Now',
                        style: TextStyle(
                          color:
                              Color(0xFF6D35B8),
                          fontWeight:
                              FontWeight.w800,
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

  @override
  Widget build(BuildContext context) {
    ImageProvider<Object>? avatarImage;

    if (selectedImage != null) {
      avatarImage = FileImage(
        File(selectedImage!.path),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            children: [
              GestureDetector(
                onTap: loading ? null : showImageOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 58,
                      backgroundColor: const Color(0xFFEDE3F8),
                      backgroundImage: avatarImage,
                      child: avatarImage == null
                          ? const Icon(
                              Icons.person,
                              size: 58,
                              color: Colors.deepPurple,
                            )
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: const BoxDecoration(
                          color: Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Add Profile Photo',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: countries.contains(country) ? country : null,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  prefixIcon: Icon(Icons.public),
                  border: OutlineInputBorder(),
                ),
                items: countries.map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: loading
                    ? null
                    : (value) {
                        setState(() {
                          country = value ?? '';
                        });
                      },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: genders.contains(gender) ? gender : null,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.wc),
                  border: OutlineInputBorder(),
                ),
                items: genders.map((value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: loading
                    ? null
                    : (value) {
                        setState(() {
                          gender = value ?? '';
                        });
                      },
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: loading ? null : pickBirthday,
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Birthday',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    birthday.isEmpty ? 'Select your birthday' : birthday,
                    style: TextStyle(
                      color: birthday.isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : register,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'CREATE ACCOUNT',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
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
    'Friends',
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
      const FriendsScreen(),
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
      bottomNavigationBar:
          NavigationBar(
        selectedIndex:
            selectedIndex,
        onDestinationSelected:
            (index) {
          setState(() {
            selectedIndex =
                index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.groups_outlined,
            ),
            selectedIcon:
                Icon(Icons.groups),
            label: 'Rooms',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.people_outline,
            ),
            selectedIcon:
                Icon(Icons.people),
            label: 'Friends',
          ),
          NavigationDestination(
            icon: Icon(
              Icons.person_outline,
            ),
            selectedIcon:
                Icon(Icons.person),
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

    if (name == null ||
        name.isEmpty) {
      return;
    }

    try {
      await api.createRoom(
        widget.token,
        name,
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
                            backgroundColor:
                                Colors
                                    .deepPurple
                                    .shade100,
                            child:
                                const Icon(
                              Icons.mic,
                              color: Colors
                                  .deepPurple,
                            ),
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
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        VoiceRoomScreen(
                                  roomId:
                                      id,
                                  roomName:
                                      name,
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

    return RefreshIndicator(
      onRefresh: loadProfile,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          16,
          20,
          16,
          30,
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
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (flag.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 21),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'UID: ',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  uid.isEmpty ? '------' : uid,
                  style: const TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
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
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Row(
                children: [
                  statItem(
                    'Lv.${user?['level'] ?? 1}',
                    'Wealth Level',
                  ),
                  Container(
                    width: 1,
                    height: 35,
                    color: Colors.grey.shade300,
                  ),
                  statItem(
                    'Lv.1',
                    'Charm Level',
                  ),
                  Container(
                    width: 1,
                    height: 35,
                    color: Colors.grey.shade300,
                  ),
                  statItem(
                    'VIP 0',
                    'VIP',
                  ),
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

          profileAction(
            Icons.account_balance_wallet,
            'Wallet',
          ),

          profileAction(
            Icons.shopping_bag,
            'Mall',
          ),

          profileAction(
            Icons.star,
            'Wealth Level',
          ),

          profileAction(
            Icons.workspace_premium,
            'VIP',
          ),

          profileAction(
            Icons.military_tech,
            'HONOR',
          ),

          profileAction(
            Icons.business,
            'My Agency',
          ),

          profileAction(
            Icons.attach_money,
            'My Income',
          ),

          profileAction(
            Icons.feedback_outlined,
            'Feedback',
          ),

          profileAction(
            Icons.settings,
            'Settings',
          ),

          const SizedBox(
            height: 8,
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
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
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
                    const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon:
                      Icon(Icons.person),
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

// ============================================================
// VOICE ROOM UI
// ============================================================

class VoiceRoomScreen
    extends StatefulWidget {
  final String roomId;
  final String roomName;
  final int seatCount;

  const VoiceRoomScreen({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.seatCount,
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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF211A35),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF211A35),
        foregroundColor:
            Colors.white,
        title: Text(
          widget.roomName,
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

                return Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor:
                          Colors
                              .deepPurple
                              .shade300,
                      child:
                          const Icon(
                        Icons.person,
                        color:
                            Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(
                      height: 7,
                    ),
                    Text(
                      speaker,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 20,
              vertical: 15,
            ),
            decoration:
                const BoxDecoration(
              color:
                  Color(0xFF171225),
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  25,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment
                      .spaceEvenly,
              children: [
                _roomButton(
                  icon: microphoneOn
                      ? Icons.mic
                      : Icons.mic_off,
                  label: 'Mic',
                  active:
                      microphoneOn,
                  onTap: () {
                    setState(() {
                      microphoneOn =
                          !microphoneOn;
                    });
                  },
                ),
                  _roomButton(
  icon: Icons.settings_outlined,
  label: 'Room Setting',
  onTap: () {
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
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Room Setting',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 15),
                ListTile(
                  leading: const Icon(
                    Icons.event_seat_outlined,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Seat Setting',
                    style: TextStyle(
                      color: Colors.white,
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
),
                
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    // Game icon — Gift ke bilkul upar
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      child: const Icon(
        Icons.sports_esports,
        color: Colors.white,
        size: 32,
      ),
    ),

    const SizedBox(height: 8),

    // Gift icon — neeche
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
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      },
      child: const Icon(
        Icons.card_giftcard,
        color: Colors.white,
        size: 32,
      ),
    ),
  ],
),
                  
                _roomButton(
                  icon: Icons.event_seat_outlined,
                  label: 'Seat',
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
                        return SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Choose Seat Count',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ...[5, 10, 15, 20, 25].map(
                                  (count) => ListTile(
                                    leading: const Icon(
                                      Icons.event_seat,
                                      color: Colors.white,
                                    ),
                                    title: Text(
                                      '$count Seats',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '$count seats selected',
                                          ),
                                        ),
                                      );
                                    },
                                  ),
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
    icon: Icons.emoji_emotions_outlined,
    label: 'Emoji',
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
                  physics: const NeverScrollableScrollPhysics(),
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
                        final selectedEmoji = emojis[index];
                        Navigator.pop(sheetContext);

                        ScaffoldMessenger.of(this.context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              'Selected $selectedEmoji',
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
                  icon: Icons
                      .chat_bubble_outline,
                  label: 'Chat',
                  onTap: () {},
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
              ? Colors.green
              : Colors.white,
      size: 28,
    ),
  );
}
