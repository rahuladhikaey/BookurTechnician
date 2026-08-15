import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../booking_provider.dart';
import '../theme.dart';

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = LatLng(12.971598, 77.594566); // Default: Bengaluru
  String _addressText = 'Fetching address...';
  bool _isLoading = false;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
  }

  // Get device current position
  Future<void> _determinePosition() async {
    setState(() {
      _isLoading = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied.';
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = userLatLng;
      });

      _mapController.move(userLatLng, 16.0);
      _reverseGeocode(userLatLng);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPS Centering Failed: $e')),
        );
      }
      // Fallback geocoding on default center
      _reverseGeocode(_currentCenter);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Reverse geocoding via OSM Nominatim API
  Future<void> _reverseGeocode(LatLng coords) async {
    if (_isGeocoding) return;
    setState(() {
      _isGeocoding = true;
      _addressText = 'Fetching address details...';
    });

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=${coords.latitude}&lon=${coords.longitude}&zoom=18&addressdetails=1',
      );
      
      final response = await http.get(url, headers: {
        'User-Agent': 'BookUrTechnician/1.0',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        setState(() {
          _addressText = displayName ?? 'Unknown Location coords (${coords.latitude.toStringAsFixed(4)}, ${coords.longitude.toStringAsFixed(4)})';
        });
      } else {
        throw 'HTTP Error ${response.statusCode}';
      }
    } catch (e) {
      setState(() {
        _addressText = 'Address unavailable: $e';
      });
    } finally {
      setState(() {
        _isGeocoding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Your Location'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 15.0,
              maxZoom: 18.0,
              minZoom: 12.0,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && position.center != null) {
                  _currentCenter = position.center!;
                }
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd) {
                  _reverseGeocode(_currentCenter);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.bookurtechnician.customer',
              ),
            ],
          ),

          // 2. Fixed Center Pin Overlay (Draggable map moves under this pin)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 38.0), // Adjust to align center of target icon
              child: Icon(
                Icons.location_pin,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),

          // 3. Dynamic Address Display Card (Floating Top)
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(Icons.map, color: Theme.of(context).primaryColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'SELECTING SERVICE ADDRESS',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextGray, letterSpacing: 0.8),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _addressText,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (_isGeocoding)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // 4. GPS Centering floating button
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_fab',
              onPressed: _determinePosition,
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
              elevation: 4,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.gps_fixed),
            ),
          ),

          // 5. Save & Confirm coordinates footer
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -3)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isGeocoding
                            ? null
                            : () {
                                ref.read(bookingProvider.notifier).updateAddress(_addressText);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Address confirmed: $_addressText'),
                                    backgroundColor: kSuccessGreen,
                                  ),
                                );
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Confirm Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/saved_addresses');
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kBrandPrimary,
                          side: const BorderSide(color: kBrandPrimary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Enter Location Manually', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
