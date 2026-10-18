// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserModel _$UserModelFromJson(Map<String, dynamic> json) => UserModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      username: json['username'] as String,
      email: json['email'] as String?,
      jabatan: json['jabatan'] as String?,
      jabatanBlud: json['jabatanBlud'] as String?,
      nip: json['nip'] as String?,
      foto: json['foto'] as String?,
      attendanceMode: json['attendance_mode'] as String?,
      jobCategory: json['job_category'] as String?,
      statusAtlm: json['status_atlm'] as String?,
      isLocationFree: json['is_location_free'] as bool?,
    );

Map<String, dynamic> _$UserModelToJson(UserModel instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'username': instance.username,
      'email': instance.email,
      'jabatan': instance.jabatan,
      'jabatanBlud': instance.jabatanBlud,
      'nip': instance.nip,
      'foto': instance.foto,
      'attendance_mode': instance.attendanceMode,
      'job_category': instance.jobCategory,
      'status_atlm': instance.statusAtlm,
      'is_location_free': instance.isLocationFree,
    };
