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
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  double get _sliderValue {
    if (_controller.duration <= Duration.zero) {
      return 0;
    }

    final value =
        _controller.position.inMilliseconds.toDouble();

    final max =
        _controller.duration.inMilliseconds.toDouble();

    return value.clamp(0.0, max);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bhagavad Gita'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ),
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

                  const Text(
                    'श्रीमद्भगवद्गीता',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD32F2F),
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

                  Slider(
                    value: _sliderValue,
                    min: 0,
                    max: _controller.duration > Duration.zero
                        ? _controller.duration.inMilliseconds
                            .toDouble()
                        : 1,
                    onChanged: _controller.isInitialized &&
                            !_controller.isLoading &&
                            !_controller.hasError
                        ? (value) {
                            setState(() {
                              // Visual slider update while dragging.
                            });
                          }
                        : null,
                    onChangeEnd: _controller.isInitialized &&
                            !_controller.isLoading &&
                            !_controller.hasError
                        ? (value) {
                            _controller.seek(
                              Duration(
                                milliseconds: value.round(),
                              ),
                            );
                          }
                        : null,
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(
                            _controller.position,
                          ),
                        ),
                        Text(
                          _formatDuration(
                            _controller.duration,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  _buildPlaybackButton(),

                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackButton() {
    if (_controller.isLoading) {
      return const SizedBox(
        width: 180,
        height: 60,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_controller.hasError) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(
          Icons.error_rounded,
          size: 24,
        ),
        label: const Text('Playback Error'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(180, 60),
        ),
      );
    }

    if (_controller.isCompleted) {
      return ElevatedButton.icon(
        onPressed: _controller.isBusy
            ? null
            : () => _controller.restart(),
        icon: const Icon(
          Icons.replay_rounded,
          size: 24,
        ),
        label: const Text('Replay'),
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(180, 60),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _controller.isBusy
          ? null
          : () => _controller.togglePlayPause(),
      icon: Icon(
        _controller.isPlaying
            ? Icons.pause_rounded
            : Icons.play_arrow_rounded,
        size: 36,
      ),
      label: Text(
        _controller.isPlaying ? 'Pause' : 'Play',
        style: const TextStyle(
          fontSize: 18,
        ),
      ),
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(180, 60),
      ),
    );
  }
}