import 'package:json_annotation/json_annotation.dart';

part 'attendance_location_model.g.dart';

@JsonSerializable()
class AttendanceLocationModel {
  final int id;
  final String name;
  @JsonKey(fromJson: _parseDouble)
  final double latitude;
  @JsonKey(fromJson: _parseDouble)
  final double longitude;
  @JsonKey(name: 'radius_meters')
  final int radiusMeters;
  @JsonKey(name: 'is_location_free')
  final bool isLocationFree;
  @JsonKey(name: 'is_in_range')
  final bool? isInRange;
  final double? distance;

  AttendanceLocationModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.isLocationFree = false,
    this.isInRange,
    this.distance,
  });

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.parse(value);
    return 0.0;
  }

  factory AttendanceLocationModel.fromJson(Map<String, dynamic> json) =>
      _$AttendanceLocationModelFromJson(json);
  
  Map<String, dynamic> toJson() => _$AttendanceLocationModelToJson(this);

  AttendanceLocationModel copyWith({
    int? id,
    String? name,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    bool? isLocationFree,
    bool? isInRange,
    double? distance,
  }) {
    return AttendanceLocationModel(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      isLocationFree: isLocationFree ?? this.isLocationFree,
      isInRange: isInRange ?? this.isInRange,
      distance: distance ?? this.distance,
    );
  }
}
