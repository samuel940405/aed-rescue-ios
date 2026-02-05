import 'package:shared_preferences/shared_preferences.dart';

class GameService {
  static const String keyPoints = 'user_points';
  static const String keyBadges = 'user_badges';

  Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(keyPoints) ?? 0;
  }

  Future<void> addPoints(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    int current = prefs.getInt(keyPoints) ?? 0;
    await prefs.setInt(keyPoints, current + amount);
    await _checkBadges(current + amount);
  }

  Future<List<String>> getBadges() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(keyBadges) ?? [];
  }

  Future<void> _checkBadges(int totalPoints) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> badges = prefs.getStringList(keyBadges) ?? [];

    if (totalPoints >= 100 && !badges.contains('Scout')) {
      badges.add('Scout');
    }
    if (totalPoints >= 500 && !badges.contains('Guardian')) {
      badges.add('Guardian');
    }
    if (totalPoints >= 1000 && !badges.contains('Hero')) {
      badges.add('Hero');
    }

    await prefs.setStringList(keyBadges, badges);
  }
}
