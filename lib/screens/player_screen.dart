import 'package:flutter/material.dart';
import '../services/audio_player_controller.dart';

class PlayerScreen extends StatefulWidget {
  final AudioPlayerController controller;

  const PlayerScreen({
    super.key,
    required this.controller,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AudioPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller;
    _controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {
        // State updates are handled by the controller's notifyListeners()
      });
    }
  }

  String _formatDuration(Duration d) {
    if (d == Duration.zero) {
      return '00:00';
    }
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
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
                    // Progress bar - disabled during loading or error
                    Slider(
                      value: _controller.position.inSeconds.toDouble(),
                      min: 0.0,
                      max: _controller.duration.inSeconds.toDouble() > 0
                          ? _controller.duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: _controller.isInitialized && 
                              !_controller.isLoading && 
                              !_controller.hasError
                          ? (value) async {
                              final position = Duration(seconds: value.toInt());
                              await _controller.seek(position);
                            }
                          : null,
                      onChangeEnd: _controller.isInitialized &&
                              !_controller.isLoading &&
                              !_controller.hasError
                          ? (value) async {
                              final position = Duration(seconds: value.toInt());
                              await _controller.seek(position);
                            }
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(_controller.position)),
                          Text(_formatDuration(_controller.duration)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Play/Pause button - show different UI based on state
                    _buildPlaybackButton(),
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

  Widget _buildPlaybackButton() {
    // Show loading indicator while loading
    if (_controller.isLoading) {
      return SizedBox(
        width: 180,
        height: 60,
        child: const CircularProgressIndicator(),
      );
    }

    // Show error state if applicable
    if (_controller.hasError) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.error_rounded, size: 24),
        label: const Text('Playback Error'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade300,
          foregroundColor: Colors.white,
          minimumSize: const Size(180, 60),
        ),
      );
    }

    // Completed state - show replay button
    if (_controller.isCompleted) {
      return ElevatedButton.icon(
        onPressed: () async => await _controller.restart(),
        icon: const Icon(Icons.replay_rounded, size: 24),
        label: const Text('Replay'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(180, 60),
        ),
      );
    }

    // Playing or Paused - show play/pause button
    return ElevatedButton.icon(
      onPressed: () async => await _controller.togglePlayPause(),
      icon: Icon(
        _controller.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        size: 36,
      ),
      label: Text(
        _controller.isPlaying ? 'Pause' : 'Play',
        style: const TextStyle(fontSize: 18),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(180, 60),
      ),
    );
  }
}
