import 'package:flutter/material.dart';
import '../services/game_service.dart';

class ProfileScreen extends StatelessWidget {
  final GameService _gameService = GameService();

  ProfileScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Rescue Profile')),
      body: FutureBuilder(
        future: Future.wait([
          _gameService.getPoints(),
          _gameService.getBadges()
        ]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final points = snapshot.data![0] as int;
          final badges = snapshot.data![1] as List<String>;

          return Column(
            children: [
              const SizedBox(height: 30),
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.redAccent,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text("Rescue Volunteer", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   _buildStatCard("Points", points.toString()),
                   const SizedBox(width: 20),
                   _buildStatCard("Rescues", (points ~/ 100).toString()),
                ],
              ),
              
              const SizedBox(height: 30),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Badges", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: badges.length,
                  itemBuilder: (context, index) {
                    return Card(
                      color: Colors.amber[100],
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stars, color: Colors.orange, size: 40),
                          const SizedBox(height: 5),
                          Text(badges[index], style: const TextStyle(fontWeight: FontWeight.bold))
                        ],
                      ),
                    );
                  },
                ),
              )
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.red)),
            Text(label, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
