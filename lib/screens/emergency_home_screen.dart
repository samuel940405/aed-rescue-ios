import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
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
  final SensorService _sensorService = SensorService(); 
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 1. Remove Hardcoded Data
  // JSON loading will replace _allAeds
  List<AedPoint> _allAeds = [];

  List<AedPoint> _nearestAeds = [];
  bool _loading = true;
  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    // 2. Load JSON Data
    _loadAedData();
    
    // Start tracking
    _startLocationStream();
  }

  Future<void> _loadAedData() async {
    try {
      final String response = await rootBundle.loadString('assets/aed_data.json');
      final List<dynamic> data = json.decode(response);
      setState(() {
        _allAeds = data.map((json) => AedPoint.fromMap(json)).toList();
      });
      // Initial sort if we already have location (unlikely first run, but possible)
      if (_currentLocation != null) {
        _sortAedsByDistance();
      }
    } catch (e) {
      print("Failed to load AED data: $e");
      // Fallback empty list or handle error
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLocationStream() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 20, 
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position position) {
      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
           // Loading is done once we have location + data (data loads fast)
          _loading = false;
          _sortAedsByDistance();
        });
      }
    }, onError: (e) {
      print("Location stream error: $e");
    });
  }

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

  // 3. Dynamic Filtering Logic (2km radius)
  void _sortAedsByDistance() {
    if (_currentLocation == null || _allAeds.isEmpty) return;

    final Distance distance = const Distance();
    const double radiusInMeters = 2000; // 2km radius

    // Create a temporary list for calculation
    List<AedPoint> nearbyCandidates = [];

    // Calculate distances and filter
    for (var aed in _allAeds) {
      double dist = distance.as(
        LengthUnit.Meter,
        _currentLocation!,
        LatLng(aed.lat, aed.lng)
      );
      aed.distance = dist; // Store distance in object

      if (dist <= radiusInMeters) {
        nearbyCandidates.add(aed);
      }
    }

    // Sort by distance
    nearbyCandidates.sort((a, b) => (a.distance ?? 99999).compareTo(b.distance ?? 99999));
    
    // Update display list (Take up to 20 to show list, can be adjusted)
    setState(() {
        _nearestAeds = nearbyCandidates; 
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _currentLocation == null) {
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
            child: _nearestAeds.isEmpty 
              ? Center(child: Text("附近 2km 內沒有發現 AED", style: TextStyle(color: Colors.grey[600], fontSize: 16)))
              : ListView.builder(
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
