import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/aed_point.dart';
import '../services/sensor_service.dart';
import '../services/database_helper.dart';
import 'guidance_screen.dart';
import 'cpr_screen.dart';
import 'profile_screen.dart';

class EmergencyHomeScreen extends StatefulWidget {
  const EmergencyHomeScreen({Key? key}) : super(key: key);

  @override
  _EmergencyHomeScreenState createState() => _EmergencyHomeScreenState();
}

class _EmergencyHomeScreenState extends State<EmergencyHomeScreen> {
  final SensorService _sensorService = SensorService(); // Kept for other potential uses or backup
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 1. Inject CYCU AED Data (Hardcoded for demo/testing)
  final List<AedPoint> _allAeds = [
    AedPoint(
      id: 1001,
      name: '中原大學 科學館',
      address: '桃園市中壢區中北路200號 (科學館)',
      floor: '1F',
      landmarks: '["Main Entrance", "Security Desk"]',
      lat: 24.9582,
      lng: 121.2403,
    ),
    AedPoint(
      id: 1002,
      name: '中原大學 全人教育村',
      address: '桃園市中壢區中北路200號 (全人)',
      floor: 'LB',
      landmarks: '["Village Hall", "Information"]',
      lat: 24.9571,
      lng: 121.2415,
    ),
    AedPoint(
      id: 1003,
      name: '中原大學 體育館',
      address: '桃園市中壢區中北路200號 (體育館)',
      floor: '1F',
      landmarks: '["Gym Reception"]',
      lat: 24.9591,
      lng: 121.2430,
    ),
  ];

  List<AedPoint> _nearestAeds = [];
  bool _loading = true;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    // Initialize list with hardcoded data properly
    _nearestAeds = List.from(_allAeds); 
    
    // Start tracking
    _startLocationStream();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // 2. Implement Missing Function: _startLocationStream
  void _startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Handle disabled service if needed
      print("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    // 3. Fix Const Syntax: Remove const from LocationSettings
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, // Update every 20 meters
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _loading = false;
          _sortAedsByDistance();
        });
      }
    }, onError: (e) {
      print("Location stream error: $e");
      // Fallback location checks could go here
    });
  }

  // 4. Implement Missing Function: _refreshLocation
  Future<void> _refreshLocation() async {
    setState(() => _loading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
          _sortAedsByDistance();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("已更新最新位置"), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("定位失敗: $e"), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // 5. Implement Missing Function: _sortAedsByDistance
  void _sortAedsByDistance() {
    if (_currentLocation == null) return;

    final Distance distance = const Distance();
    
    // Update distances
    for (var aed in _allAeds) {
      aed.distance = distance.as(
        LengthUnit.Meter,
        _currentLocation!,
        LatLng(aed.lat, aed.lng)
      );
    }

    // Sort
    _allAeds.sort((a, b) => (a.distance ?? 99999).compareTo(b.distance ?? 99999));
    
    // Update display list (Top 10)
    _nearestAeds = _allAeds.take(10).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Basic loading logic based on whether we have location or at least AEDs to show
    if (_loading && _currentLocation == null && _nearestAeds.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('EMERGENCY MODE', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLocation,
            tooltip: 'Refresh Location',
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen())),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
           final Uri launchUri = Uri(scheme: 'tel', path: '119');
           if (await canLaunchUrl(launchUri)) {
             await launchUrl(launchUri);
           }
        },
        backgroundColor: Colors.red[900],
        icon: const Icon(Icons.phone_in_talk, color: Colors.white),
        label: const Text("CALL 119", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.redAccent,
            child: const Text(
              "Select the nearest AED to start guidance",
              style: TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _nearestAeds.length,
              itemBuilder: (context, index) {
                final aed = _nearestAeds[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: InkWell(
                    onTap: () {
                      _showActionSheet(context, aed);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Big Distance
                          Container(
                            width: 80,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.withOpacity(0.3))
                            ),
                            child: Column(
                              children: [
                                Text(
                                  "${aed.distance?.toInt() ?? '-'}m",
                                  style: const TextStyle(
                                    fontSize: 20, 
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red
                                  ),
                                ),
                                const Text("Distance", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  aed.name,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(4)
                                      ),
                                      child: Text(
                                        aed.floor, 
                                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown[800])
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        aed.address,
                                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // Offline Map Placeholder Section
          Container(
            height: 150,
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: _currentLocation ?? const LatLng(24.9582, 121.2403), // Default to CYCU
                  initialZoom: 15,
                ),
                children: [
                   TileLayer(
                     urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                     // 6. Fix Map Permission: userAgentPackageName
                     userAgentPackageName: 'com.cycu.rescue.mobileApp',
                   ),
                   MarkerLayer(
                     markers: [
                       if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            child: const Icon(Icons.my_location, color: Colors.blue, size: 30),
                          ),
                       ..._nearestAeds.map((aed) => Marker(
                         point: LatLng(aed.lat, aed.lng),
                         child: const Icon(Icons.location_on, color: Colors.red),
                       )).toList(),
                     ]
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionSheet(BuildContext context, AedPoint aed) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 250,
          child: Column(
             crossAxisAlignment: CrossAxisAlignment.stretch,
             children: [
               Text(aed.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               const SizedBox(height: 20),
               ElevatedButton.icon(
                 icon: const Icon(Icons.navigation),
                 label: const Text("START GUIDANCE"),
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                 onPressed: () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (_) => GuidanceScreen(
                     targetAed: aed, userLocation: _currentLocation ?? LatLng(aed.lat, aed.lng) // fallback
                   )));
                 },
               ),
               const SizedBox(height: 10),
               OutlinedButton.icon(
                 icon: const Icon(Icons.medical_services),
                 label: const Text("I HAVE THE AED - START CPR"),
                 style: OutlinedButton.styleFrom(
                   padding: const EdgeInsets.all(16),
                   foregroundColor: Colors.red
                 ),
                 onPressed: () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (_) => const CprScreen()));
                 },
               )
             ],
          ),
        );
      }
    );
  }
}
