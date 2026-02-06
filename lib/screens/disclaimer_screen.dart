import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // To access cameras if needed, or better, navigate to wrapper.

class DisclaimerScreen extends StatelessWidget {
  final VoidCallback onAccept;

  const DisclaimerScreen({Key? key, required this.onAccept}) : super(key: key);

  Future<void> _handleAccept(BuildContext context) async {
    // 1. Request Permission
    var status = await Permission.location.request();

    if (status.isGranted) {
      // 2. Get Position
      try {
        Position position = await Geolocator.getCurrentPosition();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("成功取得位置: ${position.latitude}, ${position.longitude}"),
            backgroundColor: Colors.green,
          )
        );
        
        // Original logic to proceed
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_accepted_disclaimer', true);
        onAccept();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("取得位置失敗: $e"),
            backgroundColor: Colors.red,
          )
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("權限被拒絕"),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Legal Disclaimer",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    "1. This application is for reference only. In a life-threatening emergency, always call 119 immediately.\n\n"
                    "2. The AED locations provided are based on Open Data and community reports. We cannot guarantee their real-time availability or functionality.\n\n"
                    "3. We collect your GPS location solely to display nearby AEDs and verify community reports. Your data is not sold to third parties.\n\n"
                    "4. By clicking 'I Agree', you acknowledge that the developers are not liable for any damages arising from the use of this app.",
                    style: TextStyle(fontSize: 16, height: 1.5, color: Colors.black87),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => _handleAccept(context),
                child: const Text("I AGREE & GRANT PERMISSIONS", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      ),
    );
  }
}
