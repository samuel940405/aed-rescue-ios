import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/sync_service.dart';
import 'screens/report_screen.dart';
import 'screens/emergency_home_screen.dart';
import 'screens/disclaimer_screen.dart';

// Top-level function for background task
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print("Native called background task: $task");
    if (task == 'sync_uploads') {
       final syncService = SyncService();
       await syncService.syncPendingUploads();
    }
    return Future.value(true);
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Cameras
  // Handle case where no camera e.g. simulator
  List<CameraDescription> cameras = [];
  try {
    cameras = await availableCameras();
  } catch (e) {
    print("No camera found: $e");
  }
  
  // Initialize Background Sync Manager
  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: true 
  );
  
  Workmanager().registerPeriodicTask(
    "1", 
    "sync_uploads", 
    constraints: Constraints(
      networkType: NetworkType.connected, 
    ),
    frequency: const Duration(minutes: 15),
  );

  // Check disclaimer status
  final prefs = await SharedPreferences.getInstance();
  final bool hasAccepted = prefs.getBool('has_accepted_disclaimer') ?? false;

  runApp(MyApp(cameras: cameras, hasAcceptedDisclaimer: hasAccepted));
}

class MyApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  final bool hasAcceptedDisclaimer;

  const MyApp({Key? key, required this.cameras, required this.hasAcceptedDisclaimer}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final SyncService _syncService = SyncService();
  late bool _hasAccepted;

  @override
  void initState() {
    super.initState();
    _hasAccepted = widget.hasAcceptedDisclaimer;
    _syncService.initialize();
  }

  void _onAccepted() {
     setState(() {
       _hasAccepted = true;
     });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AED Rescue',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        scaffoldBackgroundColor: Colors.grey[50], // Lighter background
      ),
      home: _hasAccepted 
          ? const EmergencyHomeScreen()
          : DisclaimerScreen(onAccept: _onAccepted),
    );
  }
}
