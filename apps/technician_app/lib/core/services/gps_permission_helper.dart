import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

enum GpsFixStatus {
  active,
  gpsDisabled,
  permissionDenied,
  permissionDeniedForever,
  failed,
}

class GpsFixResult {
  final GpsFixStatus status;
  final Position? position;
  final String? address;
  final String message;

  const GpsFixResult({
    required this.status,
    this.position,
    this.address,
    required this.message,
  });

  bool get isSuccess => status == GpsFixStatus.active && position != null;
}

class GpsPermissionHelper {
  /// Ensures location service is enabled and permission is granted.
  /// Automatically requests permission if needed, and shows prompt dialogs if context is provided.
  static Future<GpsFixResult> ensureLocationPermissionAndGps({
    BuildContext? context,
    bool showPromptDialogs = true,
  }) async {
    try {
      // 1. Check if device location service (GPS) is turned on
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context != null && showPromptDialogs && context.mounted) {
          await showGpsDisabledDialog(context);
          // Check again after user returns from settings dialog
          serviceEnabled = await Geolocator.isLocationServiceEnabled();
        }
        if (!serviceEnabled) {
          return const GpsFixResult(
            status: GpsFixStatus.gpsDisabled,
            message: 'Device GPS location service is turned off.',
          );
        }
      }

      // 2. Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Auto-request permission prompt
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (context != null && showPromptDialogs && context.mounted) {
          await showPermissionDeniedDialog(
            context,
            isPermanentlyDenied: false,
          );
        }
        return const GpsFixResult(
          status: GpsFixStatus.permissionDenied,
          message: 'Location permission was denied.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        if (context != null && showPromptDialogs && context.mounted) {
          await showPermissionDeniedDialog(
            context,
            isPermanentlyDenied: true,
          );
        }
        return const GpsFixResult(
          status: GpsFixStatus.permissionDeniedForever,
          message: 'Location permissions are permanently denied in device settings.',
        );
      }

      // 3. Permission granted & GPS active -> Acquire current high accuracy position fix
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );
      } catch (e) {
        debugPrint('[GpsPermissionHelper] High accuracy fix timeout, fetching last known position: $e');
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null) {
        return const GpsFixResult(
          status: GpsFixStatus.failed,
          message: 'Unable to obtain GPS fix coordinates.',
        );
      }

      // 4. Reverse geocode position to user-friendly address string
      final address = await reverseGeocode(position.latitude, position.longitude);

      return GpsFixResult(
        status: GpsFixStatus.active,
        position: position,
        address: address,
        message: 'GPS location acquired successfully.',
      );
    } catch (e) {
      debugPrint('[GpsPermissionHelper] Error during GPS check: $e');
      return GpsFixResult(
        status: GpsFixStatus.failed,
        message: 'GPS Acquisition error: $e',
      );
    }
  }

  /// Reverse geocodes latitude & longitude into readable street / suburb address via OpenStreetMap Nominatim
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );
      final response = await http.get(url, headers: {
        'User-Agent': 'BookUrTechnicianPartner/1.0 (partner@bookurtechnician.com)',
      }).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final addressObj = data['address'] as Map<String, dynamic>?;
        final suburb = addressObj?['suburb'] ??
            addressObj?['neighbourhood'] ??
            addressObj?['residential'] ??
            addressObj?['subdistrict'] ??
            '';
        final city = addressObj?['city'] ??
            addressObj?['town'] ??
            addressObj?['county'] ??
            addressObj?['state_district'] ??
            '';

        if (suburb.isNotEmpty && city.isNotEmpty) {
          return '$suburb, $city';
        } else if (data['display_name'] != null) {
          final parts = (data['display_name'] as String).split(',');
          return parts.take(2).join(',').trim();
        }
      }
    } catch (e) {
      debugPrint('[GpsPermissionHelper] Reverse geocode error: $e');
    }
    return 'Lat: ${lat.toStringAsFixed(4)}, Lng: ${lng.toStringAsFixed(4)}';
  }

  /// Interactive Modal Dialog prompting technician to turn on device GPS
  static Future<void> showGpsDisabledDialog(BuildContext context) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.location_off_rounded, size: 48, color: Color(0xFFEF4444)),
          title: const Text(
            'Device GPS Turned Off',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'BookUrTechnician Partner app requires active device GPS location to send you nearby customer jobs and track en-route service delivery.\n\nPlease enable location services.',
            style: TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: const Icon(Icons.gps_fixed_rounded, size: 18),
              label: const Text('Turn On GPS', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
  }

  /// Modal Dialog guiding technician to grant location permissions
  static Future<void> showPermissionDeniedDialog(
    BuildContext context, {
    required bool isPermanentlyDenied,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          icon: const Icon(Icons.gpp_maybe_rounded, size: 48, color: Color(0xFFF59E0B)),
          title: const Text(
            'Location Access Required',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            textAlign: TextAlign.center,
          ),
          content: Text(
            isPermanentlyDenied
                ? 'Location permission is permanently denied in device settings. Please open app settings and grant Location permission to continue receiving bookings.'
                : 'BookUrTechnician Partner app needs Location permission to verify your service area and update customer live status.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A8A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              icon: Icon(isPermanentlyDenied ? Icons.tune_rounded : Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                isPermanentlyDenied ? 'Open App Settings' : 'Grant Permission',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (isPermanentlyDenied) {
                  await Geolocator.openAppSettings();
                } else {
                  await Geolocator.requestPermission();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
