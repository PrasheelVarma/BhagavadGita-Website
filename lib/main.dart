import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async'; // Required for the timer

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
      // Start with the Splash Screen
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Create a scale effect (grows slightly)
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    // Create a fade effect
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    // Start animation
    _controller.forward();

    // Navigate to Home after 3 seconds
    Timer(const Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const GitaPlayerScreen()),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean background for the logo
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // The Logo
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/logo.png',
                    height: 200,
                    width: 200,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 24),
                // Optional: App Title below logo
                Text(
                  'श्रीमद्भगवद्गीता',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFD32F2F),
                    letterSpacing: 1.1,
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

class GitaPlayerScreen extends StatefulWidget {
  const GitaPlayerScreen({super.key});

  @override
  State<GitaPlayerScreen> createState() => _GitaPlayerScreenState();
}

class _GitaPlayerScreenState extends State<GitaPlayerScreen> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();

    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });

    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  Future<void> _initAudio() async {
    try {
      await _audioPlayer.setSource(AssetSource('audio.m4a'));
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
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.resume();
    }
    if (mounted) {
      setState(() => _isPlaying = !_isPlaying);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bhagavad Gita'),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFFFF3E0),
              const Color(0xFFFFE0B2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Deity Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/logo.png',
                        height: 220,
                        width: 220,
                        fit: BoxFit.cover,
                      ),
                    ),

                    const SizedBox(height: 40),

                    Text(
                      'श्रीमद्भगवद्गीता',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD32F2F),
                        letterSpacing: 1.2,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Divine Song of the Lord',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),

                    const SizedBox(height: 48),

                    // Progress bar
                    Slider(
                      value: _position.inSeconds.toDouble(),
                      min: 0.0,
                      max: _duration.inSeconds.toDouble() > 0
                          ? _duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await _audioPlayer.seek(position);
                      },
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_position)),
                          Text(_formatDuration(_duration)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Play/Pause Button
                    ElevatedButton.icon(
                      onPressed: _togglePlayPause,
                      icon: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 36,
                      ),
                      label: Text(
                        _isPlaying ? 'Pause' : 'Play',
                        style: const TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(180, 60),
                      ),
                    ),

                    const SizedBox(height: 60),
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