import 'package:flutter/material.dart';
import 'package:picky/components/hbox.dart';
import 'package:picky/components/vbox.dart';
import 'package:picky/pages/detail.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:picky/pages/login.dart';
import 'package:geolocator/geolocator.dart';
import 'package:picky/pages/additem.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> nearbyItems = [];
  List<Map<String, dynamic>> verticalItems = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchItemsNearby();
  }

  Future<void> _fetchItemsNearby() async {
    try {
      final position = await _getCurrentLocation();

      final snapshot =
          await FirebaseFirestore.instance.collection('items').get();

      final allItems = snapshot.docs.map((doc) {
        final data = doc.data();
        final GeoPoint loc = data['location'];
        final double distance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              loc.latitude,
              loc.longitude,
            ) /
            1000; // in km

        return {
          ...data,
          'distance': distance,
        };
      }).toList();

      setState(() {
        nearbyItems = allItems
            .where((item) => item['distance'] <= 20)
            .toList()
            .take(10)
            .toList(); // optional limit

        verticalItems = allItems;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching nearby items: $e");
      setState(() => isLoading = false);
    }
  }

  Future<Position> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      throw Exception('Location service disabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Permission permanently denied');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const LoginPage();
    }

    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddItemPage()),
          );
        },
        backgroundColor: Colors.grey[300],
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // search bar + buttons
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "What are you looking for?",
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[300],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                      icon: const Icon(Icons.settings, color: Colors.grey),
                      onPressed: () {}),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.grey),
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text("Nearby you",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: nearbyItems.isEmpty
                    ? const Center(child: Text("No nearby items"))
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: nearbyItems.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final item = nearbyItems[index];
                          return HorizontalBoxItem(
                            title: item['name'],
                            icon: Icons.place, // fallback
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DetailPage(
                                    title: item['name'],
                                    description:
                                        item['description'] ?? "No description",
                                    location: item['location'] as GeoPoint,
                                    imageUrl: item['imageUrl'] ??
                                        'https://via.placeholder.com/300',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: verticalItems.length,
                  itemBuilder: (context, index) {
                    final item = verticalItems[index];
                    return VerticalBoxItem(
                      name: item['name'],
                      rating: item['rating'].toString(),
                      imageUrl:
                          item['imageUrl'] ?? 'https://via.placeholder.com/150',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DetailPage(
                              title: item['name'],
                              description: item['description'] ??
                                  "No description available.",
                              location: item['location'] as GeoPoint,
                              imageUrl: item['imageUrl'] ??
                                  'https://via.placeholder.com/150',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
