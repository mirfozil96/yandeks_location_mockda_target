import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:http/http.dart' as http;

class Location {
  final String id;
  final double latitude;
  final double longitude;

  Location({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      latitude: double.parse(json['latitude'] as String),
      longitude: double.parse(json['longitude'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
    };
  }
}

class CustomYandexMap extends StatefulWidget {
  const CustomYandexMap({super.key});

  @override
  State<CustomYandexMap> createState() => _CustomYandexMapState();
}

class _CustomYandexMapState extends State<CustomYandexMap> {
  late YandexMapController yandexMapController;
  late Position myPosition;
  bool isLoading = false;
  List<Location> locations = [];
  Location? currentLocation;
  final String apiUrl = 'https://65d3570a522627d50108ac00.mockapi.io/location';
  List<PlacemarkMapObject> placemarks = [];

  void onMapCreated(YandexMapController controller) {
    yandexMapController = controller;
    _determinePosition().then((_) {
      yandexMapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: Point(
              latitude: myPosition.latitude,
              longitude: myPosition.longitude,
            ),
            zoom: 13,
            tilt: 900,
            azimuth: 180,
          ),
        ),
      );
      _fetchLocations(); // Lokatsiyalarni olish
    });
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    myPosition = await Geolocator.getCurrentPosition();
    isLoading = true;
    setState(() {});
    return myPosition;
  }

  void findMe() {
    yandexMapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(
            latitude: myPosition.latitude,
            longitude: myPosition.longitude,
          ),
          zoom: 18,
          tilt: 50,
          azimuth: 180,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 2,
      ),
    );

    yandexMapController.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: Point(
            latitude: myPosition.latitude,
            longitude: myPosition.longitude,
          ),
          zoom: 19,
          tilt: 90,
          azimuth: 180,
        ),
      ),
      animation: const MapAnimation(
        type: MapAnimationType.smooth,
        duration: 4,
      ),
    );
  }

  Future<void> _addLocationFromMap(Point point) async {
    final location = Location(
      id: '', // ID backend tomonidan belgilanadi
      latitude: point.latitude,
      longitude: point.longitude,
    );

    await _addLocation(location); // Lokatsiyani qo'shish
    currentLocation = location;

    // Yeni lokatsiyalarni yuklash
    await _fetchLocations();
    setState(() {});
  }

  Future<void> _fetchLocations() async {
    final response = await http.get(Uri.parse(apiUrl));
    if (response.statusCode == 200) {
      final List<dynamic> locationsJson = json.decode(response.body);
      locations = locationsJson.map((json) => Location.fromJson(json)).toList();
      // Placemarklarni yangilash
      _updatePlacemarks();
      setState(() {});
    } else {
      throw Exception('Failed to load locations');
    }
  }

  Future<void> _addLocation(Location location) async {
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(location.toJson()),
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to add location');
    }

    final jsonResponse = json.decode(response.body);
    currentLocation = Location.fromJson(jsonResponse);
  }

  Future<void> _deleteLocation(Location location) async {
    final response = await http.delete(
      Uri.parse('$apiUrl/${location.id}'),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete location');
    }
  }

  // Placemarklarni locations ro'yxati asosida yangilash
  void _updatePlacemarks() {
    placemarks = locations
        .map((location) => PlacemarkMapObject(
              mapId: MapObjectId(location.id), // Unique ID for each placemark
              point: Point(
                  latitude: location.latitude, longitude: location.longitude),
              opacity: 1,
              direction: 40,
              icon: PlacemarkIcon.single(PlacemarkIconStyle(
                image: BitmapDescriptor.fromAssetImage('assets/place.png'),
              )),

              onTap: (PlacemarkMapObject self, Point point) =>
                  log('Tapped me at $point'),
            ))
        .toList();
  }

  @override
  void initState() {
    _determinePosition();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? Column(
              children: [
                Expanded(
                  child: YandexMap(
                    mapType: MapType.vector,
                    mapObjects: placemarks,
                    onMapCreated: onMapCreated,
                    onMapTap: (Point point) {
                      debugPrint(point.latitude.toString());
                      debugPrint(point.longitude.toString());
                      // _addLocationFromMap(point);
                    },
                    onMapLongTap: (Point point) {
                      debugPrint(point.latitude.toString());
                      debugPrint(point.longitude.toString());
                      _addLocationFromMap(point);
                    },
                  ),
                ),
                SizedBox(
                    height: 200, // or any other height you want
                    child: ListView.builder(
                      itemCount: locations.length,
                      itemBuilder: (BuildContext context, int index) {
                        final location = locations[index];

                        return Dismissible(
                          key: Key(location
                              .id), // Unik klyuch sifatida ID ni ishlatamiz
                          direction:
                              DismissDirection.endToStart, // Yonini aniqlash
                          onDismissed: (direction) {
                            _deleteLocation(location);
                            setState(() {
                              locations.removeAt(index);
                              _updatePlacemarks(); // Update placemarks after deleting
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text('Location ${location.id} deleted')),
                            );
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20.0),
                            color: Colors.red,
                            child:
                                const Icon(Icons.delete, color: Colors.white),
                          ),
                          child: ListTile(
                            title: Text('Location ${location.id}'),
                            subtitle: Text(
                              'Lat: ${location.latitude}, Long: ${location.longitude}',
                            ),
                          ),
                        );
                      },
                    )),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          findMe();
        },
        child: const Icon(Icons.gps_fixed_rounded),
      ),
    );
  }
}
