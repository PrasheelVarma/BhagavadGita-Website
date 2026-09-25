import 'package:flutter/material.dart';
import 'package:bhagavad_gita/services/audio_player_controller.dart';
import 'package:bhagavad_gita/screens/splash_screen.dart';
import 'package:bhagavad_gita/screens/player_screen.dart';

void main() {
  runApp(const BhagavadGitaApp());
}

class BhagavadGitaApp extends StatelessWidget {
  const BhagavadGitaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhagavad Gita',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFD32F2F),
        scaffoldBackgroundColor: const Color(0xFFFDFDFD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD32F2F),
          primary: const Color(0xFFD32F2F),
          secondary: const Color(0xFFFFCDD2),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFD32F2F),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFD32F2F),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
        ),
        sliderTheme: SliderThemeData(
          activeTrackColor: const Color(0xFFD32F2F),
          inactiveTrackColor: const Color(0xFFFFCDD2),
          thumbColor: const Color(0xFFD32F2F),
          overlayColor: const Color(0x33D32F2F),
          trackHeight: 6,
        ),
      ),
      home: Builder(
        builder: (context) => SplashScreen(
          onSplashComplete: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const GitaPlayerScreen()),
            );
          },
        ),
      ),
    );
  }
}

class GitaPlayerScreen extends StatefulWidget {
  const GitaPlayerScreen({super.key});

  @override
  State<GitaPlayerScreen> createState() => _GitaPlayerScreenState();
}

class _GitaPlayerScreenState extends State<GitaPlayerScreen> {
  late AudioPlayerController _playerController;

  @override
  void initState() {
    super.initState();
    _playerController = AudioPlayerController();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _playerController.initialize('audio.m4a');
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerScreen(controller: _playerController);
  }
}
