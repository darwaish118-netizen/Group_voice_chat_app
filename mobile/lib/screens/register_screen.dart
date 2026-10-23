part of '../main.dart';

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
    body: Stack(
      children: [
        const Positioned.fill(child: CustomPaint(painter: MindoAuthBackdropPainter())),
        Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xD918072F),
            Color(0xD909051B),
            Color(0xD926053D),
          ],
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
      ],
    ),
  );
}
}

