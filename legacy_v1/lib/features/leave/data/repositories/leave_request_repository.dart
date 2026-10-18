import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/api/dio_client.dart';
import '../../../../core/constants/app_constants.dart';
import '../models/leave_request_model.dart';

class LeaveRequestRepository {
  final DioClient _dioClient = DioClient();

  Future<LeaveRequestModel> getLeaveRequests({
    int? month,
    int? year,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (month != null) queryParams['month'] = month;
      if (year != null) queryParams['year'] = year;

      final response = await _dioClient.get(
        '${AppConstants.apiPrefix}/leave/requests',
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return LeaveRequestModel.fromJson(response.data['data']);
      } else {
        throw Exception(response.data['message'] ?? 'Gagal memuat data izin/cuti');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> submitLeaveRequest({
    required String leaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
    File? attachment,
  }) async {
    try {
      // Prepare form data
      final formData = FormData.fromMap({
        'leave_type': leaveType,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'reason': reason,
      });

      // Add file if exists
      if (attachment != null) {
        final fileName = attachment.path.split('/').last;
        formData.files.add(MapEntry(
          'attachment',
          await MultipartFile.fromFile(
            attachment.path,
            filename: fileName,
          ),
        ));
      }

      final response = await _dioClient.post(
        '${AppConstants.apiPrefix}/leave/request',
        data: formData,
      );
      
      if (response.statusCode != 200) {
        throw Exception(response.data['message'] ?? 'Gagal mengajukan izin/cuti');
      }
    } catch (e) {
      throw Exception(e.toString());
    }
  }
}
