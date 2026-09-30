import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bhagavad_gita/screens/player_screen.dart';
import 'package:bhagavad_gita/screens/splash_screen.dart';
import 'package:bhagavad_gita/services/audio_player_controller.dart';

void main() {
  // Required before using MethodChannels (e.g. background service channel).
  WidgetsFlutterBinding.ensureInitialized();
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
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
              MaterialPageRoute(
                builder: (context) => const GitaPlayerScreen(),
              ),
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

class _GitaPlayerScreenState extends State<GitaPlayerScreen>
    with WidgetsBindingObserver {
  // MethodChannel that talks to BackgroundAudioService via MainActivity.
  static const _serviceChannel = MethodChannel(
    'com.reshapel.bhagavadgita/background_audio',
  );

  late AudioPlayerController _playerController;

  // Track whether the foreground service is currently running so we never
  // double-start or double-stop it.
  bool _serviceRunning = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _playerController = AudioPlayerController();
    _playerController.addListener(_onPlayerStateChanged);
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      await _playerController.initialize('audio.m4a');
    } on AudioInitializationException catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error loading audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audio: $e')),
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Foreground service management
  // -------------------------------------------------------------------------

  /// Start the Android foreground service if not already running.
  Future<void> _startBackgroundService() async {
    if (_serviceRunning) return;
    try {
      await _serviceChannel.invokeMethod<void>('startService');
      _serviceRunning = true;
    } catch (e) {
      // Non-fatal on non-Android platforms (web, desktop) where the channel
      // is not registered — playback continues without the service.
      debugPrint('BackgroundAudioService: startService failed: $e');
    }
  }

  /// Stop the Android foreground service if it is running.
  Future<void> _stopBackgroundService() async {
    if (!_serviceRunning) return;
    try {
      await _serviceChannel.invokeMethod<void>('stopService');
      _serviceRunning = false;
    } catch (e) {
      debugPrint('BackgroundAudioService: stopService failed: $e');
    }
  }

  // -------------------------------------------------------------------------
  // AudioPlayerController listener
  // -------------------------------------------------------------------------

  /// Called whenever the player state changes.
  ///
  /// Start the foreground service as soon as playback begins so the process
  /// is protected before the app can be backgrounded.
  /// Stop it only when the track completes or an unrecoverable error occurs —
  /// pausing alone should NOT stop the service, because the user may resume
  /// at any time while the app is in the background.
  void _onPlayerStateChanged() {
    switch (_playerController.state) {
      case AudioPlaybackState.playing:
        _startBackgroundService();
      case AudioPlaybackState.completed:
        // Track finished; the service is no longer needed.
        _stopBackgroundService();
      case AudioPlaybackState.error:
        // Stop the service on unrecoverable error; tryRecover() will
        // restart it if the user retries and playback resumes.
        _stopBackgroundService();
      case AudioPlaybackState.loading:
      case AudioPlaybackState.paused:
        // Keep the service alive so the user can resume from the background.
        break;
    }
  }

  // -------------------------------------------------------------------------
  // App lifecycle
  // -------------------------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.detached:
        // App is being terminated. Stop the service cleanly.
        _stopBackgroundService();
      case AppLifecycleState.paused:
        // App moved to background. If audio is playing the foreground service
        // is already running (started in _onPlayerStateChanged). Nothing to do.
        break;
      case AppLifecycleState.resumed:
        // App returned to foreground. If audio is still playing but the
        // service was somehow stopped (e.g. user dismissed the notification
        // before GITA-8 makes it non-dismissible), restart it.
        if (_playerController.isPlaying && !_serviceRunning) {
          _startBackgroundService();
        }
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  // -------------------------------------------------------------------------
  // Disposal
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playerController.removeListener(_onPlayerStateChanged);
    _stopBackgroundService();
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlayerScreen(controller: _playerController);
  }
}
