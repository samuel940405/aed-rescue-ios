import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';

class CprScreen extends StatefulWidget {
  const CprScreen({Key? key}) : super(key: key);

  @override
  _CprScreenState createState() => _CprScreenState();
}

class _CprScreenState extends State<CprScreen> with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _metronomeTimer;
  
  // 110 BPM
  final Duration _beatInterval = const Duration(milliseconds: 545);
  int _beatCount = 0;
  bool _isPlaying = true;

  // Visual Animation
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAudio();
    _startMetronome();
    
    _animController = AnimationController(
       vsync: this, 
       duration: const Duration(milliseconds: 200)
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut)
    );
  }

  void _setupAudio() async {
    await _flutterTts.setLanguage("zh-TW"); // Chinese Taiwan
    await _flutterTts.setSpeechRate(0.5);
    
    // Initial instruction
    await _flutterTts.speak("請跟隨節拍，用力按壓。");
  }

  void _startMetronome() {
    _metronomeTimer = Timer.periodic(_beatInterval, (timer) {
      if (!_isPlaying) return;
      
      _playBeat();
      _beatCount++;
      
      // Every 30 beats (approx 15-20 sec), remind user
      if (_beatCount % 30 == 0) {
        _flutterTts.speak("用力下壓，不要中斷");
      }
    });
  }

  Future<void> _playBeat() async {
    // Play a system click or simple sound
    // Since we don't have assets guaranteed, we assume a source or fallback to logic
    // For this demo, we'll try to play a default source if available, else just visual
    try {
       await _audioPlayer.play(AssetSource('sounds/metronome.mp3')); 
    } catch(e) {
       print("Audio play error: $e");
    }
    
    // Visual Beat
    _animController.forward().then((_) => _animController.reverse());
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _flutterTts.stop();
    _audioPlayer.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red[800],
      appBar: AppBar(
        title: const Text("CPR GUIDANCE"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "FOLLOW THE BEAT",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              "110 BPM",
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 50),
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 10,
                    )
                  ]
                ),
                child: Center(
                  child: Icon(Icons.favorite, size: 100, color: Colors.red[800]),
                ),
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)
              ),
              onPressed: () {
                setState(() => _isPlaying = !_isPlaying);
                if (_isPlaying) {
                   _flutterTts.speak("繼續急救");
                } else {
                   _flutterTts.speak("暫停");
                }
              },
              icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
              label: Text(_isPlaying ? "PAUSE" : "RESUME"),
            ),
             const SizedBox(height: 20),
             const Padding(
               padding: EdgeInsets.symmetric(horizontal: 40),
               child: Text(
                 "Push hard and fast in the center of the chest.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.white70),
               ),
             )
          ],
        ),
      ),
    );
  }
}
