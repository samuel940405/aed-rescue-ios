import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'database_helper.dart';

class SyncService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  static const String uploadEndpoint = "https://your-backend-api.com/upload";

  /// Start monitoring connectivity changes
  void initialize() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final result = results.first;
      if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
        print("Network restored. Triggering sync...");
        syncPendingUploads();
      }
    });
  }

  /// Process the offline queue
  Future<void> syncPendingUploads() async {
    final pendingItems = await _dbHelper.getPendingUploads();
    
    if (pendingItems.isEmpty) return;

    print("Found ${pendingItems.length} items to upload.");

    for (var item in pendingItems) {
      bool success = await _uploadItem(item);
      if (success) {
        await _dbHelper.markAsUploaded(item['id']);
        print("Item ${item['id']} synced successfully.");
        
        // Optional: Delete local file to save space
        // final file = File(item['image_path']);
        // if (await file.exists()) await file.delete();
      }
    }
  }

  Future<bool> _uploadItem(Map<String, dynamic> item) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(uploadEndpoint));
      
      // Attach Metadata
      request.fields['lat'] = item['lat'].toString();
      request.fields['lng'] = item['lng'].toString();
      request.fields['heading'] = item['heading'].toString();
      request.fields['created_at'] = item['created_at'].toString();

      // Attach File
      final file = File(item['image_path']);
      if (await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('photo', file.path),
        );
      } else {
        print("File missing: ${item['image_path']}");
        return false; // Skip but strictly this is an error state
      }

      var response = await request.send();
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print("Upload failed: $e");
      return false;
    }
  }
}
