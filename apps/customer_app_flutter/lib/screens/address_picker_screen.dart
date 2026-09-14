import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../booking_provider.dart';
import '../models/customer_profile_models.dart';
import '../services/api_client.dart';
import '../theme.dart';

enum LocationStatus {
  checking,
  permissionRequired,
  gpsDisabled,
  locating,
  located,
  failed,
}

class AddressPickerScreen extends ConsumerStatefulWidget {
  const AddressPickerScreen({super.key});

  @override
  ConsumerState<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends ConsumerState<AddressPickerScreen> {
  final MapController _mapController = MapController();
  LatLng _currentCenter = const LatLng(12.971598, 77.594566); // Default: Bengaluru
  String _addressText = 'Fetching address details...';
  String _areaText = '';
  String _cityText = '';
  String _postalCode = '';
  String _stateText = '';
  LocationStatus _locationStatus = LocationStatus.checking;
  String? _statusMessage;
  bool _isGeocoding = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determinePosition();
    });
  }

  // Get real device current position with full permission state handling
  Future<void> _determinePosition() async {
    setState(() {
      _locationStatus = LocationStatus.checking;
      _statusMessage = 'Checking GPS & permissions...';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatus = LocationStatus.gpsDisabled;
          _statusMessage = 'Device GPS is turned off. Please enable location services.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatus = LocationStatus.permissionRequired;
            _statusMessage = 'Location permission is required to find your exact service address.';
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationStatus = LocationStatus.permissionRequired;
          _statusMessage = 'Location permissions are permanently denied. Please enable them in app settings.';
        });
        return;
      }

      setState(() {
        _locationStatus = LocationStatus.locating;
        _statusMessage = 'Acquiring high-accuracy GPS fix...';
      });

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentCenter = userLatLng;
        _locationStatus = LocationStatus.located;
        _statusMessage = null;
      });

      _mapController.move(userLatLng, 16.5);
      await _reverseGeocode(userLatLng);
    } catch (e) {
      debugPrint('GPS acquisition error: $e');
      setState(() {
        _locationStatus = LocationStatus.failed;
        _statusMessage = 'Could not acquire GPS: $e';
      });
      _reverseGeocode(_currentCenter);
    }
  }

  // Reverse geocoding via OpenStreetMap Nominatim API
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
        'User-Agent': 'BookUrTechnician/1.0 (contact@bookurtechnician.com)',
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final displayName = data['display_name'] as String?;
        final addressObj = data['address'] as Map<String, dynamic>?;

        final suburb = addressObj?['suburb'] ?? addressObj?['neighbourhood'] ?? addressObj?['residential'] ?? '';
        final city = addressObj?['city'] ?? addressObj?['town'] ?? addressObj?['county'] ?? 'Bengaluru';
        final state = addressObj?['state'] ?? 'Karnataka';
        final postcode = addressObj?['postcode'] ?? '560001';

        setState(() {
          _addressText = displayName ?? 'Lat: ${coords.latitude.toStringAsFixed(5)}, Lng: ${coords.longitude.toStringAsFixed(5)}';
          _areaText = suburb.isNotEmpty ? suburb : 'Locality';
          _cityText = city;
          _stateText = state;
          _postalCode = postcode;
        });
      } else {
        setState(() {
          _addressText = 'GPS Location (${coords.latitude.toStringAsFixed(5)}, ${coords.longitude.toStringAsFixed(5)})';
        });
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      setState(() {
        _addressText = 'GPS Location (${coords.latitude.toStringAsFixed(5)}, ${coords.longitude.toStringAsFixed(5)})';
      });
    } finally {
      setState(() {
        _isGeocoding = false;
      });
    }
  }

  Future<void> _saveAndConfirmAddress() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
    });

    final lat = _currentCenter.latitude;
    final lng = _currentCenter.longitude;

    // Update global state with formatted address AND real lat/lng
    ref.read(bookingProvider.notifier).updateAddress(
      _addressText,
      latitude: lat,
      longitude: lng,
    );

    // Save address to backend PostgreSQL database with PostGIS geometry
    try {
      final res = await ApiClient.post('/customer/addresses', {
        'houseFlat': 'Selected Location',
        'street': _addressText,
        'area': _areaText.isNotEmpty ? _areaText : 'Area',
        'city': _cityText.isNotEmpty ? _cityText : 'Bengaluru',
        'state': _stateText.isNotEmpty ? _stateText : 'Karnataka',
        'postalCode': _postalCode.isNotEmpty ? _postalCode : '560001',
        'addressType': 'HOME',
        'latitude': lat,
        'longitude': lng,
        'primary': true,
      });

      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['data'] != null) {
          final addrJson = decoded['data'];
          final now = DateTime.now();
          final savedAddress = CustomerAddress(
            id: addrJson['id']?.toString() ?? 'addr_${now.millisecondsSinceEpoch}',
            customerId: addrJson['customerId']?.toString() ?? 'customer',
            addressType: AddressType.home,
            houseFlat: addrJson['houseFlat'] ?? 'Premises',
            street: addrJson['street'] ?? _addressText,
            area: addrJson['area'] ?? (_areaText.isNotEmpty ? _areaText : 'Area'),
            city: addrJson['city'] ?? (_cityText.isNotEmpty ? _cityText : 'Bengaluru'),
            state: addrJson['state'] ?? (_stateText.isNotEmpty ? _stateText : 'Karnataka'),
            postalCode: addrJson['postalCode'] ?? (_postalCode.isNotEmpty ? _postalCode : '560001'),
            latitude: lat,
            longitude: lng,
            isPrimary: true,
            createdAt: now,
            updatedAt: now,
          );
          ref.read(bookingProvider.notifier).addCustomerAddress(savedAddress);
        }
      }
    } catch (e) {
      debugPrint('Failed to persist address to backend: $e');
    }

    if (mounted) {
      setState(() {
        _isSaving = false;
      });
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Service location confirmed: $_addressText'),
          backgroundColor: kSuccessGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin Service Location'),
        elevation: 0,
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Tile Layer
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentCenter,
              initialZoom: 16.0,
              maxZoom: 18.0,
              minZoom: 10.0,
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
              padding: const EdgeInsets.only(bottom: 38.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kBlack,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: const Text(
                      'Service Location',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Icon(
                    Icons.location_pin,
                    size: 48,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
            ),
          ),

          // 3. Status Alert Banner (GPS disabled / Permissions)
          if (_locationStatus == LocationStatus.gpsDisabled || _locationStatus == LocationStatus.permissionRequired)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade400),
                ),
                child: Row(
                  children: [
                    Icon(
                      _locationStatus == LocationStatus.gpsDisabled ? Icons.location_off : Icons.lock_outline,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage ?? 'Location attention required',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        if (_locationStatus == LocationStatus.gpsDisabled) {
                          await Geolocator.openLocationSettings();
                        } else {
                          await Geolocator.openAppSettings();
                        }
                        _determinePosition();
                      },
                      child: Text(
                        _locationStatus == LocationStatus.gpsDisabled ? 'ENABLE' : 'SETTINGS',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Dynamic Address Display Card (Floating Top)
          if (_locationStatus == LocationStatus.located || _locationStatus == LocationStatus.failed || _locationStatus == LocationStatus.locating)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Theme.of(context).primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SERVICE DELIVERY POINT',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: kTextGray, letterSpacing: 0.8),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _addressText,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: kTextNavy),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lat: ${_currentCenter.latitude.toStringAsFixed(5)}, Lng: ${_currentCenter.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 11, color: kTextGray),
                            ),
                          ],
                        ),
                      ),
                      if (_isGeocoding || _locationStatus == LocationStatus.locating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),
            ),

          // 5. GPS Centering Floating Button
          Positioned(
            bottom: 120,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'gps_fab',
              onPressed: _determinePosition,
              backgroundColor: Colors.white,
              foregroundColor: Theme.of(context).primaryColor,
              elevation: 4,
              child: _locationStatus == LocationStatus.locating || _locationStatus == LocationStatus.checking
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : const Icon(Icons.my_location),
            ),
          ),

          // 6. Save & Confirm Coordinates Footer
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
                        onPressed: _isGeocoding || _isSaving ? null : _saveAndConfirmAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBlack,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Confirm Service Location', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
                        child: const Text('Choose From Saved Addresses', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
