import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/attendance_location_model.dart';
import '../models/attendance_config_model.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository();
});

class AttendanceRepository {
  final DioClient _dioClient = DioClient();

  // Get attendance configuration
  Future<AttendanceConfigModel> getAttendanceConfig() async {
    try {
      final response = await _dioClient.get(AppConstants.attendanceConfigEndpoint);
      
      if (response.statusCode == 200 && response.data != null) {
        return AttendanceConfigModel.fromJson(
          response.data['data'] as Map<String, dynamic>
        );
      } else {
        throw Exception('Failed to load attendance config');
      }
    } catch (e) {
      throw Exception('Error fetching attendance config: $e');
    }
  }

  // Get allowed locations for user
  Future<List<AttendanceLocationModel>> getAllowedLocations() async {
    try {
      final response = await _dioClient.get(
        '/api/app/v1/matrix/mobile/attendance/locations',
      );

      final List<dynamic> data = response.data['data'];
      return data.map((json) => AttendanceLocationModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to get locations: ${e.toString()}');
    }
  }

  // Check-in attendance
  Future<Map<String, dynamic>> checkIn({
    required double latitude,
    required double longitude,
    required int locationId,
    required File photo,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'location_id': locationId.toString(),
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'check_in_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dioClient.postMultipart(
        AppConstants.attendanceCheckInEndpoint,
        formData: formData,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to check-in: ${e.toString()}');
    }
  }

  // Check-out attendance
  Future<Map<String, dynamic>> checkOut({
    required double latitude,
    required double longitude,
    required int locationId,
    required File photo,
  }) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'location_id': locationId.toString(),
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'check_out_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _dioClient.postMultipart(
        AppConstants.attendanceCheckOutEndpoint,
        formData: formData,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to check-out: ${e.toString()}');
    }
  }

  // Get today's attendance
  Future<Map<String, dynamic>> getTodayAttendance() async {
    try {
      final response = await _dioClient.get(
        AppConstants.attendanceTodayEndpoint,
      );

      return response.data;
    } catch (e) {
      throw Exception('Failed to get today attendance: ${e.toString()}');
    }
  }
}
