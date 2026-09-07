import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryUploadService {
  static const String cloudName = 'p1ish280';
  static const String uploadPreset = 'asaliswad_products';
  static const String uploadUrl = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  /// Uploads an XFile directly to Cloudinary and returns the public HTTPS CDN URL.
  static Future<String?> uploadImageFile(XFile file, {String folder = 'kyc_documents'}) async {
    try {
      final bytes = await file.readAsBytes();
      final base64Image = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final response = await dio.post(
        uploadUrl,
        data: {
          'file': base64Image,
          'upload_preset': uploadPreset,
          'folder': folder,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final secureUrl = response.data['secure_url']?.toString();
        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('☁️ [Cloudinary] Upload success: $secureUrl');
          return secureUrl;
        }
      }
    } catch (e) {
      debugPrint('❌ [Cloudinary] Direct upload error: $e');
    }
    return null;
  }
}
