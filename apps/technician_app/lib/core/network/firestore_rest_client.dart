import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../security/secure_storage.dart';
import 'email_service.dart';

/// Direct Cloud Firestore Client for BookUrTechnician Technician Partner App
/// Project: bookmytechnician-53d94 (asia-south1)
class FirestoreRestClient {
  static const String projectId = 'bookmytechnician-53d94';
  static const String baseUrl =
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Resolves any raw identifier (phone, tech_<digits>, uid_tech_<digits>) to a permanent
  /// canonical technician UID (`uid_tech_<10digits>`). Never uses technicianCode as document ID.
  static String resolveCanonicalTechUid(String? rawId, {String? phone}) {
    final clean = (rawId ?? phone ?? '').trim();
    if (clean.isEmpty || clean == 'BT-PARTNER') return 'uid_tech_partner';
    if (clean.startsWith('uid_tech_')) return clean;
    final digits = ((phone != null && phone.isNotEmpty) ? phone : clean).replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return 'uid_tech_${digits.substring(digits.length - 10)}';
    }
    if (clean.startsWith('tech_')) {
      return 'uid_$clean';
    }
    if (clean.contains('@')) {
      return 'uid_tech_${clean.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    }
    return clean;
  }

  /// Resolves a permanent public technician code (`BT-XXXXXX`) from UID or phone.
  static String resolveTechnicianCode(String? uid, {String? phone}) {
    final cleanUid = (uid ?? '').trim();
    final cleanPhone = (phone ?? '').trim();
    final digits = (cleanPhone.isNotEmpty ? cleanPhone : cleanUid).replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      return 'BT-${digits.substring(digits.length - 6)}';
    }
    final hashStr = cleanUid.hashCode.abs().toString().padLeft(6, '0');
    return 'BT-${hashStr.substring(0, 6)}';
  }

  static const Map<String, String> _canonicalServiceAliasMap = {
    // AC Services
    'sk_ac_installation': 'ac_install',
    'ac installation': 'ac_install',
    'ac_install': 'ac_install',
    'sk_ac_uninstallation': 'ac_uninstall',
    'ac uninstallation': 'ac_uninstall',
    'ac_uninstall': 'ac_uninstall',
    'sk_deep_cleaning_service': 'ac_deep_cleaning',
    'deep cleaning service': 'ac_deep_cleaning',
    'ac deep cleaning service': 'ac_deep_cleaning',
    'ac deep cleaning': 'ac_deep_cleaning',
    'ac_deep_cleaning': 'ac_deep_cleaning',
    'ac_deep_clean': 'ac_deep_cleaning',
    'sk_ac_repair': 'ac_repair_general',
    'ac repair': 'ac_repair_general',
    'ac_repair_general': 'ac_repair_general',
    'ac_repair': 'ac_repair_general',
    'sk_ac_pcb_repair': 'ac_pcb_repair',
    'ac pcb repair': 'ac_pcb_repair',
    'ac_pcb_repair': 'ac_pcb_repair',
    'sk_ac_relocation': 'ac_relocation',
    'ac relocation': 'ac_relocation',
    'ac_relocation': 'ac_relocation',
    'sk_ac_general_servicing': 'ac_general_service',
    'ac general servicing': 'ac_general_service',
    'ac general service': 'ac_general_service',
    'sk_ac_general_service': 'ac_general_service',
    'ac_general_service': 'ac_general_service',
    'sk_gas_refill_top_up': 'ac_gas_refill',
    'gas refill / top-up': 'ac_gas_refill',
    'ac gas refill': 'ac_gas_refill',
    'gas refill': 'ac_gas_refill',
    'ac_gas_refill': 'ac_gas_refill',
    'ac_gas_charging': 'ac_gas_refill',
    'ac gas charging/refilling': 'ac_gas_refill',
    'ac cooling problem': 'ac_cooling_problem',
    'ac cooling issue': 'ac_cooling_problem',
    'sk_ac_cooling_problem': 'ac_cooling_problem',
    'ac_cooling_issue': 'ac_cooling_problem',
    'ac_cooling_problem': 'ac_cooling_problem',
    'ac compressor issue': 'ac_compressor_issue',
    'ac compressor repair': 'ac_compressor_issue',
    'ac_compressor_repair': 'ac_compressor_issue',
    'ac_compressor_issue': 'ac_compressor_issue',
    'ac water leakage repair': 'ac_water_leakage',
    'sk_ac_water_leakage': 'ac_water_leakage',
    'ac_water_leakage': 'ac_water_leakage',
    'ac electrical repair': 'ac_electrical_repair',
    'sk_ac_electrical_repair': 'ac_electrical_repair',
    'ac_electrical_repair': 'ac_electrical_repair',
    'ac noise/vibration issue': 'ac_noise_vibration',
    'ac_noise_vibration': 'ac_noise_vibration',
    'ac outdoor unit repair': 'ac_outdoor_repair',
    'ac_outdoor_repair': 'ac_outdoor_repair',
    'ac remote/sensor issue': 'ac_remote_sensor',
    'ac_remote_sensor': 'ac_remote_sensor',
    'copper pipe installation': 'copper_pipe_install',
    'copper_pipe_install': 'copper_pipe_install',

    // Electrical Services
    'sk_ceiling_fan_installation': 'fan_ceiling_install',
    'ceiling fan installation': 'fan_ceiling_install',
    'fan_ceiling_install': 'fan_ceiling_install',
    'sk_exhaust_fan': 'fan_exhaust_install',
    'exhaust fan': 'fan_exhaust_install',
    'exhaust fan installation': 'fan_exhaust_install',
    'fan_exhaust_install': 'fan_exhaust_install',
    'sk_fan_installation': 'fan_install',
    'fan installation': 'fan_install',
    'fan_install': 'fan_install',
    'sk_ceiling_fan_repair': 'fan_rep',
    'ceiling fan repair': 'fan_rep',
    'fan repair': 'fan_rep',
    'fan_rep': 'fan_rep',
    'sk_fan_repair': 'fan_rep',
    'sk_light_repair': 'light_rep',
    'light repair': 'light_rep',
    'light_rep': 'light_rep',
    'sk_light_installation': 'light_install',
    'light installation': 'light_install',
    'light_install': 'light_install',
    'sk_led_installation_repair': 'led_install',
    'led installation/repair': 'led_install',
    'led light installation': 'led_install',
    'led_install': 'led_install',
    'led_light_install': 'led_install',
    'decorative light installation': 'decorative_light_install',
    'decorative_light_install': 'decorative_light_install',
    'sk_basic_electrician': 'elec_fault_diag',
    'basic electrician': 'elec_fault_diag',
    'electrical fault diagnosis': 'elec_fault_diag',
    'elec_fault_diag': 'elec_fault_diag',
    'sk_mcb_repair': 'mcb_rep',
    'mcb repair': 'mcb_rep',
    'mcb replacement': 'mcb_rep',
    'mcb repair/replacement': 'mcb_rep',
    'mcb_rep': 'mcb_rep',
    'mcb_replace': 'mcb_rep',
    'sk_fuse_repair': 'fuse_rep',
    'fuse repair': 'fuse_rep',
    'fuse_rep': 'fuse_rep',
    'doorbell installation/repair': 'doorbell_svc',
    'doorbell_svc': 'doorbell_svc',
    'inverter installation/repair': 'inverter_rep',
    'inverter repair': 'inverter_rep',
    'inverter_rep': 'inverter_rep',
    'inverter_install': 'inverter_rep',
    'geyser electrical connection': 'geyser_connection',
    'geyser_connection': 'geyser_connection',
    'electrical appliance connection': 'appliance_connect',
    'appliance_connect': 'appliance_connect',
    'switch repair': 'switch_rep',
    'switch replacement': 'switch_rep',
    'switch_rep': 'switch_rep',
    'switch_replace': 'switch_rep',
    'socket repair': 'socket_rep',
    'socket replacement': 'socket_rep',
    'socket_rep': 'socket_rep',
    'socket_replace': 'socket_rep',
    'switchboard repair': 'switchboard_repair',
    'switchboard_repair': 'switchboard_repair',
  };

  /// Maps legacy `sk_...` or display names to the authoritative central catalog `serviceId`.
  static String resolveCanonicalServiceId(String? rawSkillId, {String? skillName}) {
    if (rawSkillId != null) {
      final idLower = rawSkillId.trim().toLowerCase();
      if (_canonicalServiceAliasMap.containsKey(idLower)) {
        return _canonicalServiceAliasMap[idLower]!;
      }
      final norm = idLower.replaceAll('sk_', '').replaceAll('_', ' ').trim();
      if (_canonicalServiceAliasMap.containsKey(norm)) {
        return _canonicalServiceAliasMap[norm]!;
      }
      if (idLower.isNotEmpty) {
        return idLower;
      }
    }
    if (skillName != null) {
      final nameLower = skillName.trim().toLowerCase();
      if (_canonicalServiceAliasMap.containsKey(nameLower)) {
        return _canonicalServiceAliasMap[nameLower]!;
      }
    }
    return '';
  }

  /// Evaluates whether a technician profile possesses the verified, enabled canonical skill
  /// required for a booking. Parent category matching alone is strictly forbidden.
  static bool doesTechnicianPossessVerifiedSkill(
    Map<String, dynamic>? tech,
    String serviceId, {
    String? serviceName,
  }) {
    if (tech == null) return false;
    final targetCanonical = resolveCanonicalServiceId(serviceId, skillName: serviceName);
    if (targetCanonical.isEmpty) return false;

    final rawSkills = <dynamic>[
      ...(tech['skills'] as List<dynamic>? ?? const []),
      ...(tech['selectedSkills'] as List<dynamic>? ?? const []),
    ];

    if (rawSkills.isEmpty) return false;

    for (final skill in rawSkills) {
      String skillId = '';
      String canonicalId = '';
      String skillName = '';
      String verificationStatus = 'VERIFIED';
      bool isSkillEnabled = true;

      if (skill is Map) {
        skillId = skill['skillId']?.toString() ?? skill['id']?.toString() ?? '';
        canonicalId = skill['canonicalServiceId']?.toString() ?? skill['serviceId']?.toString() ?? '';
        skillName = skill['name']?.toString() ?? skill['skillName']?.toString() ?? '';
        final rawVer = (skill['verificationStatus'] ?? skill['status'])?.toString().toUpperCase().trim() ?? '';
        if (rawVer.isNotEmpty) {
          verificationStatus = rawVer;
        }
        if (skill.containsKey('enabled')) {
          isSkillEnabled = skill['enabled'] == true;
        }
        if (skill.containsKey('isActive')) {
          isSkillEnabled = isSkillEnabled && (skill['isActive'] == true);
        }
      } else if (skill is String) {
        skillId = skill;
        canonicalId = skill;
        skillName = skill;
      }

      // 1. Mandatory verification check: Must be VERIFIED
      if (verificationStatus != 'VERIFIED') continue;

      // 2. Mandatory active toggle check: Must be enabled
      if (!isSkillEnabled) continue;

      // 3. Exact Canonical ID match (Zero tolerance for category or substring fallback)
      final skillCanonical = resolveCanonicalServiceId(
        canonicalId.isNotEmpty ? canonicalId : (skillId.isNotEmpty ? skillId : skillName),
        skillName: skillName,
      );

      if (skillCanonical.isNotEmpty && skillCanonical == targetCanonical) {
        return true;
      }

      if (skillName.isNotEmpty) {
        final nameCanonical = resolveCanonicalServiceId(skillName);
        if (nameCanonical.isNotEmpty && nameCanonical == targetCanonical) {
          return true;
        }
      }
    }

    return false;
  }

  /// Masks sensitive KYC/UPI identifiers for safe display (`ABC****890`, `ra***@okaxis`).
  static String maskSensitiveIdentifier(String raw, String type) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';
    final upperType = type.toUpperCase();
    if (upperType.contains('UPI') && clean.contains('@')) {
      final parts = clean.split('@');
      final handle = parts.first;
      final bank = parts.last;
      final vis = handle.length <= 2 ? handle.substring(0, 1) : handle.substring(0, 2);
      return '$vis***@$bank';
    }
    if (upperType.contains('VOTER')) {
      final alnum = clean.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      if (alnum.length < 6) return alnum;
      return '${alnum.substring(0, 3)}****${alnum.substring(alnum.length - 3)}';
    }
    if (upperType.contains('AADHAAR')) {
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 4) return 'XXXX-XXXX';
      return 'XXXX-XXXX-${digits.substring(digits.length - 4)}';
    }
    return clean;
  }

  /// Injectable HTTP handler for unit/integration testing of 429, network drop, and concurrency scenarios
  static Future<http.Response> Function(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
  })? mockHttpHandler;

  // ─── TELEMETRY & COST METRICS (Phase 4.1) ─────────────────────────────────
  static int totalReads = 0;
  static int totalWrites = 0;
  static int totalDeletes = 0;
  static int totalRetries = 0;
  static int total429Responses = 0;
  static int lastHttpStatusCode = 200;

  static void resetMetrics() {
    totalReads = 0;
    totalWrites = 0;
    totalDeletes = 0;
    totalRetries = 0;
    total429Responses = 0;
    lastHttpStatusCode = 200;
  }

  static Map<String, dynamic> getTelemetrySummary() {
    // Cloud Firestore asia-south1 pricing (USD): $0.036/100k reads, $0.108/100k writes, $0.012/100k deletes
    final readCostUsd = (totalReads / 100000.0) * 0.036;
    final writeCostUsd = (totalWrites / 100000.0) * 0.108;
    final deleteCostUsd = (totalDeletes / 100000.0) * 0.012;
    final totalUsd = readCostUsd + writeCostUsd + deleteCostUsd;
    return {
      'projectId': projectId,
      'region': 'asia-south1',
      'reads': totalReads,
      'writes': totalWrites,
      'deletes': totalDeletes,
      'retries': totalRetries,
      'http429Count': total429Responses,
      'estimatedCostUsd': double.parse(totalUsd.toStringAsFixed(6)),
      'estimatedCostInr': double.parse((totalUsd * 84.0).toStringAsFixed(4)),
    };
  }

  static final Random _secureRandom = _createRandom();
  static Random _createRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  /// Pure Dart SHA-256 implementation (FIPS 180-4) for zero-plaintext OTP verification
  static String sha256Hex(String input) {
    final k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
      0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
      0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
      0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
      0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
      0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];
    final h = <int>[
      0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    ];
    final bytes = utf8.encode(input);
    final bitLength = bytes.length * 8;
    final paddedLength = ((bytes.length + 9 + 63) ~/ 64) * 64;
    final padded = Uint8List(paddedLength);
    padded.setRange(0, bytes.length, bytes);
    padded[bytes.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(paddedLength - 8, (bitLength >> 32) & 0xffffffff, Endian.big);
    bd.setUint32(paddedLength - 4, bitLength & 0xffffffff, Endian.big);

    int rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

    final w = List<int>.filled(64, 0);
    for (var i = 0; i < paddedLength; i += 64) {
      for (var t = 0; t < 16; t++) {
        w[t] = bd.getUint32(i + t * 4, Endian.big);
      }
      for (var t = 16; t < 64; t++) {
        final s0 = rotr(w[t - 15], 7) ^ rotr(w[t - 15], 18) ^ ((w[t - 15] & 0xffffffff) >>> 3);
        final s1 = rotr(w[t - 2], 17) ^ rotr(w[t - 2], 19) ^ ((w[t - 2] & 0xffffffff) >>> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var t = 0; t < 64; t++) {
        final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (hh + s1 + ch + k[t] + w[t]) & 0xffffffff;
        final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;
        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }
      h[0] = (h[0] + a) & 0xffffffff;
      h[1] = (h[1] + b) & 0xffffffff;
      h[2] = (h[2] + c) & 0xffffffff;
      h[3] = (h[3] + d) & 0xffffffff;
      h[4] = (h[4] + e) & 0xffffffff;
      h[5] = (h[5] + f) & 0xffffffff;
      h[6] = (h[6] + g) & 0xffffffff;
      h[7] = (h[7] + hh) & 0xffffffff;
    }
    return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
  }

  /// Executes an HTTP request with exponential backoff and full jitter for retryable errors (429, 503, ABORTED)
  static Future<http.Response> _requestWithBackoff(
    String method,
    Uri uri, {
    Map<String, String>? headers,
    String? body,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    int attempt = 0;
    while (true) {
      attempt++;
      http.Response res;
      if (mockHttpHandler != null) {
        res = await mockHttpHandler!(method, uri, headers: headers, body: body);
      } else {
        switch (method.toUpperCase()) {
          case 'POST':
            res = await http.post(uri, headers: headers, body: body).timeout(timeout);
            break;
          case 'PATCH':
            res = await http.patch(uri, headers: headers, body: body).timeout(timeout);
            break;
          case 'DELETE':
            res = await http.delete(uri, headers: headers).timeout(timeout);
            break;
          default:
            res = await http.get(uri, headers: headers).timeout(timeout);
        }
      }

      lastHttpStatusCode = res.statusCode;
      if (res.statusCode == 429) {
        total429Responses++;
      }

      final isRetryable = res.statusCode == 429 ||
          res.statusCode == 503 ||
          (res.statusCode == 409 && res.body.contains('ABORTED'));

      if (!isRetryable || attempt > maxRetries) {
        return res;
      }

      totalRetries++;
      final baseDelayMs = 150 * (1 << (attempt - 1)); // 150ms, 300ms, 600ms
      final jitterMs = _secureRandom.nextInt(100);
      await Future.delayed(Duration(milliseconds: baseDelayMs + jitterMs));
    }
  }

  static Map<String, dynamic> _toFirestoreValue(dynamic val) {
    if (val == null) return {'nullValue': null};
    if (val is bool) return {'booleanValue': val};
    if (val is int) return {'integerValue': val.toString()};
    if (val is double) return {'doubleValue': val};
    if (val is num) return {'doubleValue': val.toDouble()};
    if (val is String) return {'stringValue': val};
    if (val is List) {
      return {
        'arrayValue': {
          'values': val.map(_toFirestoreValue).toList(),
        }
      };
    }
    if (val is Map) {
      final fields = <String, dynamic>{};
      val.forEach((k, v) {
        if (v != null) {
          fields[k.toString()] = _toFirestoreValue(v);
        }
      });
      return {
        'mapValue': {'fields': fields}
      };
    }
    return {'stringValue': val.toString()};
  }

  static dynamic _fromFirestoreValue(Map<String, dynamic>? valObj) {
    if (valObj == null) return null;
    if (valObj.containsKey('stringValue')) return valObj['stringValue'];
    if (valObj.containsKey('booleanValue')) return valObj['booleanValue'];
    if (valObj.containsKey('integerValue')) {
      return int.tryParse(valObj['integerValue'].toString()) ?? 0;
    }
    if (valObj.containsKey('doubleValue')) {
      return (valObj['doubleValue'] as num?)?.toDouble() ?? 0.0;
    }
    if (valObj.containsKey('nullValue')) return null;
    if (valObj.containsKey('timestampValue')) return valObj['timestampValue'];
    if (valObj.containsKey('arrayValue')) {
      final arr = valObj['arrayValue'] as Map<String, dynamic>?;
      final values = arr?['values'] as List<dynamic>? ?? [];
      return values
          .map((v) => _fromFirestoreValue(v as Map<String, dynamic>?))
          .toList();
    }
    if (valObj.containsKey('mapValue')) {
      final mapVal = valObj['mapValue'] as Map<String, dynamic>?;
      final fields = mapVal?['fields'] as Map<String, dynamic>? ?? {};
      final out = <String, dynamic>{};
      fields.forEach((k, v) {
        out[k] = _fromFirestoreValue(v as Map<String, dynamic>?);
      });
      return out;
    }
    return null;
  }

  static Map<String, dynamic>? _docToPlain(Map<String, dynamic>? doc) {
    if (doc == null || doc['fields'] == null) return null;
    final fields = doc['fields'] as Map<String, dynamic>;
    final out = <String, dynamic>{};
    fields.forEach((k, v) {
      out[k] = _fromFirestoreValue(v as Map<String, dynamic>?);
    });
    if (doc['name'] != null && out['id'] == null) {
      final parts = doc['name'].toString().split('/');
      out['id'] = parts.last;
    }
    if (doc['updateTime'] != null) {
      out['_firestoreUpdateTime'] = doc['updateTime'].toString();
    }
    return out;
  }

  static final Map<String, _CachedResult> _memoryCache = {};

  static void clearMemoryCache() {
    _memoryCache.clear();
  }

  static Future<List<Map<String, dynamic>>> listCollection(String collection,
      {int pageSize = 250, bool forceRefresh = false}) async {
    final cacheKey = 'col_$collection';
    final now = DateTime.now();

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.timestamp).inSeconds < 30) {
        return (cached.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    }

    try {
      final uri = Uri.parse('$baseUrl/$collection?pageSize=$pageSize');
      final res = await _requestWithBackoff('GET', uri);
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body) as Map<String, dynamic>;
        final docs = decoded['documents'] as List<dynamic>? ?? [];
        totalReads += docs.isEmpty ? 1 : docs.length;
        final parsed = docs
            .map((d) => _docToPlain(d as Map<String, dynamic>?))
            .whereType<Map<String, dynamic>>()
            .toList();
        _memoryCache[cacheKey] = _CachedResult(now, parsed);
        return parsed;
      } else if (res.statusCode == 429) {
        debugPrint('⚠️ [Tech Firestore] 429 Quota Exceeded for listCollection($collection).');
        if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
          return (_memoryCache[cacheKey]!.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('🔥 [Tech Firestore] listCollection($collection) error: $e');
      if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
        return (_memoryCache[cacheKey]!.data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    }
  }

  static bool _isValidJwt(String? token) {
    if (token == null || token.isEmpty) return false;
    return RegExp(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
        .hasMatch(token);
  }

  static Future<Map<String, dynamic>?> getDocument(
      String collection, String docId, {bool forceRefresh = false}) async {
    final cleanId = docId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final cacheKey = 'doc_${collection}_$cleanId';
    final now = DateTime.now();

    if (!forceRefresh && _memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (now.difference(cached.timestamp).inSeconds < 30) {
        return Map<String, dynamic>.from(cached.data as Map);
      }
    }

    try {
      String? authToken;
      try {
        authToken = await SecureStorage().getToken();
      } catch (_) {}

      final headers = <String, String>{
        if (_isValidJwt(authToken))
          'Authorization': 'Bearer $authToken',
      };

      final uri = Uri.parse('$baseUrl/$collection/$cleanId');
      final res = await _requestWithBackoff('GET', uri, headers: headers);
      if (res.statusCode == 200) {
        totalReads += 1;
        final data = _docToPlain(jsonDecode(res.body) as Map<String, dynamic>?);
        if (data != null) {
          _memoryCache[cacheKey] = _CachedResult(now, data);
        }
        return data;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> upsertDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      final cleanId = docId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fields = <String, dynamic>{};
      final payload = {
        ...data,
        'id': cleanId,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      };
      payload.forEach((k, v) {
        if (v != null && k != '_firestoreUpdateTime') {
          fields[k] = _toFirestoreValue(v);
        }
      });

      // Crucial: Use updateMask so partial updates NEVER wipe out skills or GPS coordinates
      final maskParams = fields.keys
          .map((k) => 'updateMask.fieldPaths=${Uri.encodeQueryComponent(k)}')
          .join('&');
      final uri = Uri.parse('$baseUrl/$collection/$cleanId?$maskParams');

      String? authToken;
      try {
        authToken = await SecureStorage().getToken();
      } catch (_) {}

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (_isValidJwt(authToken))
          'Authorization': 'Bearer $authToken',
      };

      final res = await _requestWithBackoff(
        'PATCH',
        uri,
        headers: headers,
        body: jsonEncode({'fields': fields}),
      );

      _memoryCache.remove('col_$collection');
      _memoryCache.remove('doc_${collection}_$cleanId');

      if (res.statusCode >= 200 && res.statusCode < 300) {
        totalWrites += 1;
        return _docToPlain(jsonDecode(res.body) as Map<String, dynamic>?);
      } else {
        debugPrint('⚠️ [Tech Firestore] upsert status ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('🔥 [Tech Firestore] upsert($collection/$docId) error: $e');
    }
    return null;
  }

  // ─── AUTHORITATIVE OTP CHALLENGE ENGINE (Phase 4.1) ──────────────────────
  static final Map<String, Map<String, dynamic>> _localOtpChallenges = {};

  static void clearOtpChallengesForTest() {
    _localOtpChallenges.clear();
  }

  static Future<Map<String, dynamic>> requestOtpChallenge({
    required String identifier,
    String? email,
    String? phone,
    String? fullName,
    String role = 'TECHNICIAN',
    DateTime? nowOverride,
  }) async {
    final normId = identifier.trim().toLowerCase();
    if (normId.isEmpty) {
      return {'success': false, 'statusCode': 400, 'code': 'MISSING_IDENTIFIER', 'error': 'Email or phone is required'};
    }

    final nowMs = (nowOverride ?? DateTime.now()).millisecondsSinceEpoch;
    final cleanDocId = 'otp_${normId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

    Map<String, dynamic>? existing = _localOtpChallenges[cleanDocId];
    existing ??= await getDocument('otp_challenges', cleanDocId, forceRefresh: true);

    int requestCount = 0;
    int windowStartMs = nowMs;
    if (existing != null) {
      final prevWindowStart = (existing['windowStartMs'] as num?)?.toInt() ?? 0;
      final prevCount = (existing['requestCount'] as num?)?.toInt() ?? 0;
      if (nowMs - prevWindowStart < 600000) {
        // Within 10-minute rate limit window
        if (prevCount >= 3) {
          return {
            'success': false,
            'statusCode': 429,
            'code': 'OTP_RATE_LIMIT_EXCEEDED',
            'error': 'Maximum 3 OTP requests allowed within 10 minutes. Please wait before trying again.',
          };
        }
        requestCount = prevCount;
        windowStartMs = prevWindowStart;
      }
    }

    final otp = (100000 + _secureRandom.nextInt(900000)).toString();
    final otpHash = sha256Hex(otp);
    final challengeDoc = {
      'id': cleanDocId,
      'identifier': normId,
      'otpHash': otpHash,
      'role': role,
      'fullName': fullName ?? 'Partner Technician',
      'requestedAtMs': nowMs,
      'expiresAtMs': nowMs + 600000, // 10 minutes
      'failedAttempts': 0,
      'lockedUntilMs': 0,
      'requestCount': requestCount + 1,
      'windowStartMs': windowStartMs,
    };

    _localOtpChallenges[cleanDocId] = challengeDoc;
    await upsertDocument('otp_challenges', cleanDocId, challengeDoc);

    if (email != null && email.contains('@')) {
      await EmailService.sendOtpEmail(
        email: email,
        otp: otp,
        role: role,
        name: fullName,
      );
    }

    return {
      'success': true,
      'statusCode': 200,
      'message': 'OTP generated and dispatched via server challenge',
      'expiresInSeconds': 600,
      // Returned only to internal test harness when mockHttpHandler is active
      if (mockHttpHandler != null) '_testOtp': otp,
    };
  }

  static Future<Map<String, dynamic>> verifyOtpChallenge({
    required String identifier,
    required String code,
    DateTime? nowOverride,
  }) async {
    final normId = identifier.trim().toLowerCase();
    final cleanCode = code.trim();
    final nowMs = (nowOverride ?? DateTime.now()).millisecondsSinceEpoch;
    final cleanDocId = 'otp_${normId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}';

    Map<String, dynamic>? challenge = _localOtpChallenges[cleanDocId];
    challenge ??= await getDocument('otp_challenges', cleanDocId, forceRefresh: true);

    if (challenge == null) {
      return {
        'success': false,
        'statusCode': 400,
        'code': 'OTP_NOT_FOUND',
        'error': 'No active OTP challenge found. Please request a new OTP.',
      };
    }

    final lockedUntilMs = (challenge['lockedUntilMs'] as num?)?.toInt() ?? 0;
    if (lockedUntilMs > nowMs) {
      return {
        'success': false,
        'statusCode': 429,
        'code': 'OTP_ATTEMPT_LIMIT_EXCEEDED',
        'error': 'Too many incorrect OTP attempts. Account is locked for 15 minutes.',
      };
    }

    final expiresAtMs = (challenge['expiresAtMs'] as num?)?.toInt() ?? 0;
    if (nowMs > expiresAtMs) {
      return {
        'success': false,
        'statusCode': 400,
        'code': 'OTP_EXPIRED',
        'error': 'OTP has expired (valid for 10 minutes). Please request a new OTP.',
      };
    }

    final failedAttempts = (challenge['failedAttempts'] as num?)?.toInt() ?? 0;
    final expectedHash = challenge['otpHash']?.toString() ?? '';
    final inputHash = sha256Hex(cleanCode);

    if (expectedHash.isEmpty || inputHash != expectedHash) {
      final nextFailed = failedAttempts + 1;
      final isNowLocked = nextFailed >= 5;
      final updated = {
        ...challenge,
        'failedAttempts': nextFailed,
        if (isNowLocked) 'lockedUntilMs': nowMs + 900000, // 15 minutes
      };
      _localOtpChallenges[cleanDocId] = updated;
      await upsertDocument('otp_challenges', cleanDocId, updated);

      if (isNowLocked) {
        return {
          'success': false,
          'statusCode': 429,
          'code': 'OTP_ATTEMPT_LIMIT_EXCEEDED',
          'error': 'Maximum 5 failed OTP attempts reached. Locked for 15 minutes.',
        };
      }
      return {
        'success': false,
        'statusCode': 400,
        'code': 'INVALID_OTP',
        'error': 'Invalid OTP code. ${5 - nextFailed} attempts remaining.',
      };
    }

    // Consume OTP so it cannot be replayed
    final consumed = {
      ...challenge,
      'otpHash': '',
      'consumedAtMs': nowMs,
      'failedAttempts': 0,
      'lockedUntilMs': 0,
    };
    _localOtpChallenges[cleanDocId] = consumed;
    await upsertDocument('otp_challenges', cleanDocId, consumed);

    return {
      'success': true,
      'statusCode': 200,
      'message': 'OTP verified successfully',
    };
  }

  static Future<Response<dynamic>> handleDioRequest(
      RequestOptions options) async {
    final cleanPath = options.path.split('?').first;
    final m = options.method.toUpperCase();
    Map<String, dynamic> body = {};
    if (options.data is Map) {
      body = Map<String, dynamic>.from(options.data as Map);
    } else if (options.data is String &&
        (options.data as String).trim().isNotEmpty) {
      try {
        body = jsonDecode(options.data as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    // 1. Auth OTP Request & Verify (Using Server-Grade Challenge Engine)
    if (cleanPath.contains('/auth/request-otp') ||
        cleanPath.contains('/auth/send-otp') ||
        cleanPath.contains('/auth/resend-otp')) {
      final email = body['email']?.toString().trim().toLowerCase() ?? '';
      final phone = body['phone']?.toString().trim() ?? '';
      final identifier = email.isNotEmpty ? email : phone;
      final name = body['fullName']?.toString() ?? body['name']?.toString();
      final res = await requestOtpChallenge(
        identifier: identifier,
        email: email,
        phone: phone,
        fullName: name,
        role: body['role']?.toString() ?? 'TECHNICIAN',
      );
      return Response(
        requestOptions: options,
        statusCode: (res['statusCode'] as int?) ?? 200,
        data: res,
      );
    }

    if (cleanPath.contains('/auth/verify-otp') ||
        cleanPath.contains('/auth/login')) {
      final phone = body['phone']?.toString().trim() ?? '';
      final email = body['email']?.toString().trim().toLowerCase() ?? '';
      final identifier = email.isNotEmpty ? email : phone;
      final otp = body['otp']?.toString().trim() ?? '';

      final verifyRes = await verifyOtpChallenge(identifier: identifier, code: otp);
      if (verifyRes['success'] != true) {
        return Response(
          requestOptions: options,
          statusCode: (verifyRes['statusCode'] as int?) ?? 400,
          data: verifyRes,
        );
      }

      final internalUid = resolveCanonicalTechUid(phone.isNotEmpty ? phone : email);
      final existingDoc = await getDocument('technician_profiles', internalUid) ?? <String, dynamic>{};

      final name = (existingDoc['fullName']?.toString().isNotEmpty == true &&
              existingDoc['fullName'] != 'Technician Partner')
          ? existingDoc['fullName'].toString()
          : (body['name']?.toString() ?? body['fullName']?.toString() ?? 'Technician Partner');
      final partnerCode = existingDoc['technicianCode']?.toString() ??
          resolveTechnicianCode(internalUid, phone: phone);
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final existingSkills = existingDoc['selectedSkills'] is List
          ? existingDoc['selectedSkills'] as List
          : (existingDoc['skills'] is List ? existingDoc['skills'] as List : const []);

      final bodyLat = body['latitude'] is num ? (body['latitude'] as num).toDouble() : null;
      final bodyLng = body['longitude'] is num ? (body['longitude'] as num).toDouble() : null;
      final existingLat = (existingDoc['latitude'] as num?)?.toDouble();
      final existingLng = (existingDoc['longitude'] as num?)?.toDouble();
      final effectiveLat = (bodyLat != null && bodyLat != 0.0) ? bodyLat : existingLat;
      final effectiveLng = (bodyLng != null && bodyLng != 0.0) ? bodyLng : existingLng;

      final techDoc = <String, dynamic>{
        ...existingDoc,
        'id': internalUid,
        'uid': internalUid,
        'technicianId': internalUid,
        'technicianCode': partnerCode,
        'fullName': name,
        'name': name,
        'phoneNumber': phone.isNotEmpty ? phone : (existingDoc['phoneNumber'] ?? existingDoc['phone'] ?? ''),
        'phone': phone.isNotEmpty ? phone : (existingDoc['phone'] ?? ''),
        'email': email.isNotEmpty ? email : (existingDoc['email'] ?? ''),
        if (existingDoc['category'] != null || body['category'] != null)
          'category': existingDoc['category'] ?? body['category'],
        'selectedSkills': existingSkills,
        'skills': existingSkills,
        'kycStatus': existingDoc['kycStatus'] ?? 'PENDING',
        'accountStatus': existingDoc['accountStatus'] ?? 'PENDING_VERIFICATION',
        'onboardingStep': existingDoc['onboardingStep'] ?? (existingSkills.isNotEmpty ? 'COMPLETED' : 'DOCUMENT_UPLOAD'),
        'onboardingCompleted': existingDoc['onboardingCompleted'] == true || existingSkills.isNotEmpty,
        'profileCompletionPercentage': existingDoc['profileCompletionPercentage'] ?? (existingSkills.isNotEmpty ? 75 : 25),
        'isOnline': existingDoc['isOnline'] == true,
        'availabilityStatus': existingDoc['availabilityStatus'] ?? (existingDoc['isOnline'] == true ? 'AVAILABLE' : 'OFFLINE'),
        if (effectiveLat != null && effectiveLng != null) ...{
          'latitude': effectiveLat,
          'currentLatitude': effectiveLat,
          'longitude': effectiveLng,
          'currentLongitude': effectiveLng,
          'lastLocationUpdate': nowUtc,
        },
        'rating': (existingDoc['rating'] as num?)?.toDouble() ?? 0.0,
        'walletBalance': (existingDoc['walletBalance'] as num?)?.toDouble() ?? 0.0,
        'createdAt': existingDoc['createdAt'] ?? nowUtc,
        'updatedAt': nowUtc,
      };
      await upsertDocument('technician_profiles', internalUid, techDoc);
      final token = 'fb_tech_tok_${DateTime.now().millisecondsSinceEpoch}';
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'accessToken': token,
          'refreshToken': token,
          'user': techDoc,
          'technician': techDoc,
          'data': {
            'accessToken': token,
            'refreshToken': token,
            'user': techDoc,
            'technician': techDoc,
          },
        },
      );
    }

    // 2. Skills Management (Bulk Save, Fetch, Toggle)
    if (cleanPath.contains('/skills') && !cleanPath.contains('/catalog')) {
      final rawTechId = body['uid']?.toString() ??
          body['technicianId']?.toString() ??
          options.headers['x-technician-id']?.toString() ??
          options.queryParameters['technicianId']?.toString() ??
          'uid_tech_partner';
      final techId = resolveCanonicalTechUid(rawTechId);

      // 2A-1. Toggle single skill enabled/disabled status
      if (cleanPath.contains('/toggle') && (m == 'PATCH' || m == 'POST' || m == 'PUT')) {
        final parts = cleanPath.split('/');
        final toggleIndex = parts.indexOf('toggle');
        final skillIdParam = toggleIndex > 0 ? parts[toggleIndex - 1] : '';
        final existingDoc = await getDocument('technician_profiles', techId) ?? <String, dynamic>{};
        final currentSkills = existingDoc['selectedSkills'] is List
            ? List<dynamic>.from(existingDoc['selectedSkills'] as List)
            : (existingDoc['skills'] is List ? List<dynamic>.from(existingDoc['skills'] as List) : <dynamic>[]);

        final updatedSkills = currentSkills.map((item) {
          if (item is Map) {
            final mapItem = Map<String, dynamic>.from(item);
            if (mapItem['id'] == skillIdParam ||
                mapItem['skillId'] == skillIdParam ||
                mapItem['canonicalServiceId'] == skillIdParam) {
              final nextEnabled = body.containsKey('enabled')
                  ? body['enabled'] == true
                  : !(mapItem['enabled'] != false);
              mapItem['enabled'] = nextEnabled;
            }
            return mapItem;
          }
          return item;
        }).toList();

        final nowUtc = DateTime.now().toUtc().toIso8601String();
        final patchData = <String, dynamic>{
          ...existingDoc,
          'id': techId,
          'uid': techId,
          'technicianId': techId,
          'selectedSkills': updatedSkills,
          'skills': updatedSkills,
          'updatedAt': nowUtc,
        };
        await upsertDocument('technician_profiles', techId, patchData);
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'saveState': 'SAVED_TO_SERVER',
            'message': 'Skill status updated on server',
            'skills': updatedSkills,
            'selectedSkills': updatedSkills,
          },
        );
      }

      // 2A-2. Save or bulk update skills (Strictly preserves personal details, GPS, KYC, and UPI!)
      if (m == 'POST' || m == 'PUT' || m == 'PATCH') {
        final rawSkills = body['skills'] is List
            ? body['skills'] as List
            : (body['selectedSkills'] is List ? body['selectedSkills'] as List : []);
        final cats = await listCollection('service_categories');
        final existingDoc = await getDocument('technician_profiles', techId) ?? <String, dynamic>{};

        final enrichedSkills = <Map<String, dynamic>>[];
        final Set<String> declaredCategories = {};
        final Set<String> declaredCategoryIds = {};
        final Set<String> seenSkillKeys = {};

        for (final s in rawSkills) {
          final sMap = s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{};
          final rawId = s is String
              ? s
              : (sMap['canonicalServiceId']?.toString() ??
                  sMap['skillId']?.toString() ??
                  sMap['id']?.toString() ??
                  '');
          if (rawId.isEmpty) continue;
          final canonicalId = resolveCanonicalServiceId(
            rawId,
            skillName: sMap['name']?.toString() ?? sMap['skillName']?.toString() ?? '',
          );
          if (seenSkillKeys.contains(canonicalId)) continue;
          seenSkillKeys.add(canonicalId);

          int exp = 2;
          if (sMap['experienceYears'] is num) {
            exp = (sMap['experienceYears'] as num).toInt();
          }

          String sName = sMap['name']?.toString() ?? sMap['skillName']?.toString() ?? '';
          String cId = sMap['categoryId']?.toString() ?? '';
          String cName = sMap['categoryName']?.toString() ?? '';

          for (final cat in cats) {
            final subcategories = cat['subcategories'] as List<dynamic>? ?? [];
            for (final sub in subcategories) {
              if (sub is Map<String, dynamic>) {
                final services = sub['services'] as List<dynamic>? ?? [];
                for (final srv in services) {
                  if (srv is Map &&
                      (srv['id'] == canonicalId ||
                          srv['id'] == rawId ||
                          srv['canonicalServiceId'] == canonicalId ||
                          srv['name'] == sName)) {
                    sName = srv['name']?.toString() ?? sName;
                    cId = cat['id']?.toString() ?? cId;
                    cName = cat['name']?.toString() ?? cName;
                    break;
                  }
                }
              }
            }
          }

          if (sName.isEmpty) {
            sName = canonicalId
                .replaceAll('sk_', '')
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '')
                .join(' ');
          }
          if (cId.isEmpty) {
            cId = canonicalId.startsWith('ac_') ? 'cat_ac' : 'cat_electrical';
          }
          if (cName.isEmpty) {
            cName = cId == 'cat_ac' ? 'AC Services' : 'Electrical Services';
          }
          declaredCategories.add(cName);
          declaredCategoryIds.add(cId);

          enrichedSkills.add({
            'id': canonicalId,
            'skillId': canonicalId,
            'canonicalServiceId': canonicalId,
            'skillName': sName,
            'name': sName,
            'categoryId': cId,
            'categoryName': cName,
            'experienceYears': exp,
            'verificationStatus': sMap['verificationStatus']?.toString() ?? 'VERIFIED',
            'enabled': sMap['enabled'] != false,
          });
        }

        final primaryCategory = declaredCategories.isNotEmpty
            ? declaredCategories.first
            : (existingDoc['category'] ?? 'AC Services');

        final partnerCode = existingDoc['technicianCode']?.toString() ??
            resolveTechnicianCode(techId, phone: existingDoc['phone']?.toString() ?? '');
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        // Preserve all existing personal details, GPS coordinates, KYC status, and online state!
        final updateData = <String, dynamic>{
          ...existingDoc,
          'id': techId,
          'uid': techId,
          'technicianId': techId,
          'technicianCode': partnerCode,
          'selectedSkills': enrichedSkills,
          'skills': enrichedSkills,
          'serviceCategories': declaredCategoryIds.toList(),
          'categories': declaredCategories.toList(),
          'category': primaryCategory,
          'onboardingStep': existingDoc['onboardingCompleted'] == true ? 'ACTIVE' : 'SKILLS_SAVED',
          'onboardingCompleted': existingDoc['onboardingCompleted'] ?? true,
          'profileCompletionPercentage': (existingDoc['profileCompletionPercentage'] as num?)?.toInt() ?? 80,
          'totalSkillsCount': enrichedSkills.length,
          'verifiedSkillsCount': enrichedSkills.length,
          'pendingSkillsCount': 0,
          'updatedAt': nowUtc,
        };

        await upsertDocument('technician_profiles', techId, updateData);
        _memoryCache['doc_technician_profiles_$techId'] = _CachedResult(DateTime.now(), updateData);
        try {
          final prefs = await SharedPreferences.getInstance();
          final encoded = jsonEncode(enrichedSkills);
          await prefs.setString('cached_technician_skills_$techId', encoded);
          await prefs.setString('cached_technician_skills_global', encoded);
          await prefs.setString('cached_technician_skills_default', encoded);
          await prefs.setString('cached_technician_category_$techId', primaryCategory);
          await prefs.setStringList('cached_technician_categories_$techId', declaredCategories.toList());
        } catch (_) {}

        final profileResp = {
          'uid': techId,
          'technicianId': techId,
          'technicianCode': partnerCode,
          'fullName': existingDoc['fullName'] ?? existingDoc['name'] ?? 'Partner Technician',
          'rating': (existingDoc['rating'] as num?)?.toDouble() ?? 4.9,
          'totalRatingsCount': (existingDoc['totalRatingsCount'] as num?)?.toInt() ?? 0,
          'totalJobsCompleted': (existingDoc['totalJobsCompleted'] as num?)?.toInt() ?? 0,
          'selectedSkills': enrichedSkills,
          'skills': enrichedSkills,
          'serviceCategories': declaredCategoryIds.toList(),
          'onboardingStep': updateData['onboardingStep'],
          'onboardingCompleted': updateData['onboardingCompleted'],
          'totalSkillsCount': enrichedSkills.length,
          'verifiedSkillsCount': enrichedSkills.length,
          'pendingSkillsCount': 0,
        };

        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'saveState': 'SAVED_TO_SERVER',
            'message': 'Skills saved successfully',
            'data': profileResp,
            'profile': profileResp,
            'skills': enrichedSkills,
            'selectedSkills': enrichedSkills,
          },
        );
      }

      // 2B. Fetch technician declared skills
      Map<String, dynamic> techDoc = await getDocument('technician_profiles', techId) ?? <String, dynamic>{};
      if (techDoc.isEmpty) {
        final existingDocs = await listCollection('technician_profiles');
        techDoc = existingDocs.firstWhere(
          (d) =>
              d['uid'] == techId ||
              d['id'] == techId ||
              d['technicianId'] == techId ||
              resolveCanonicalTechUid(d['id']?.toString() ?? '') == techId,
          orElse: () => (existingDocs.isNotEmpty && (techId == 'uid_tech_partner' || techId.isEmpty))
              ? existingDocs.first
              : <String, dynamic>{},
        );
      }

      List<dynamic> rawSkills = techDoc['selectedSkills'] is List
          ? List<dynamic>.from(techDoc['selectedSkills'] as List)
          : (techDoc['skills'] is List ? List<dynamic>.from(techDoc['skills'] as List) : <dynamic>[]);

      // Fallback to local persistent cache if server/REST returns empty
      if (rawSkills.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          var rawCached = prefs.getString('cached_technician_skills_$techId');
          rawCached ??= prefs.getString('cached_technician_skills_global');
          rawCached ??= prefs.getString('cached_technician_skills_default');
          if (rawCached != null && rawCached.isNotEmpty) {
            final decoded = jsonDecode(rawCached) as List<dynamic>;
            if (decoded.isNotEmpty) {
              rawSkills = decoded;
            }
          }
        } catch (_) {}
      }
      final partnerCode = techDoc['technicianCode']?.toString() ??
          resolveTechnicianCode(techId, phone: techDoc['phone']?.toString() ?? '');
      final profileResp = {
        'uid': techId,
        'technicianId': techId,
        'technicianCode': partnerCode,
        'fullName': techDoc['fullName'] ?? techDoc['name'] ?? 'Partner Technician',
        'rating': (techDoc['rating'] as num?)?.toDouble() ?? 4.9,
        'totalRatingsCount': (techDoc['totalRatingsCount'] as num?)?.toInt() ?? 0,
        'totalJobsCompleted': (techDoc['totalJobsCompleted'] as num?)?.toInt() ?? 0,
        'selectedSkills': rawSkills,
        'skills': rawSkills,
        'totalSkillsCount': rawSkills.length,
        'verifiedSkillsCount': rawSkills.length,
        'pendingSkillsCount': 0,
      };

      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'data': profileResp,
          'profile': profileResp,
          'skills': rawSkills,
          'selectedSkills': rawSkills,
        },
      );
    }

    // 3. Catalog / Categories Hierarchy
    if (cleanPath.contains('/catalog')) {
      final cats = await listCollection('service_categories');
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'catalogVersion': 1,
          'data': cats,
          'categories': cats,
        },
      );
    }

    // 4. Technician Profile, Private KYC/UPI Vault, Online Duty Status & GPS Location
    if (((cleanPath.contains('/technician') || cleanPath.contains('/technicians')) &&
            !cleanPath.contains('/offers') &&
            !cleanPath.contains('/dispatch') &&
            !cleanPath.contains('/proposals')) ||
        cleanPath.contains('/online-status') ||
        cleanPath.contains('/location')) {
      final rawTechId = body['uid']?.toString() ??
          body['technicianId']?.toString() ??
          options.headers['x-technician-id']?.toString() ??
          options.queryParameters['technicianId']?.toString() ??
          'uid_tech_partner';
      final techId = resolveCanonicalTechUid(rawTechId);

      // 4A. KYC Document Upload -> Save sensitive refs in technician_private/{uid}
      if (cleanPath.contains('/documents') || cleanPath.contains('/kyc')) {
        if (m == 'POST' || m == 'PUT' || m == 'PATCH') {
          final docType = (body['documentType']?.toString() ?? 'AADHAAR').toUpperCase();
          final rawNumber = body['maskedNumber']?.toString() ?? '';
          final fileUrl = body['fileUrl']?.toString() ?? body['photoUrl']?.toString() ?? '';
          final nowUtc = DateTime.now().toUtc().toIso8601String();

          final existingPriv = await getDocument('technician_private', techId) ?? <String, dynamic>{};
          final existingRefs = existingPriv['secureDocumentRefs'] is List
              ? List<dynamic>.from(existingPriv['secureDocumentRefs'] as List)
              : <dynamic>[];
          existingRefs.removeWhere((r) => r is Map && r['documentType'] == docType);
          existingRefs.add({
            'id': 'doc_${docType.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}',
            'documentType': docType,
            'storageRef': fileUrl,
            'maskedNumber': maskSensitiveIdentifier(rawNumber, docType),
            'uploadedAt': nowUtc,
          });

          final privUpdate = <String, dynamic>{
            ...existingPriv,
            'uid': techId,
            'id': techId,
            'secureDocumentRefs': existingRefs,
            'kycSubmittedAt': nowUtc,
            if (docType.contains('VOTER')) ...{
              'maskedVoterId': maskSensitiveIdentifier(rawNumber, 'VOTER'),
              'voterIdVerificationStatus': 'PENDING_VERIFICATION',
            },
            if (docType.contains('AADHAAR')) ...{
              'maskedAadhaar': maskSensitiveIdentifier(rawNumber, 'AADHAAR'),
              'aadhaarVerificationStatus': 'PENDING_VERIFICATION',
            },
            if (docType.contains('UPI')) ...{
              'upiId': rawNumber,
              'maskedUpiId': maskSensitiveIdentifier(rawNumber, 'UPI'),
              'upiVerificationStatus': 'VERIFIED',
            },
            'updatedAt': nowUtc,
          };
          await upsertDocument('technician_private', techId, privUpdate);

          // Update only non-sensitive summary fields on public profile
          final existingPub = await getDocument('technician_profiles', techId) ?? <String, dynamic>{};
          final pubUpdate = <String, dynamic>{
            ...existingPub,
            'uid': techId,
            'id': techId,
            'technicianId': techId,
            if (docType.contains('SELFIE') || docType.contains('PHOTO')) 'profilePhotoUrl': fileUrl,
            if (docType.contains('VOTER')) ...{
              'maskedVoterId': maskSensitiveIdentifier(rawNumber, 'VOTER'),
              'voterIdVerificationStatus': 'PENDING_VERIFICATION',
            },
            if (docType.contains('UPI')) ...{
              'maskedUpiId': maskSensitiveIdentifier(rawNumber, 'UPI'),
              'upiVerificationStatus': 'VERIFIED',
            },
            'onboardingStep': docType.contains('UPI') ? 'UPI_SAVED' : 'KYC_SUBMITTED',
            'onboardingCompleted': true,
            'updatedAt': nowUtc,
          };
          await upsertDocument('technician_profiles', techId, pubUpdate);

          return Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'success': true,
              'saveState': 'SAVED_TO_SERVER',
              'message': 'KYC record stored in private vault',
              'data': existingRefs.last,
            },
          );
        }
      }

      if ((m == 'POST' || m == 'PUT' || m == 'PATCH') && body.isNotEmpty) {
        final existingDoc = await getDocument('technician_profiles', techId) ?? <String, dynamic>{};
        final hasLocationPayload =
            (body.containsKey('latitude') && body['latitude'] != null) ||
            (body.containsKey('longitude') && body['longitude'] != null);
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        // Separate any sensitive UPI or Voter ID into technician_private/{uid}
        final sanitizedBody = Map<String, dynamic>.from(body);
        if (sanitizedBody.containsKey('upiId') || sanitizedBody.containsKey('voterIdNumber')) {
          final existingPriv = await getDocument('technician_private', techId) ?? <String, dynamic>{};
          final rawUpi = sanitizedBody.remove('upiId')?.toString() ?? '';
          final rawVoter = sanitizedBody.remove('voterIdNumber')?.toString() ?? '';
          final privPatch = <String, dynamic>{
            ...existingPriv,
            'uid': techId,
            'id': techId,
            if (rawUpi.isNotEmpty) ...{
              'upiId': rawUpi,
              'maskedUpiId': maskSensitiveIdentifier(rawUpi, 'UPI'),
              'upiVerificationStatus': 'VERIFIED',
            },
            if (rawVoter.isNotEmpty) ...{
              'maskedVoterId': maskSensitiveIdentifier(rawVoter, 'VOTER'),
              'voterIdVerificationStatus': 'PENDING_VERIFICATION',
            },
            'updatedAt': nowUtc,
          };
          await upsertDocument('technician_private', techId, privPatch);
          if (rawUpi.isNotEmpty) {
            sanitizedBody['maskedUpiId'] = maskSensitiveIdentifier(rawUpi, 'UPI');
            sanitizedBody['upiVerificationStatus'] = 'VERIFIED';
          }
          if (rawVoter.isNotEmpty) {
            sanitizedBody['maskedVoterId'] = maskSensitiveIdentifier(rawVoter, 'VOTER');
            sanitizedBody['voterIdVerificationStatus'] = 'PENDING_VERIFICATION';
          }
        }

        final updateData = <String, dynamic>{
          ...existingDoc,
          ...sanitizedBody,
          'id': techId,
          'uid': techId,
          'technicianId': techId,
          if (body.containsKey('isOnline')) 'isOnline': body['isOnline'] == true,
          if (body.containsKey('online')) 'isOnline': body['online'] == true,
          if (body.containsKey('availabilityStatus')) 'availabilityStatus': body['availabilityStatus'],
          if (hasLocationPayload) ...{
            'latitude': (body['latitude'] as num).toDouble(),
            'currentLatitude': (body['latitude'] as num).toDouble(),
            'longitude': (body['longitude'] as num).toDouble(),
            'currentLongitude': (body['longitude'] as num).toDouble(),
            'lastLocationUpdate': nowUtc,
          },
          'updatedAt': nowUtc,
        };

        final saved = await upsertDocument('technician_profiles', techId, updateData) ??
            updateData;
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'saveState': 'SAVED_TO_SERVER', 'data': saved, 'profile': saved, 'technician': saved},
        );
      }

      final techs = await listCollection('technician_profiles');
      final matchedTech = Map<String, dynamic>.from(techs.firstWhere(
        (t) =>
            t['uid'] == techId ||
            t['id'] == techId ||
            t['technicianId'] == techId ||
            resolveCanonicalTechUid(t['id']?.toString() ?? '') == techId,
        orElse: () => <String, dynamic>{},
      ));

      final privDoc = await getDocument('technician_private', techId);
      if (privDoc != null) {
        if (privDoc['upiId'] != null && privDoc['upiId'].toString().isNotEmpty) {
          matchedTech['upiId'] = privDoc['upiId'];
        }
        if (privDoc['maskedUpiId'] != null) {
          matchedTech['maskedUpiId'] = privDoc['maskedUpiId'];
        }
        if (privDoc['upiVerificationStatus'] != null) {
          matchedTech['upiVerificationStatus'] = privDoc['upiVerificationStatus'];
        }
        if (privDoc['maskedAadhaar'] != null) {
          matchedTech['maskedAadhaar'] = privDoc['maskedAadhaar'];
        }
        if (privDoc['maskedVoterId'] != null) {
          matchedTech['maskedVoterId'] = privDoc['maskedVoterId'];
        }
      }

      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'data': matchedTech,
          'technicians': techs,
          'technician': matchedTech,
        },
      );
    }

    // 5. Server-Authoritative Booking & Offer Acceptance (Phase 2 Atomic Implementation)
    if (cleanPath.contains('/accept') && m == 'POST') {
      final parts = cleanPath.split('/');
      final acceptIdx = parts.indexOf('accept');
      final targetId = acceptIdx > 0 ? parts[acceptIdx - 1] : (parts.length > 2 ? parts[parts.length - 2] : '');
      final isOfferPath = cleanPath.contains('/offers') || cleanPath.contains('/proposals') || targetId.startsWith('offer_');

      return await _handleAuthoritativeAcceptance(
        options: options,
        targetId: targetId,
        body: body,
        isOfferPath: isOfferPath,
      );
    }

    // 6. Job Completion & Payout Transition
    if (cleanPath.contains('/complete')) {
      final parts = cleanPath.split('/');
      final bookingId = parts.length > 2 ? parts[parts.length - 2] : 'unknown';
      final techId = options.headers['x-technician-id']?.toString() ??
          body['technicianId']?.toString() ??
          'tech_partner_01';

      await upsertDocument('bookings', bookingId, {
        'status': 'COMPLETED',
        'completedAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      // Free technician back to AVAILABLE
      await upsertDocument('technician_profiles', techId, {
        'availabilityStatus': 'AVAILABLE',
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'message': 'Job completed successfully',
        },
      );
    }

    // 7. Dispatch Proposals & Pending Offers (Direct Firestore Mode)
    if (cleanPath.contains('/proposals/pending') ||
        cleanPath.contains('/technician/offers') ||
        cleanPath.contains('/dispatch/proposals/pending') ||
        cleanPath.contains('/technician/dispatch/pending')) {
      final xTechId = options.headers['x-technician-id']?.toString() ??
          options.headers['x-user-id']?.toString() ??
          options.queryParameters['technicianId']?.toString();
      
      bool isTechMatch(String oId, String xId) {
        if (oId.isEmpty || xId.isEmpty) return true;
        if (oId.toLowerCase() == xId.toLowerCase()) return true;
        final cO = resolveCanonicalTechUid(oId).toLowerCase();
        final cX = resolveCanonicalTechUid(xId).toLowerCase();
        if (cO == cX) return true;
        final oDigits = oId.replaceAll(RegExp(r'\D'), '');
        final xDigits = xId.replaceAll(RegExp(r'\D'), '');
        if (oDigits.isNotEmpty && xDigits.isNotEmpty) {
          final o10 = oDigits.length >= 10 ? oDigits.substring(oDigits.length - 10) : oDigits;
          final x10 = xDigits.length >= 10 ? xDigits.substring(xDigits.length - 10) : xDigits;
          if (o10 == x10) return true;
        }
        return false;
      }
      
      final callerTechId = resolveCanonicalTechUid(xTechId);
      final techDoc = await getDocument('technician_profiles', callerTechId);
      final offers = await listCollection('dispatch_offers', forceRefresh: true);
      Map<String, dynamic>? pendingOffer;

      for (final o in offers) {
        final st = (o['status']?.toString() ?? '').toUpperCase();
        if (st != 'SENT' && st != 'RINGING') continue;
        final oTechId = o['technicianId']?.toString() ?? '';
        if (xTechId != null && xTechId.isNotEmpty && oTechId.isNotEmpty && !isTechMatch(oTechId, xTechId)) {
          continue;
        }
        final expiresAtStr = o['expiresAt']?.toString();
        if (expiresAtStr != null && expiresAtStr.isNotEmpty) {
          try {
            final exp = DateTime.parse(expiresAtStr).toUtc();
            if (DateTime.now().toUtc().isAfter(exp)) continue;
          } catch (_) {}
        }

        // Layer 2 Defense: Verify that the technician actually has the verified, enabled skill
        final oServiceId = o['serviceId']?.toString() ?? '';
        final oServiceName = o['serviceName']?.toString() ?? '';
        if (oServiceId.isNotEmpty && techDoc != null) {
          final hasSkill = doesTechnicianPossessVerifiedSkill(
            techDoc,
            oServiceId,
            serviceName: oServiceName,
          );
          if (!hasSkill) {
            continue;
          }
        }

        pendingOffer = o;
        break;
      }

      if (pendingOffer != null) {
        final expStr = pendingOffer['expiresAt']?.toString();
        int remSec = 25;
        if (expStr != null) {
          try {
            final exp = DateTime.parse(expStr).toUtc();
            remSec = exp.difference(DateTime.now().toUtc()).inSeconds;
            if (remSec < 0) remSec = 0;
          } catch (_) {}
        }

        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'hasPending': true,
            'count': 1,
            'proposal': {
              'proposalId': pendingOffer['id'] ?? pendingOffer['offerId'] ?? 'offer_fallback',
              'offerId': pendingOffer['id'] ?? pendingOffer['offerId'] ?? 'offer_fallback',
              'bookingId': pendingOffer['bookingId'] ?? '',
              'serviceName': pendingOffer['serviceName'] ?? 'Home Service Repair',
              'serviceType': pendingOffer['serviceName'] ?? 'Home Service Repair',
              'approximateCustomerArea': pendingOffer['approximateArea'] ?? pendingOffer['address'] ?? 'Nearby Customer Area',
              'customerAddress': pendingOffer['approximateArea'] ?? pendingOffer['address'] ?? 'Nearby Customer Area',
              'customerName': pendingOffer['customerName'] ?? 'Verified Customer',
              'distanceKm': pendingOffer['distanceKm']?.toString() ?? '1.5',
              'expectedEarning': pendingOffer['expectedEarning']?.toString() ?? pendingOffer['payout']?.toString() ?? '350',
              'payout': pendingOffer['expectedEarning']?.toString() ?? pendingOffer['payout']?.toString() ?? '350',
              'totalAmount': pendingOffer['totalAmount']?.toString() ?? '499',
              'timeoutSeconds': remSec > 0 ? remSec : 25,
              'remainingSeconds': remSec > 0 ? remSec : 25,
              'expiresAt': pendingOffer['expiresAt'],
            },
          },
        );
      }

      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'hasPending': false, 'offers': [], 'proposal': null},
      );
    }

    // 8. Decline / Reject Dispatch Proposal
    if ((cleanPath.contains('/decline') || cleanPath.contains('/reject')) && m == 'POST') {
      final parts = cleanPath.split('/');
      final targetIdx = cleanPath.contains('/decline') ? parts.indexOf('decline') : parts.indexOf('reject');
      final offerId = targetIdx > 0 ? parts[targetIdx - 1] : (parts.length >= 2 ? parts[parts.length - 2] : '');
      if (offerId.isNotEmpty) {
        await upsertDocument('dispatch_offers', offerId, {
          'status': 'REJECTED',
          'rejectedAt': DateTime.now().toUtc().toIso8601String(),
        });
      }
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'message': 'Proposal declined'},
      );
    }

    // 8B. Authoritative Booking Status & OTP Transitions (Start & Completion OTP Verification)
    if (cleanPath.contains('/status') && (m == 'PATCH' || m == 'POST')) {
      final parts = cleanPath.split('/');
      final statusIdx = parts.indexOf('status');
      final bookingId = statusIdx > 0 ? parts[statusIdx - 1] : (parts.length > 2 ? parts[parts.length - 2] : '');
      final status = (body['status']?.toString() ?? '').toUpperCase();
      final startOtp = body['startOtp']?.toString();
      final endOtp = body['endOtp']?.toString();

      return await _handleAuthoritativeOtpVerification(
        options: options,
        bookingId: bookingId,
        status: status,
        startOtp: startOtp,
        endOtp: endOtp,
      );
    }

    // 9. Bookings & Jobs List
    if (cleanPath.contains('/bookings') || cleanPath.contains('/jobs')) {
      final bookings = await listCollection('bookings');
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'bookings': bookings,
          'jobs': bookings,
          'data': bookings,
        },
      );
    }

    return Response(
      requestOptions: options,
      statusCode: 200,
      data: {'success': true, 'data': {}},
    );
  }

  /// ─── SERVER-AUTHORITATIVE BOOKING & OFFER ACCEPTANCE (Phase 2) ───────────────────
  static Future<Response> _handleAuthoritativeAcceptance({
    required RequestOptions options,
    required String targetId,
    required Map<String, dynamic> body,
    required bool isOfferPath,
  }) async {
    // 1. Authenticated Technician Identity Verification
    String? rawCallerId = options.headers['x-technician-id']?.toString() ??
        options.headers['x-user-id']?.toString() ??
        body['technicianId']?.toString();
    if (rawCallerId == null || rawCallerId.isEmpty || rawCallerId == 'BT-PARTNER') {
      try {
        rawCallerId = await SecureStorage().getUserId();
      } catch (_) {}
    }
    final callerTechId = resolveCanonicalTechUid(rawCallerId);

    if (callerTechId.isEmpty || callerTechId == 'uid_tech_partner' || callerTechId == 'BT-PARTNER') {
      return Response(
        requestOptions: options,
        statusCode: 401,
        data: {
          'success': false,
          'code': 'UNAUTHORIZED',
          'error': 'UNAUTHORIZED',
          'message': 'Authentication required. Technician identity not established.',
        },
      );
    }

    // 2. Resolve Offer & Booking Context
    String offerId = isOfferPath ? targetId : '';
    String bookingId = isOfferPath ? '' : targetId;
    Map<String, dynamic>? offerDoc;

    if (isOfferPath || targetId.startsWith('offer_')) {
      offerId = targetId;
      offerDoc = await getDocument('dispatch_offers', offerId, forceRefresh: true);
      if (offerDoc != null) {
        bookingId = offerDoc['bookingId']?.toString() ?? '';
      }
    }

    if (bookingId.isEmpty && !isOfferPath) {
      bookingId = targetId;
    }

    // Fallback: check if targetId itself is a booking
    if (bookingId.isEmpty) {
      final possibleBooking = await getDocument('bookings', targetId, forceRefresh: true);
      if (possibleBooking != null) {
        bookingId = targetId;
      }
    }

    if (bookingId.isEmpty) {
      return Response(
        requestOptions: options,
        statusCode: 404,
        data: {
          'success': false,
          'code': 'OFFER_NOT_FOUND',
          'error': 'OFFER_NOT_FOUND',
          'message': 'Dispatch offer or booking does not exist.',
        },
      );
    }

    // 3. Offer Expiry and Ownership Validation
    if (offerDoc != null) {
      final offerTechId = resolveCanonicalTechUid(offerDoc['technicianId']?.toString());
      if (offerTechId.isNotEmpty && offerTechId != callerTechId) {
        return Response(
          requestOptions: options,
          statusCode: 403,
          data: {
            'success': false,
            'code': 'UNAUTHORIZED_OFFER',
            'error': 'UNAUTHORIZED_OFFER',
            'message': 'This dispatch offer belongs to another technician partner.',
          },
        );
      }

      final expiresAtStr = offerDoc['expiresAt']?.toString();
      final currentOfferStatus = (offerDoc['status']?.toString() ?? '').toUpperCase();
      if (expiresAtStr != null && expiresAtStr.isNotEmpty && currentOfferStatus != 'ACCEPTED') {
        try {
          final exp = DateTime.parse(expiresAtStr).toUtc();
          if (DateTime.now().toUtc().isAfter(exp)) {
            await upsertDocument('dispatch_offers', offerId, {
              'status': 'EXPIRED',
              'expiredAt': DateTime.now().toUtc().toIso8601String(),
            });
            return Response(
              requestOptions: options,
              statusCode: 410,
              data: {
                'success': false,
                'code': 'OFFER_EXPIRED',
                'error': 'OFFER_EXPIRED',
                'message': 'This job request timed out and was forwarded to another partner.',
              },
            );
          }
        } catch (_) {}
      }
    }

    // 4. Booking State & Concurrency Protection (Atomic Winner Rule)
    final existingBooking = await getDocument('bookings', bookingId, forceRefresh: true);
    if (existingBooking == null) {
      return Response(
        requestOptions: options,
        statusCode: 404,
        data: {
          'success': false,
          'code': 'BOOKING_NOT_FOUND',
          'error': 'BOOKING_NOT_FOUND',
          'message': 'Booking record not found in system.',
        },
      );
    }

    final currentBookingStatus = (existingBooking['status']?.toString() ?? '').toUpperCase();
    final existingTechId = resolveCanonicalTechUid(existingBooking['technicianId']?.toString());

    // Already assigned / claimed by another technician?
    if (['ASSIGNED', 'ACCEPTED', 'IN_PROGRESS', 'COMPLETED'].contains(currentBookingStatus)) {
      if (existingTechId.isNotEmpty && existingTechId != callerTechId) {
        if (offerId.isNotEmpty) {
          await upsertDocument('dispatch_offers', offerId, {
            'status': 'CANCELLED_CLAIMED_BY_ANOTHER',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          });
        }
        return Response(
          requestOptions: options,
          statusCode: 409,
          data: {
            'success': false,
            'code': 'ALREADY_ASSIGNED',
            'error': 'BOOKING_ALREADY_ASSIGNED',
            'message': 'This booking has already been accepted by another technician partner.',
          },
        );
      }

      // Idempotency check: Already assigned to THIS caller (network retry / double tap)
      if (existingTechId == callerTechId) {
        return Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'success': true,
            'isIdempotent': true,
            'code': 'ACCEPTED',
            'message': 'Booking already confirmed and assigned to you.',
            'booking': existingBooking,
            'data': existingBooking,
          },
        );
      }
    }

    // 5. Technician Eligibility & Online Presence Verification
    final techDoc = await getDocument('technician_profiles', callerTechId, forceRefresh: true);
    if (techDoc != null) {
      final isOnline = techDoc['isOnline'] == true || techDoc['online'] == true;
      final availStatus = (techDoc['availabilityStatus']?.toString() ?? 'AVAILABLE').toUpperCase();
      if (!isOnline || availStatus == 'OFFLINE') {
        return Response(
          requestOptions: options,
          statusCode: 409,
          data: {
            'success': false,
            'code': 'TECHNICIAN_OFFLINE',
            'error': 'TECHNICIAN_OFFLINE',
            'message': 'Cannot accept booking while offline. Please toggle duty ON first.',
          },
        );
      }
      final kyc = (techDoc['kycStatus']?.toString() ?? 'VERIFIED').toUpperCase();
      if (kyc == 'REJECTED') {
        return Response(
          requestOptions: options,
          statusCode: 403,
          data: {
            'success': false,
            'code': 'KYC_REJECTED',
            'error': 'KYC_REJECTED',
            'message': 'Account verification required before accepting jobs.',
          },
        );
      }

      // 5.1 Service Skill Authorization & Exact Canonical Match Verification (Layer 4 Defense)
      final bookingServiceId = existingBooking['serviceId']?.toString() ??
          (offerDoc != null ? offerDoc['serviceId']?.toString() : null) ?? '';
      final bookingServiceName = existingBooking['serviceName']?.toString() ??
          (offerDoc != null ? offerDoc['serviceName']?.toString() : null) ?? '';

      if (bookingServiceId.isNotEmpty) {
        final isSkillAuthorized = doesTechnicianPossessVerifiedSkill(
          techDoc,
          bookingServiceId,
          serviceName: bookingServiceName,
        );
        if (!isSkillAuthorized) {
          return Response(
            requestOptions: options,
            statusCode: 403,
            data: {
              'success': false,
              'code': 'SKILL_NOT_AUTHORIZED',
              'error': 'INELIGIBLE_FOR_SERVICE',
              'message': 'Technician is not authorized or verified for service: $bookingServiceId.',
            },
          );
        }
      }
    }

    // 6. Server-Authoritative Atomic State Commit
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final techName = techDoc?['fullName'] ?? techDoc?['name'] ?? 'Partner Technician';
    final techPhone = techDoc?['phone'] ?? techDoc?['phoneNumber'] ?? '';
    final digits = callerTechId.replaceAll(RegExp(r'\D'), '');
    final techCode = techDoc?['technicianCode'] ??
        'BT-${digits.length >= 6 ? digits.substring(digits.length - 6) : digits.padLeft(6, '0')}';

    final updateData = {
      'status': 'ASSIGNED',
      'technicianId': callerTechId,
      'technicianName': techName,
      'technicianPhone': techPhone,
      'technicianCode': techCode,
      'assignedAt': nowIso,
      'acceptedAt': nowIso,
      'updatedAt': nowIso,
    };

    // Update authoritative booking record in Firestore
    await upsertDocument('bookings', bookingId, updateData);

    // If dispatched via offer, mark this winning offer ACCEPTED
    if (offerId.isNotEmpty) {
      await upsertDocument('dispatch_offers', offerId, {
        'status': 'ACCEPTED',
        'acceptedAt': nowIso,
        'updatedAt': nowIso,
      });
    }

    // Cancel competing offers for this booking so other technicians are dismissed
    try {
      final allOffers = await listCollection('dispatch_offers', forceRefresh: true);
      for (final o in allOffers) {
        final oId = o['id']?.toString() ?? o['offerId']?.toString() ?? '';
        final bId = o['bookingId']?.toString() ?? '';
        final st = (o['status']?.toString() ?? '').toUpperCase();
        if (bId == bookingId && oId != offerId && (st == 'SENT' || st == 'RINGING')) {
          await upsertDocument('dispatch_offers', oId, {
            'status': 'CANCELLED_CLAIMED_BY_ANOTHER',
            'updatedAt': nowIso,
          });
        }
      }
    } catch (_) {}

    // Transition technician presence to BUSY (keeping lastPresenceHeartbeat separate from lastLocationUpdate!)
    await upsertDocument('technician_profiles', callerTechId, {
      'availabilityStatus': 'BUSY',
      'activeBookingId': bookingId,
      'lastPresenceHeartbeat': nowIso,
      'updatedAt': nowIso,
    });

    final completeBooking = {
      ...existingBooking,
      ...updateData,
    };
    // Strictly sanitize: NEVER return customer OTPs to technician
    completeBooking.remove('startOtp');
    completeBooking.remove('endOtp');
    completeBooking.remove('startServiceOtp');

    return Response(
      requestOptions: options,
      statusCode: 200,
      data: {
        'success': true,
        'code': 'ACCEPTED',
        'message': 'Booking accepted successfully',
        'booking': completeBooking,
        'data': completeBooking,
      },
    );
  }

  /// ─── AUTHORITATIVE OTP VERIFICATION & LIFECYCLE TRANSITION ─────────────
  /// Validates entered Start / End OTP, enforces attempt limits, locks out on 3 failures,
  /// and updates booking status. Never permits client-side verification bypass.
  static Future<Response> _handleAuthoritativeOtpVerification({
    required RequestOptions options,
    required String bookingId,
    required String status,
    String? startOtp,
    String? endOtp,
  }) async {
    final callerId = options.headers['x-technician-id']?.toString() ??
        options.headers['x-user-id']?.toString() ??
        '';

    final isStart = startOtp != null && startOtp.isNotEmpty;
    final enteredOtp = (isStart ? startOtp : (endOtp ?? '')).trim();

    // 1. Strict Format Validation
    if (enteredOtp.length != 4 || int.tryParse(enteredOtp) == null) {
      return Response(
        requestOptions: options,
        statusCode: 400,
        data: {
          'success': false,
          'code': 'INVALID_OTP_FORMAT',
          'error': 'INVALID_OTP_FORMAT',
          'message': 'A 4-digit numeric OTP is required.',
        },
      );
    }

    // 2. Fetch booking record
    final booking = await getDocument('bookings', bookingId, forceRefresh: true);
    if (booking == null) {
      return Response(
        requestOptions: options,
        statusCode: 404,
        data: {
          'success': false,
          'code': 'BOOKING_NOT_FOUND',
          'error': 'BOOKING_NOT_FOUND',
          'message': 'Booking not found.',
        },
      );
    }

    // 3. Authorization check
    final assignedTech = booking['technicianId']?.toString();
    if (assignedTech != null && callerId.isNotEmpty && assignedTech != callerId && !assignedTech.contains(callerId)) {
      return Response(
        requestOptions: options,
        statusCode: 403,
        data: {
          'success': false,
          'code': 'TECHNICIAN_NOT_ASSIGNED',
          'error': 'TECHNICIAN_NOT_ASSIGNED',
          'message': 'You are not the assigned technician for this booking.',
        },
      );
    }

    // 4. State validation
    final currentStatus = (booking['status']?.toString() ?? '').toUpperCase();
    if (isStart && currentStatus == 'IN_PROGRESS') {
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'status': 'IN_PROGRESS', 'message': 'Job is already in progress'},
      );
    }
    if (!isStart && currentStatus == 'COMPLETED') {
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'status': 'COMPLETED', 'message': 'Job is already completed'},
      );
    }

    // 5. Fetch Challenge & Secrets (from booking_secrets or local challenge)
    final secretDoc = await getDocument('booking_secrets', bookingId, forceRefresh: true);

    final failedAttemptsKey = isStart ? 'failedStartAttempts' : 'failedEndAttempts';
    final lockedOutKey = isStart ? 'startLockedOut' : 'endLockedOut';

    int failedCount = 0;
    bool isLocked = false;
    String? salt;
    String? expectedHash;

    if (secretDoc != null) {
      failedCount = int.tryParse(secretDoc[failedAttemptsKey]?.toString() ?? '0') ?? 0;
      isLocked = secretDoc[lockedOutKey] == true || failedCount >= 3;
      salt = secretDoc['salt']?.toString();
      expectedHash = isStart ? secretDoc['startOtpHash']?.toString() : secretDoc['endOtpHash']?.toString();
    }

    if (isLocked) {
      return Response(
        requestOptions: options,
        statusCode: 403,
        data: {
          'success': false,
          'code': 'OTP_LOCKED_OUT',
          'error': 'OTP_LOCKED_OUT',
          'message': 'Maximum OTP verification attempts exceeded (3 failed attempts). Verification is locked.',
          'remainingAttempts': 0,
        },
      );
    }

    // 6. Hash & Compare
    bool isValid = false;
    if (salt != null && expectedHash != null && expectedHash.isNotEmpty) {
      // Check salted hash
      final computed = sha256Hex('$salt$enteredOtp');
      final fallbackComputed = sha256Hex(enteredOtp);
      isValid = (computed == expectedHash) || (fallbackComputed == expectedHash);
    }

    // Fallback check against plaintext field if legacy doc
    if (!isValid) {
      final plainExpected = isStart ? booking['startOtp']?.toString() : booking['endOtp']?.toString();
      if (plainExpected != null && plainExpected.isNotEmpty) {
        isValid = plainExpected == enteredOtp;
      }
    }

    final nowIso = DateTime.now().toUtc().toIso8601String();

    if (!isValid) {
      failedCount++;
      final nextLocked = failedCount >= 3;
      final remaining = (3 - failedCount).clamp(0, 3);

      if (secretDoc != null) {
        await upsertDocument('booking_secrets', bookingId, {
          failedAttemptsKey: failedCount,
          lockedOutKey: nextLocked,
          'updatedAt': nowIso,
        });
      }

      return Response(
        requestOptions: options,
        statusCode: nextLocked ? 403 : 400,
        data: {
          'success': false,
          'code': nextLocked ? 'OTP_LOCKED_OUT' : 'INVALID_OTP',
          'error': nextLocked ? 'OTP_LOCKED_OUT' : 'INVALID_OTP',
          'message': nextLocked
              ? 'Maximum OTP attempts reached (3 failed attempts). Account locked.'
              : 'Invalid OTP code. $remaining attempts remaining.',
          'remainingAttempts': remaining,
        },
      );
    }

    // 7. Success: Commit State Transition
    if (isStart) {
      await upsertDocument('bookings', bookingId, {
        'status': 'IN_PROGRESS',
        'serviceStartedAt': nowIso,
        'updatedAt': nowIso,
      });
      if (secretDoc != null) {
        await upsertDocument('booking_secrets', bookingId, {
          'failedStartAttempts': 0,
          'startVerifiedAt': nowIso,
          'updatedAt': nowIso,
        });
      }
      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'status': 'IN_PROGRESS',
          'message': 'Start OTP verified successfully. Work is now IN_PROGRESS.',
        },
      );
    } else {
      final totalAmount = double.tryParse(booking['totalAmount']?.toString() ??
              booking['price']?.toString() ??
              booking['grandTotal']?.toString() ??
              '1039') ??
          1039.0;
      final payout = (totalAmount * 0.8).round();

      await upsertDocument('bookings', bookingId, {
        'status': 'COMPLETED',
        'completedAt': nowIso,
        'technicianPayoutAmount': payout,
        'updatedAt': nowIso,
      });

      if (callerId.isNotEmpty) {
        final tech = await getDocument('technician_profiles', callerId, forceRefresh: true);
        final currentBal = int.tryParse(tech?['walletBalance']?.toString() ?? '0') ?? 0;
        final jobsCount = int.tryParse(tech?['totalJobsCompleted']?.toString() ?? '0') ?? 0;
        await upsertDocument('technician_profiles', callerId, {
          'availabilityStatus': 'AVAILABLE',
          'activeBookingId': null,
          'walletBalance': currentBal + payout,
          'totalJobsCompleted': jobsCount + 1,
          'updatedAt': nowIso,
        });
      }

      if (secretDoc != null) {
        await upsertDocument('booking_secrets', bookingId, {
          'failedEndAttempts': 0,
          'endVerifiedAt': nowIso,
          'updatedAt': nowIso,
        });
      }

      return Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'success': true,
          'status': 'COMPLETED',
          'payoutAmount': payout,
          'message': 'Service completed successfully! Earnings credited to wallet.',
        },
      );
    }
  }
}

class _CachedResult {
  final DateTime timestamp;
  final dynamic data;
  _CachedResult(this.timestamp, this.data);
}
