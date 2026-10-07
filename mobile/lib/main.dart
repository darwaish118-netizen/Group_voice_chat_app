import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl =
    'https://group-voice-chat-app.onrender.com';

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
    String birthday,
  ) async {
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
        'Email and password required',
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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child:
              SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              children: [
                const Icon(
                  Icons.mic,
                  size: 80,
                  color:
                      Colors.deepPurple,
                ),
                const SizedBox(
                  height: 20,
                ),
                const Text(
                  'Group Voice Chat',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                const Text(
                  'Talk • Meet • Connect',
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(
                  height: 40,
                ),
                TextField(
                  controller:
                      emailController,
                  keyboardType:
                      TextInputType
                          .emailAddress,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(
                      Icons
                          .email_outlined,
                    ),
                    border:
                        OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 16,
                ),
                TextField(
                  controller:
                      passwordController,
                  obscureText:
                      obscure,
                  decoration:
                      InputDecoration(
                    labelText:
                        'Password',
                    prefixIcon:
                        const Icon(
                      Icons
                          .lock_outline,
                    ),
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
                                .visibility
                            : Icons
                                .visibility_off,
                      ),
                    ),
                    border:
                        const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(
                  height: 24,
                ),
                SizedBox(
                  width:
                      double.infinity,
                  height: 52,
                  child:
                      ElevatedButton(
                    onPressed:
                        loading
                            ? null
                            : login,
                    child: loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'LOGIN',
                            style:
                                TextStyle(
                              fontWeight:
                                  FontWeight
                                      .bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(
                  height: 15,
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
                  child:
                      const Text(
                    'Create new account',
                  ),
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

  bool loading = false;

  Future<void> register() async {
    final name =
        nameController.text.trim();

    final email =
        emailController.text.trim();

    final password =
        passwordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      showMessage(
        'Please fill all fields',
      );
      return;
    }

    if (password.length < 6) {
      showMessage(
        'Password must be at least 6 characters',
      );
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final data =
          await api.register(
        name,
        email,
        password,
      );

      final token =
          data['token']?.toString();

      if (token == null ||
          token.isEmpty) {
        throw Exception(
          'Registration successful but token missing',
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

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HomeScreen(
            token: token,
          ),
        ),
        (route) => false,
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

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create Account',
        ),
      ),
      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(
                height: 20,
              ),
              const Icon(
                Icons.person_add,
                size: 70,
                color:
                    Colors.deepPurple,
              ),
              const SizedBox(
                height: 25,
              ),
              TextField(
                controller:
                    nameController,
                decoration:
                    const InputDecoration(
                  labelText: 'Name',
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
                height: 16,
              ),
              TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType
                        .emailAddress,
                decoration:
                    const InputDecoration(
                  labelText: 'Email',
                  prefixIcon:
                      Icon(
                    Icons
                        .email_outlined,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 16,
              ),
              TextField(
                controller:
                    passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(
                  labelText:
                      'Password',
                  prefixIcon:
                      Icon(
                    Icons
                        .lock_outline,
                  ),
                  border:
                      OutlineInputBorder(),
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              SizedBox(
                width:
                    double.infinity,
                height: 52,
                child:
                    ElevatedButton(
                  onPressed:
                      loading
                          ? null
                          : register,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text(
                          'CREATE ACCOUNT',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight
                                    .bold,
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

    final name =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Create Voice Room',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration:
                const InputDecoration(
              labelText:
                  'Room name',
              hintText:
                  'Example: Friends Chat',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child:
                  const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text
                      .trim(),
                );
              },
              child:
                  const Text('Create'),
            ),
          ],
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
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
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
          // LEVEL / UID / VIP
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
                    'Level',
                  ),
                  Container(
                    width: 1,
                    height: 35,
                    color: Colors.grey.shade300,
                  ),
                  statItem(
                    uid.isEmpty
                        ? '------'
                        : uid,
                    'UID',
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
          // EDIT PROFILE
          // ======================================================

          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: openEditProfile,
              icon: const Icon(
                Icons.edit,
              ),
              label: const Text(
                'Edit Profile',
              ),
            ),
          ),

          const SizedBox(
            height: 15,
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
            'Level',
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

  String currentAvatarUrl = '';

  final ImagePicker _picker =
      ImagePicker();

  XFile? selectedImage;

  bool saving = false;

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

      Navigator.pop(
        context,
        Map<String, dynamic>.from(
          updatedUser,
        ),
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

  final List<String> speakers = [
    'Host',
    'Speaker 1',
    'Speaker 2',
    'Speaker 3',
    'Speaker 4',
    'Speaker 5',
    'Speaker 6',
    'Speaker 7',
  ];

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
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.share,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(
            height: 20,
          ),
          const Text(
            'VOICE ROOM',
            style: TextStyle(
              color: Colors.white70,
              letterSpacing: 2,
              fontWeight:
                  FontWeight.bold,
            ),
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
                crossAxisCount: 4,
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
                  icon: Icons
                      .card_giftcard,
                  label: 'Gift',
                  onTap: () {
                    showDialog(
                      context:
                          context,
                      builder: (_) {
                        return AlertDialog(
                          title:
                              const Text(
                            'Send Gift',
                          ),
                          content:
                              const Text(
                            'Gift system will be connected here.',
                          ),
                          actions: [
                            TextButton(
                              onPressed:
                                  () {
                                Navigator.pop(
                                  context,
                                );
                              },
                              child:
                                  const Text(
                                'OK',
                              ),
                            ),
                          ],
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
                _roomButton(
                  icon:
                      Icons.call_end,
                  label: 'Leave',
                  danger: true,
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                  },
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
      child: Column(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor:
                danger
                    ? Colors.red
                    : active
                        ? Colors.green
                        : Colors.white12,
            child: Icon(
              icon,
              color: Colors.white,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            label,
            style:
                const TextStyle(
              color:
                  Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
