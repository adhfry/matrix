// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_location_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AttendanceLocationModel _$AttendanceLocationModelFromJson(
        Map<String, dynamic> json) =>
    AttendanceLocationModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String,
      latitude: AttendanceLocationModel._parseDouble(json['latitude']),
      longitude: AttendanceLocationModel._parseDouble(json['longitude']),
      radiusMeters: (json['radius_meters'] as num).toInt(),
      isLocationFree: json['is_location_free'] as bool? ?? false,
      isInRange: json['is_in_range'] as bool?,
      distance: (json['distance'] as num?)?.toDouble(),
    );

Map<String, dynamic> _$AttendanceLocationModelToJson(
        AttendanceLocationModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'radius_meters': instance.radiusMeters,
      'is_location_free': instance.isLocationFree,
      'is_in_range': instance.isInRange,
      'distance': instance.distance,
    };
