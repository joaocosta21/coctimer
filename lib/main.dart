import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clash of Clans Countdown',
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginPage()
          : const CountdownPage(),
    );
  }
}

// Login Page
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    Future<void> _login() async {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text,
          password: passwordController.text,
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const CountdownPage()),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            ElevatedButton(onPressed: _login, child: const Text('Login')),
          ],
        ),
      ),
    );
  }
}

// Countdown Page
class CountdownPage extends StatefulWidget {
  const CountdownPage({super.key});

  @override
  _CountdownPageState createState() => _CountdownPageState();
}
class _CountdownPageState extends State<CountdownPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  late Timer _timer;
  Map<String, int> timeLeftMap = {
    'builder1': 0,
    'builder2': 0,
    'builder3': 0,
    'builder4': 0,
    'builder5': 0,
    'builder6': 0,
    'lab1': 0,
    'lab2': 0,
    'labPets': 0
  };
  late FlutterLocalNotificationsPlugin localNotifications;
  final Map<String, TextEditingController> controllers = {
    'days': TextEditingController(),
    'hours': TextEditingController(),
    'minutes': TextEditingController()
  };

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      for (var label in timeLeftMap.keys) {
        _initializeCountdown(userId, label);
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    localNotifications = FlutterLocalNotificationsPlugin();
    const androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInitSettings);

    await localNotifications.initialize(initSettings);
  }

  Future<void> _showNotification(String label) async {
    const androidDetails = AndroidNotificationDetails(
      'countdown_channel',
      'Countdown Notifications',
      channelDescription: 'Notifications for countdown completion',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    await localNotifications.show(
      0,
      'Countdown Finished',
      'The countdown for $label has completed!',
      notificationDetails,
    );
  }

  Future<void> _initializeCountdown(String userId, String label) async {
    firestore.collection('countdown').doc('$userId-$label').snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final int duration = data['seconds'];
        final Timestamp startAt = data['startAt'];
        final int serverTimeOffset = DateTime.now().millisecondsSinceEpoch -
            startAt.toDate().millisecondsSinceEpoch;

        setState(() {
          timeLeftMap[label] = duration * 1000 - serverTimeOffset;
        });

        _startCountdown(label);
      }
    });
  }

  void _startCountdown(String label) {
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        timeLeftMap[label] = (timeLeftMap[label] ?? 0) - 100;
      });

      if ((timeLeftMap[label] ?? 0) <= 0) {
        timer.cancel();
        setState(() {
          timeLeftMap[label] = 0;
        });
        _showNotification(label);
      }
    });
  }

  Future<void> _setCountdown(String userId, String label) async {
    try {
      final int days = int.parse(controllers['days']!.text.isNotEmpty ? controllers['days']!.text : '0');
      final int hours = int.parse(controllers['hours']!.text.isNotEmpty ? controllers['hours']!.text : '0');
      final int minutes = int.parse(controllers['minutes']!.text.isNotEmpty ? controllers['minutes']!.text : '0');

      final totalSeconds = (days * 86400) + (hours * 3600) + (minutes * 60);

      await firestore.collection('countdown').doc('$userId-$label').set({
        'seconds': totalSeconds,
        'startAt': FieldValue.serverTimestamp(),
      });

      controllers.values.forEach((controller) => controller.clear());
    } catch (e) {
      print('Error: $e');
    }
  }

  String _formatTimeLeft(int milliseconds) {
    final totalSeconds = milliseconds ~/ 1000;
    final days = totalSeconds ~/ 86400;
    final hours = (totalSeconds % 86400) ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    return '${days}d ${hours}h ${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clash of Clans Countdown'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: controllers.keys.map((key) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: TextField(
                    controller: controllers[key],
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: key[0].toUpperCase() + key.substring(1),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            ...timeLeftMap.keys.map((label) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: userId != null ? () => _setCountdown(userId, label) : null,
                      child: const Text('Start Countdown'),
                    ),
                    Text(
                      timeLeftMap[label]! > 0
                          ? 'Time Left: ${_formatTimeLeft(timeLeftMap[label]!)}'
                          : 'Countdown finished!',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
                const Divider(),
              ],
            )).toList(),
          ],
        ),
      ),
    );
  }
}
