import 'dart:math';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart'; // For visual context if needed
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
  
  List<AedPoint> _nearestAeds = [];
  bool _loading = true;
  LatLng? _currentLocation;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Ensure dummy data exists for demo
    await _dbHelper.seedDummyData();
    
    // Get Location
    try {
      final pos = await _sensorService.getCurrentLocation();
      if (pos != null) {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        await _findNearestAeds(_currentLocation!);
      }
    } catch (e) {
      print("Error loading location: $e");
      // Use fallback location (Taipei 101) for demo if GPS fails in simulator
      _currentLocation = const LatLng(25.0330, 121.5654);
      await _findNearestAeds(_currentLocation!);
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _findNearestAeds(LatLng current) async {
    final data = await _dbHelper.getAllAeds();
    final allAeds = data.map((e) => AedPoint.fromMap(e)).toList();
    
    // Calculate distance for all
    final Distance distance = const Distance();
    for (var aed in allAeds) {
      aed.distance = distance.as(
        LengthUnit.Meter, 
        current, 
        LatLng(aed.lat, aed.lng)
      );
    }

    // Sort and take top 3
    allAeds.sort((a, b) => (a.distance ?? 99999).compareTo(b.distance ?? 99999));
    _nearestAeds = allAeds.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
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
                                  "${aed.distance?.toInt()}m",
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
                  initialCenter: _currentLocation ?? const LatLng(0,0), // Updated for v6
                  initialZoom: 15,
                ),
                children: [
                   TileLayer(
                     urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                     userAgentPackageName: 'com.example.app',
                     // For offline, you would change this to a local provider or use fmtc
                     // tileProvider: AssetTileProvider(...),
                   ),
                   MarkerLayer(
                     markers: _nearestAeds.map((aed) => Marker(
                       point: LatLng(aed.lat, aed.lng),
                       child: const Icon(Icons.location_on, color: Colors.red),
                     )).toList(),
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
                     targetAed: aed, userLocation: _currentLocation!
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
