import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/sensor_service.dart';
import '../services/database_helper.dart';
import '../services/game_service.dart';

class ReportScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const ReportScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  
  final SensorService _sensorService = SensorService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    // Initialize first camera (usually back camera)
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _captureAndSave() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      await _initializeControllerFuture;

      // 1. Capture Sensors (Force Wait)
      // We grab these BEFORE or DURING photo to ensure accuracy
      final position = await _sensorService.getCurrentLocation();
      final heading = await _sensorService.getCurrentHeading();

      // 2. Take Picture
      final image = await _controller.takePicture();

      // 3. Move to App storage (for offline persistence)
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = p.join(appDir.path, fileName);
      
      await File(image.path).copy(savedPath);

      // 4. Save to Offline Queue (Metadata Association)
      await _dbHelper.insertPendingUpload({
        'image_path': savedPath,
        'lat': position?.latitude ?? 0.0,
        'lng': position?.longitude ?? 0.0,
        'heading': heading ?? 0.0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending'
      });

      // Award Points
      await GameService().addPoints(100);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report saved! You earned 100 points!')),
      );

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add AED Report')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                CameraPreview(_controller),
                if (_isCapturing)
                  const Center(child: CircularProgressIndicator()),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: FloatingActionButton(
                      onPressed: _isCapturing ? null : _captureAndSave,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}
