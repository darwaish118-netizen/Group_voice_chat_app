import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String apiBaseUrl = 'http://10.0.2.2:4000';

void main() {
  runApp(const VoiceChatApp());
}

class VoiceChatApp extends StatelessWidget {
  const VoiceChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Chat App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
      ),
      home: const AuthGate(),
    );
  }
}

// ================= API SERVICE =================

class ApiService {
  Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$apiBaseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
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
      Uri.parse('$apiBaseUrl/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  Future<List<dynamic>> getRooms(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/rooms'),
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
      Uri.parse('$apiBaseUrl/api/rooms'),
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

  Future<Map<String, dynamic>> me(String token) async {
    final response = await http.get(
      Uri.parse('$apiBaseUrl/api/me'),
      headers: {
        'Authorization': 'Bearer $token',
      },
    );

    return _handleResponse(response);
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final data = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(data['error'] ?? 'Something went wrong');
  }
}

final api = ApiService();

// ================= AUTH GATE =================

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool loading = true;
  String? token;

  @override
  void initState() {
    super.initState();
    checkLogin();
  }

  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');

    setState(() {
      token = savedToken;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (token == null) {
      return LoginScreen(
        onLogin: (newToken) async {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', newToken);

          setState(() {
            token = newToken;
          });
        },
      );
    }

    return HomeScreen(
      token: token!,
      onLogout: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('token');

        setState(() {
          token = null;
        });
      },
    );
  }
}

// ================= LOGIN =================

class LoginScreen extends StatefulWidget {
  final Function(String token) onLogin;

  const LoginScreen({
    super.key,
    required this.onLogin,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    if (emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('Email and password required');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await api.login(
        emailController.text.trim(),
        passwordController.text,
      );

      await widget.onLogin(result['token']);
    } catch (e) {
      showMessage(e.toString().replaceFirst('Exception: ', ''));
    }

    setState(() {
      loading = false;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.record_voice_over,
                size: 80,
                color: Colors.deepPurple,
              ),
              const SizedBox(height: 20),
              const Text(
                'Voice Chat',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : login,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('LOGIN'),
                ),
              ),
              const SizedBox(height: 15),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RegisterScreen(
                        onRegister: widget.onLogin,
                      ),
                    ),
                  );
                },
                child: const Text('Create new account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= REGISTER =================

class RegisterScreen extends StatefulWidget {
  final Function(String token) onRegister;

  const RegisterScreen({
    super.key,
    required this.onRegister,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  Future<void> register() async {
    if (nameController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      showMessage('All fields are required');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final result = await api.register(
        nameController.text.trim(),
        emailController.text.trim(),
        passwordController.text,
      );

      await widget.onRegister(result['token']);
    } catch (e) {
      showMessage(e.toString().replaceFirst('Exception: ', ''));
    }

    setState(() {
      loading = false;
    });
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: loading ? null : register,
                  child: loading
                      ? const CircularProgressIndicator()
                      : const Text('REGISTER'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================= HOME =================

class HomeScreen extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const HomeScreen({
    super.key,
    required this.token,
    required this.onLogout,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      RoomsScreen(token: widget.token),
      ProfileScreen(
        token: widget.token,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Rooms',
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

// ================= ROOMS =================

class RoomsScreen extends StatefulWidget {
  final String token;

  const RoomsScreen({
    super.key,
    required this.token,
  });

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  List<dynamic> rooms = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadRooms();
  }

  Future<void> loadRooms() async {
    try {
      final data = await api.getRooms(widget.token);

      setState(() {
        rooms = data;
        loading = false;
      });
    } catch (e) {
      setState(() {
        loading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  Future<void> createRoom() async {
    final controller = TextEditingController();

    final roomName = await showDialog<String>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Create Voice Room'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Room name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
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

    if (roomName == null || roomName.isEmpty) return;

    try {
      await api.createRoom(
        widget.token,
        roomName,
      );

      loadRooms();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceFirst('Exception: ', ''),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Rooms'),
        actions: [
          IconButton(
            onPressed: loadRooms,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createRoom,
        child: const Icon(Icons.add),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : rooms.isEmpty
              ? const Center(
                  child: Text(
                    'No rooms yet.\nCreate your first room!',
                    textAlign: TextAlign.center,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadRooms,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index];

                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.mic),
                          ),
                          title: Text(
                            room['name']?.toString() ??
                                'Voice Room',
                          ),
                          subtitle: Text(
                            '${room['room_id'] ?? ''}',
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            size: 18,
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VoiceRoomScreen(
                                  roomName:
                                      room['name']?.toString() ??
                                          'Voice Room',
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ================= VOICE ROOM =================

class VoiceRoomScreen extends StatefulWidget {
  final String roomName;

  const VoiceRoomScreen({
    super.key,
    required this.roomName,
  });

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  bool micOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.roomName),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Text(
            'Voice Room',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Realtime voice will be connected with LiveKit.',
          ),
          const SizedBox(height: 30),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 15,
                mainAxisSpacing: 20,
              ),
              itemCount: 8,
              itemBuilder: (_, index) {
                return Column(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      child: Text('${index + 1}'),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      index == 0 ? 'Host' : 'Seat ${index + 1}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(15),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton.filled(
                  onPressed: () {
                    setState(() {
                      micOn = !micOn;
                    });
                  },
                  icon: Icon(
                    micOn ? Icons.mic : Icons.mic_off,
                  ),
                ),
                IconButton.filled(
                  onPressed: () {},
                  icon: const Icon(Icons.card_giftcard),
                ),
                IconButton.filled(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.call_end),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= PROFILE =================

class ProfileScreen extends StatefulWidget {
  final String token;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.token,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final data = await api.me(widget.token);

      setState(() {
        user = data['user'];
        loading = false;
      });
    } catch (_) {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    child: Icon(
                      Icons.person,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?['name']?.toString() ?? 'User',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user?['email']?.toString() ?? '',
                  ),
                  const SizedBox(height: 30),
                  ListTile(
                    leading: const Icon(Icons.monetization_on),
                    title: const Text('Coins'),
                    trailing: Text(
                      '${user?['coins'] ?? 0}',
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: const Text('Logout'),
                    onTap: widget.onLogout,
                  ),
                ],
              ),
            ),
    );
  }
}
