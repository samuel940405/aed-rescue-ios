import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('Verify CYCU AED Data Coordinates', () async {
    final file = File('assets/aed_data.json');
    final jsonString = await file.readAsString();
    final List<dynamic> data = json.decode(jsonString);

    // CYCU Fountain (Approx center reference)
    final fountain = LatLng(24.9570, 121.2403);
    final Distance distanceObj = const Distance();

    print('\n--- CYCU AED Coordinate Verification ---');
    print('Reference Point: CYCU Fountain (24.9570, 121.2403)\n');

    for (var item in data) {
      if (item['name'].toString().contains('中原')) {
        final lat = item['lat'] as double;
        final lng = item['lng'] as double;
        final point = LatLng(lat, lng);
        
        final distance = distanceObj.as(LengthUnit.Meter, fountain, point);
        
        String status = '[通過]';
        if (distance < 10) {
          status = '[警告] 座標可能重疊 (太近)！';
        } else if (distance > 500) {
          status = '[警告] 座標異常遙遠 (太遠)！';
        }

        print('$status ${item['name']}');
        print('    距離噴水池: ${distance.toInt()} 公尺');
        print('    位置: ${item['address']}');
        print('----------------------------------------');

        expect(distance, greaterThan(10), reason: '${item['name']} is too close to fountain');
        expect(distance, lessThan(500), reason: '${item['name']} is too far from campus center');
      }
    }
  });
}
