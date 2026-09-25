import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

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
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    widget.controller.addOnDurationListener((d) {
      if (mounted) {
        setState(() {
          widget.controller.updateDuration(d);
        });
      }
    });

    widget.controller.addOnPositionListener((p) {
      if (mounted) {
        setState(() {
          widget.controller.updatePosition(p);
        });
      }
    });

    widget.controller.addOnPlayerCompleteListener(() {
      if (mounted) {
        setState(() {
          widget.controller.updatePosition(Duration.zero);
        });
      }
    });
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
                    Slider(
                      value: widget.controller.position.inSeconds.toDouble(),
                      min: 0.0,
                      max: widget.controller.duration.inSeconds.toDouble() > 0
                          ? widget.controller.duration.inSeconds.toDouble()
                          : 1.0,
                      onChanged: (value) async {
                        final position = Duration(seconds: value.toInt());
                        await widget.controller.seek(position);
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_formatDuration(widget.controller.position)),
                          Text(_formatDuration(widget.controller.duration)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton.icon(
                      onPressed: () => widget.controller.togglePlayPause(),
                      icon: Icon(
                        widget.controller.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 36,
                      ),
                      label: Text(
                        widget.controller.isPlaying ? 'Pause' : 'Play',
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
