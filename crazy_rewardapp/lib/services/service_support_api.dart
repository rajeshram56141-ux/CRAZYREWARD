import 'package:dio/dio.dart';
import '../utils/constant/constant.dart';

class ServiceSupportApi {
  static final Dio _dio = Dio();

  // Submit Promotion Request
  static Future<Map<String, dynamic>> submitPromotionRequest({
    required String userId,
    required String email,
    required String promotionType,
    required String title,
    required String description,
    String? link,
    String? phoneNumber,
    String? budget,
    String? campaignType,
  }) async {
    try {
      final response = await _dio.post(
        AppConst.submitPromotionRequest,
        data: {
          'userId': userId,
          'email': email,
          'promotionType': promotionType,
          'title': title,
          'description': description,
          'link': link ?? '',
          'phoneNumber': phoneNumber ?? '',
          'budget': budget ?? '',
          'campaignType': campaignType ?? '',
        },
        options: Options(headers: AppConst.apiHeader),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {'success': false, 'message': 'Invalid server response'};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  // Get Promotion Requests
  static Future<List<dynamic>> getPromotionRequests(String userId) async {
    try {
      final response = await _dio.get(
        AppConst.getPromotionRequests,
        queryParameters: {'userId': userId},
        options: Options(headers: AppConst.apiHeader),
      );
      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Submit Support Ticket
  static Future<Map<String, dynamic>> submitSupportRequest({
    required String userId,
    required String email,
    required String subject,
    required String message,
    String? screenshot,
  }) async {
    try {
      final validEmail = email.trim().isNotEmpty ? email.trim() : 'user_$userId@crazyreward.app';
      final response = await _dio.post(
        AppConst.submitSupportRequest,
        data: {
          'userId': userId,
          'email': validEmail,
          'subject': subject,
          'message': message,
          'screenshot': screenshot ?? '',
        },
        options: Options(headers: AppConst.apiHeader),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {'success': false, 'message': 'Invalid server response'};
    } catch (e) {
      if (e is DioException && e.response?.data != null && e.response?.data is Map) {
        final resData = Map<String, dynamic>.from(e.response!.data as Map);
        if (resData.containsKey('message')) {
          return {'success': false, 'message': resData['message'].toString()};
        }
      }
      return {'success': false, 'message': 'Failed to submit ticket. Please try again.'};
    }
  }

  // Get Support Tickets
  static Future<List<dynamic>> getSupportRequests(String userId) async {
    try {
      final response = await _dio.get(
        AppConst.getSupportRequests,
        queryParameters: {'userId': userId},
        options: Options(headers: AppConst.apiHeader),
      );
      if (response.data is Map && response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
