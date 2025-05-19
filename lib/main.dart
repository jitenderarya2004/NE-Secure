import 'package:flutter/material.dart';

import 'package:firebase_core/firebase_core.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:location/location.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  runApp(const NESecureApp());

}

class NESecureApp extends StatelessWidget {

  const NESecureApp({super.key});

  @override

  Widget build(BuildContext context) => MaterialApp(

        title: 'NE Secure',

        theme: ThemeData(primarySwatch: Colors.indigo),

        initialRoute: '/',

        routes: {

          '/': (_) => const OTPScreen(),

          '/profile': (_) => const ProfileScreen(),

          '/home': (_) => const HomeScreen(),

        },

        debugShowCheckedModeBanner: false,

      );

}

// -------- OTP SCREEN --------

class OTPScreen extends StatefulWidget {

  const OTPScreen({super.key});

  @override

  State<OTPScreen> createState() => _OTPScreenState();

}

class _OTPScreenState extends State<OTPScreen> {

  final _auth = FirebaseAuth.instance;

  String phone = '', smsCode = '', verificationId = '';

  bool otpSent = false, loading = false;

  void _sendOTP() async {

    setState(() => loading = true);

    await _auth.verifyPhoneNumber(

      phoneNumber: phone,

      verificationCompleted: (credential) async {

        await _auth.signInWithCredential(credential);

        Navigator.pushReplacementNamed(context, '/profile');

      },

      verificationFailed: (e) {

        setState(() => loading = false);

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Error')));

      },

      codeSent: (vid, _) {

        setState(() {

          verificationId = vid;

          otpSent = true;

          loading = false;

        });

      },

      codeAutoRetrievalTimeout: (_) => setState(() => loading = false),

    );

  }

  void _verifyOTP() async {

    setState(() => loading = true);

    try {

      final credential = PhoneAuthProvider.credential(

        verificationId: verificationId, smsCode: smsCode);

      await _auth.signInWithCredential(credential);

      Navigator.pushReplacementNamed(context, '/profile');

    } catch (e) {

      setState(() => loading = false);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invalid OTP')));

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Phone Login')),

      body: Padding(

        padding: const EdgeInsets.all(20.0),

        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [

          TextField(

            decoration: const InputDecoration(labelText: 'Phone Number'),

            keyboardType: TextInputType.phone,

            onChanged: (v) => phone = v,

          ),

          const SizedBox(height: 12),

          if (!otpSent)

            ElevatedButton(

              onPressed: loading ? null : _sendOTP,

              child: loading ? const CircularProgressIndicator() : const Text('Send OTP'),

            ),

          if (otpSent) ...[

            TextField(

              decoration: const InputDecoration(labelText: 'OTP'),

              keyboardType: TextInputType.number,

              onChanged: (v) => smsCode = v,

            ),

            const SizedBox(height: 12),

            ElevatedButton(

              onPressed: loading ? null : _verifyOTP,

              child: loading ? const CircularProgressIndicator() : const Text('Verify'),

            ),

          ],

        ]),

      ),

    );

  }

}

// -------- PROFILE SCREEN --------

class ProfileScreen extends StatefulWidget {

  const ProfileScreen({super.key});

  @override

  State<ProfileScreen> createState() => _ProfileScreenState();

}

class _ProfileScreenState extends State<ProfileScreen> {

  final _formKey = GlobalKey<FormState>();

  String name = '', address = '', contact = '', altContact = '', state = '';

  int age = 18;

  bool loading = false;

  void _save() async {

    if (_formKey.currentState!.validate()) {

      setState(() => loading = true);

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('profiles').doc(user!.uid).set({

        'name': name,

        'address': address,

        'contact': contact,

        'altContact': altContact,

        'state': state,

        'age': age,

        'uid': user.uid,

        'phone': user.phoneNumber,

      });

      setState(() => loading = false);

      Navigator.pushReplacementNamed(context, '/home');

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Complete Profile')),

      body: Form(

        key: _formKey,

        child: ListView(

          padding: const EdgeInsets.all(16),

          children: [

            TextFormField(

              decoration: const InputDecoration(labelText: 'Name'),

              onChanged: (v) => name = v,

              validator: (v) => v!.isEmpty ? 'Enter name' : null,

            ),

            TextFormField(

              decoration: const InputDecoration(labelText: 'Address'),

              onChanged: (v) => address = v,

              validator: (v) => v!.isEmpty ? 'Enter address' : null,

            ),

            TextFormField(

              decoration: const InputDecoration(labelText: 'Age'),

              keyboardType: TextInputType.number,

              onChanged: (v) => age = int.tryParse(v) ?? 18,

              validator: (v) => v!.isEmpty ? 'Enter age' : null,

            ),

            TextFormField(

              decoration: const InputDecoration(labelText: 'Contact'),

              onChanged: (v) => contact = v,

              validator: (v) => v!.isEmpty ? 'Enter contact' : null,

            ),

            TextFormField(

              decoration: const InputDecoration(labelText: 'Alt Contact'),

              onChanged: (v) => altContact = v,

            ),

            TextFormField(

              decoration: const InputDecoration(labelText: 'State'),

              onChanged: (v) => state = v,

              validator: (v) => v!.isEmpty ? 'Enter state' : null,

            ),

            const SizedBox(height: 20),

            ElevatedButton(

              onPressed: loading ? null : _save,

              child: loading ? const CircularProgressIndicator() : const Text('Save'),

            ),

          ],

        ),

      ),

    );

  }

}

// -------- HOME SCREEN --------

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  @override

  Widget build(BuildContext context) {

    final loc = Location();

    return Scaffold(

      appBar: AppBar(title: const Text('NE SECURE Home')),

      body: Center(

        child: ListView(

          padding: const EdgeInsets.all(20),

          shrinkWrap: true,

          children: [

            ElevatedButton.icon(

              icon: const Icon(Icons.warning),

              label: const Text('SOS Alert'),

              onPressed: () async {

                final user = FirebaseAuth.instance.currentUser;

                try {

                  bool serviceEnabled = await loc.serviceEnabled();

                  if (!serviceEnabled) {

                    serviceEnabled = await loc.requestService();

                    if (!serviceEnabled) throw Exception("Location service denied");

                  }

                  PermissionStatus permissionGranted = await loc.hasPermission();

                  if (permissionGranted == PermissionStatus.denied) {

                    permissionGranted = await loc.requestPermission();

                    if (permissionGranted != PermissionStatus.granted) throw Exception("Location permission denied");

                  }

                  final l = await loc.getLocation();

                  // Fetch user profile for extra info

                  final profileSnap = await FirebaseFirestore.instance

                      .collection('profiles')

                      .doc(user!.uid)

                      .get();

                  final profile = profileSnap.data() ?? {};

                  await FirebaseFirestore.instance.collection('sos').add({

                    'uid': user.uid,

                    'phone': user.phoneNumber,

                    'timestamp': FieldValue.serverTimestamp(),

                    'lat': l.latitude,

                    'lng': l.longitude,

                    'profile': profile,

                  });

                  ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(content: Text('SOS sent')));

                } catch (e) {

                  ScaffoldMessenger.of(context).showSnackBar(

                      SnackBar(content: Text('SOS failed: $e')));

                }

              },

            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(

              icon: const Icon(Icons.report),

              label: const Text('File Complaint'),

              onPressed: () => Navigator.push(

                context,

                MaterialPageRoute(builder: (_) => const CategorizedComplaintScreen()),

              ),

            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(

              icon: const Icon(Icons.history),

              label: const Text('Track Complaints'),

              onPressed: () => Navigator.push(

                context,

                MaterialPageRoute(builder: (_) => const TrackingScreen()),

              ),

            ),

            const SizedBox(height: 12),

            ElevatedButton.icon(

              icon: const Icon(Icons.person),

              label: const Text('Profile'),

              onPressed: () => Navigator.push(

                context,

                MaterialPageRoute(builder: (_) => const ProfileScreen()),

              ),

            ),

          ],

        ),

      ),

    );

  }

}

// -------- CATEGORY SELECTION --------

class CategorizedComplaintScreen extends StatelessWidget {

  const CategorizedComplaintScreen({super.key});

  final List<String> categories = const [

    'Verbal Abuse',

    'Housing Discrimination',

    'Workplace Harassment',

    'Police Apathy',

    'Cyberbullying',

    'Physical Assault',

    'Other'

  ];

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('Select Category')),

      body: ListView.builder(

        itemCount: categories.length,

        itemBuilder: (context, index) => ListTile(

          title: Text(categories[index]),

          trailing: const Icon(Icons.arrow_forward_ios),

          onTap: () => Navigator.push(

            context,

            MaterialPageRoute(

              builder: (_) => ComplaintFormScreen(prefill: categories[index]),

            ),

          ),

        ),

      ),

    );

  }

}

// -------- COMPLAINT FORM --------

class ComplaintFormScreen extends StatefulWidget {

  final String? prefill;

  const ComplaintFormScreen({super.key, this.prefill});

  @override

  State<ComplaintFormScreen> createState() => _ComplaintFormScreenState();

}

class _ComplaintFormScreenState extends State<ComplaintFormScreen> {

  late TextEditingController _controller;

  bool loading = false;

  @override

  void initState() {

    super.initState();

    _controller = TextEditingController(

        text: widget.prefill != null ? '${widget.prefill}: ' : '');

  }

  void _submit() async {

    if (_controller.text.trim().isNotEmpty) {

      setState(() => loading = true);

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance.collection('complaints').add({

        'uid': user!.uid,

        'phone': user.phoneNumber,

        'text': _controller.text.trim(),

        'status': 'Pending',

        'timestamp': FieldValue.serverTimestamp(),

      });

      setState(() => loading = false);

      ScaffoldMessenger.of(context)

          .showSnackBar(const SnackBar(content: Text('Complaint submitted')));

      Navigator.pop(context);

    }

  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(title: const Text('File Complaint')),

      body: Padding(

        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(

              controller: _controller,

              maxLines: 5,

              decoration: const InputDecoration(labelText: 'Complaint Text'),

            ),

            const SizedBox(height: 16),

            ElevatedButton(

              onPressed: loading ? null : _submit,

              child: loading ? const CircularProgressIndicator() : const Text('Submit'),

            ),

          ],

        ),

      ),

    );

  }

}

// -------- TRACKING SCREEN (Realtime) --------

class TrackingScreen extends StatelessWidget {

  const TrackingScreen({super.key});

  @override

  Widget build(BuildContext context) {

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(

      appBar: AppBar(title: const Text('My Complaints')),

      body: StreamBuilder<QuerySnapshot>(

        stream: FirebaseFirestore.instance

            .collection('complaints')

            .where('uid', isEqualTo: user!.uid)

            .orderBy('timestamp', descending: true)

            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final complaints = snapshot.data!.docs;

          if (complaints.isEmpty) return const Center(child: Text('No complaints yet.'));

          return ListView.builder(

            itemCount: complaints.length,

            itemBuilder: (ctx, i) => ListTile(

              title: Text(complaints[i]['text'] ?? ''),

              subtitle: Text('Status: ${complaints[i]['status'] ?? 'Pending'}'),

            ),

          );

        },

      ),

    );

  }

}