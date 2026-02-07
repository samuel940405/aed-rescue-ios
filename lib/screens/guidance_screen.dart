import 'dart:async'; // For StreamSubscription
import 'package:geolocator/geolocator.dart'; // For Position and Geolocator
import 'dart:math'; // For pi
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:vector_math/vector_math.dart' as vector;
import '../models/aed_point.dart';
import '../services/sensor_service.dart';

class GuidanceScreen extends StatefulWidget {
  final AedPoint targetAed;
  final LatLng userLocation; // Initial location

  const GuidanceScreen({
    Key? key, 
    required this.targetAed,
    required this.userLocation
  }) : super(key: key);

  @override
  _GuidanceScreenState createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> with SingleTickerProviderStateMixin {
  final SensorService _sensorService = SensorService();
  double _currentHeading = 0.0;
  double _bearing = 0.0;
  double _distance = 0.0;
  
  // Animation for smooth arrow rotation
  late AnimationController _animController;
  late Animation<double> _animDouble;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Start listening to sensors
    _startTracking();
  }

  StreamSubscription<Position>? _positionStream;

  void _startTracking() {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
        if (mounted) {
           _updatePosition(position);
        }
    });
  }

  void _updatePosition(Position pos) async {
       // Simulator special handling: Assume Heading is 0 (North) for testing
       // final heading = await _sensorService.getCurrentHeading() ?? 0.0;
       
       final double currentLat = pos.latitude;
       final double currentLng = pos.longitude;
       final double targetLat = widget.targetAed.lat;
       final double targetLng = widget.targetAed.lng;
       
       // Calculate bearing using Geolocator
       final double bearing = Geolocator.bearingBetween(
         currentLat, currentLng, 
         targetLat, targetLng
       );
       
       setState(() {
         // Update distance
         _distance = Geolocator.distanceBetween(
           currentLat, currentLng, 
           targetLat, targetLng
         );
         // Update bearing directly
         _bearing = bearing;
       });
  }

  // Calculate bearing from P1 to P2
  double _calculateBearing(LatLng start, LatLng end) {
    // Simple bearing calculation
    // latlong2 usually has a bearing function, but Distance().bearing(start, end) works too
    return const Distance().bearing(start, end);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate relative angle for the arrow
    // Bearing is 0-360 clockwise from North
    // Heading is 0-360 clockwise from North
    // Arrow rotation = Bearing - Heading
    double rotation = (_bearing - _currentHeading);
    // Normalize to -180 to 180 for shortest rotation
    rotation = (rotation + 180) % 360 - 180;
    
    // Convert to radians
    final rotationRad = vector.radians(rotation);

    // Parse landmarks
    List<dynamic> tags = [];
    try {
      tags = json.decode(widget.targetAed.landmarks);
    } catch(e) {
      tags = ["Safe Area"];
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SEARCHING...', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Info
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Column(
              children: [
                Text(
                  widget.targetAed.name, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                ),
                Text(
                  "${widget.targetAed.floor} • ${widget.targetAed.address}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey, fontSize: 14)
                ),
              ],
            ),
          ),

          // ARROW
          Expanded(
            child: Center(
              child: IgnorePointer(
                  child: Transform.rotate(
                    angle: (_bearing + 180) * pi / 180, // Simulator: Assume phone is North-up (0 heading) + 180 correction
                    child: Icon(
                      Icons.navigation,
                      size: 250,
                      color: _distance < 20 ? Colors.greenAccent : Colors.redAccent,
                    ),
                  ),
              ),
            ),
          ),

          // Distance & Last 10m Tags
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30)
              )
            ),
            child: Column(
              children: [
                Text(
                  "${_distance.toInt()} M",
                  style: const TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: tags.map((t) => Chip(
                    label: Text(t.toString().toUpperCase()),
                    backgroundColor: Colors.amber,
                    labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  )).toList(),
                ),
                if (_distance < 15)
                  const Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text(
                      "YOU ARE CLOSE! LOOK AROUND.",
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}
