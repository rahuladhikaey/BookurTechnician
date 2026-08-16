import '../../../core/network/api_result.dart';

abstract class AuthRepository {
  Future<ApiResult<bool>> requestOtp(String phone, {required String email});
  Future<ApiResult<String>> verifyOtp(String phone, String code, {String? email});
}
