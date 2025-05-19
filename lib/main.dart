import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const NESecureApp());
}

class NESecureApp extends StatelessWidget {
  const NESecureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NE Secure',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const UserCheckPage();
          }
          return const LoginPage();
        },
      ),
    );
  }
}

// --- CHECK IF USER PROFILE EXISTS ---
class UserCheckPage extends StatelessWidget {
  const UserCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const LoginPage();
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return FutureBuilder<DocumentSnapshot>(
      future: userDoc.get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return RegistrationPage(user: user);
        }
        return const HomePage();
      },
    );
  }
}

// --- LOGIN PAGE WITH REAL OTP ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController otpController = TextEditingController();
  bool otpSent = false;
  String verificationId = '';
  bool loading = false;
  String error = '';

  void sendOTP() async {
    setState(() {
      loading = true;
      error = '';
    });
    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneController.text,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await FirebaseAuth.instance.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        setState(() {
          loading = false;
          error = e.message ?? 'Verification failed';
        });
      },
      codeSent: (String verId, int? resendToken) {
        setState(() {
          verificationId = verId;
          otpSent = true;
          loading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verId) {
        setState(() {
          verificationId = verId;
          loading = false;
        });
      },
    );
  }

  void verifyOTP() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otpController.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Invalid OTP or verification failed';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login - NE Secure')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : otpSent
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Enter the OTP sent to your phone'),
                        TextField(
                          controller: otpController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'OTP',
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: verifyOTP,
                          child: const Text('Verify OTP'),
                        ),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(error, style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Enter your phone number to login'),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number (+91xxxxxxxxxx)',
                            prefixIcon: Icon(Icons.phone),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: sendOTP,
                          child: const Text('Send OTP'),
                        ),
                        if (error.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(error, style: const TextStyle(color: Colors.red)),
                          ),
                      ],
                    ),
        ),
      ),
    );
  }
}

// --- USER REGISTRATION PAGE (Collects name & email) ---
class RegistrationPage extends StatefulWidget {
  final User user;
  const RegistrationPage({super.key, required this.user});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool loading = false;
  String error = '';

  void register() async {
    setState(() {
      loading = true;
      error = '';
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(widget.user.uid).set({
        'uid': widget.user.uid,
        'phone': widget.user.phoneNumber,
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      setState(() {
        loading = false;
      });
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() {
        error = 'Registration failed';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Complete your profile'),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: register,
                      child: const Text('Register'),
                    ),
                    if (error.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(error, style: const TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

// --- HOME PAGE WITH NAVIGATION ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static final List<Widget> _pages = <Widget>[
    SOSPage(),
    ComplaintPage(),
    ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NE Secure'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'SOS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.report),
            label: 'Complaint',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// --- SOS PAGE (Sends SOS with Location and User Info to Firestore) ---
class SOSPage extends StatelessWidget {
  SOSPage({super.key});

  final CollectionReference sosRef = FirebaseFirestore.instance.collection('sos');

  Future<void> sendSOS(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch user profile
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = userDoc['name'] ?? '';
    final phone = userDoc['phone'] ?? '';
    final email = userDoc['email'] ?? '';

    Position? position;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied.')),
        );
        return;
      }

      position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
      return;
    }

    await sosRef.add({
      'uid': user.uid,
      'name': name,
      'phone': phone,
      'email': email,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': position.latitude,
      'longitude': position.longitude,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS Sent!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.sos, color: Colors.white),
        label: const Text('Send SOS'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        onPressed: () => sendSOS(context),
      ),
    );
  }
}

// --- COMPLAINT PAGE (Saves to Firestore with More Fields) ---
class ComplaintPage extends StatefulWidget {
  const ComplaintPage({super.key});

  @override
  State<ComplaintPage> createState() => _ComplaintPageState();
}

class _ComplaintPageState extends State<ComplaintPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  String _category = 'General';
  bool loading = false;
  String error = '';
  String success = '';

  final List<String> categories = [
    'General',
    'Harassment',
    'Theft',
    'Accident',
    'Other',
  ];

  Future<Position?> _getLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled.')),
        );
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied.')),
          );
          return null;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission permanently denied.')),
        );
        return null;
      }

      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to get location: $e')),
      );
      return null;
    }
  }

  void submitComplaint() async {
    setState(() {
      loading = true;
      error = '';
      success = '';
    });
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        error = 'Not logged in';
        loading = false;
      });
      return;
    }

    // Fetch user profile
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = userDoc['name'] ?? '';
    final phone = userDoc['phone'] ?? '';
    final email = userDoc['email'] ?? '';

    final position = await _getLocation(context);

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'uid': user.uid,
        'name': name,
        'phone': phone,
        'email': email,
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _category,
        'timestamp': FieldValue.serverTimestamp(),
        'latitude': position?.latitude,
        'longitude': position?.longitude,
      });
      setState(() {
        _titleController.clear();
        _descController.clear();
        _category = 'General';
        success = 'Complaint submitted!';
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to submit complaint';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Submit a Complaint', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Title',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              items: categories
                  .map((cat) => DropdownMenuItem(
                        value: cat,
                        child: Text(cat),
                      ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _category = val!;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Category',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Description',
              ),
            ),
            const SizedBox(height: 16),
            loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: submitComplaint,
                    child: const Text('Submit'),
                  ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
            if (success.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(success, style: const TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}

// --- PROFILE PAGE (Shows and Edits user info) ---
class ProfilePage extends StatefulWidget {
  ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? user;
  DocumentSnapshot? userDoc;
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  bool editing = false;
  bool loading = false;
  String error = '';
  String success = '';

  Future<void> fetchUser() async {
    user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
      nameController.text = userDoc?['name'] ?? '';
      emailController.text = userDoc?['email'] ?? '';
      setState(() {});
    }
  }

  void saveProfile() async {
    setState(() {
      loading = true;
      error = '';
      success = '';
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
      });
      setState(() {
        editing = false;
        loading = false;
        success = 'Profile updated!';
      });
      fetchUser();
    } catch (e) {
      setState(() {
        error = 'Failed to update profile';
        loading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null || userDoc == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.person, size: 80),
            const SizedBox(height: 16),
            Text(
              user!.phoneNumber ?? '',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 8),
            Text('UID: ${user!.uid}'),
            const SizedBox(height: 24),
            editing
                ? Column(
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      loading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: saveProfile,
                              child: const Text('Save'),
                            ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            editing = false;
                          });
                        },
                        child: const Text('Cancel'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(userDoc?['name'] ?? ''),
                        subtitle: const Text('Name'),
                      ),
                      ListTile(
                        leading: const Icon(Icons.email),
                        title: Text(userDoc?['email'] ?? ''),
                        subtitle: const Text('Email'),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            editing = true;
                          });
                        },
                        child: const Text('Edit Profile'),
                      ),
                    ],
                  ),
            if (error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(error, style: const TextStyle(color: Colors.red)),
              ),
            if (success.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(success, style: const TextStyle(color: Colors.green)),
              ),
          ],
        ),
      ),
    );
  }
}
