import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class UserModel {
  final int id;
  final String name;
  final String username;
  final String? email;
  final String? jabatan;
  @JsonKey(name: 'jabatanBlud')
  final String? jabatanBlud;
  final String? nip;
  final String? foto;
  @JsonKey(name: 'attendance_mode')
  final String? attendanceMode;
  @JsonKey(name: 'job_category')
  final String? jobCategory;
  @JsonKey(name: 'status_atlm')
  final String? statusAtlm;
  @JsonKey(name: 'is_location_free')
  final bool? isLocationFree;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    this.email,
    this.jabatan,
    this.jabatanBlud,
    this.nip,
    this.foto,
    this.attendanceMode,
    this.jobCategory,
    this.statusAtlm,
    this.isLocationFree,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  UserModel copyWith({
    int? id,
    String? name,
    String? username,
    String? email,
    String? jabatan,
    String? jabatanBlud,
    String? nip,
    String? foto,
    String? attendanceMode,
    String? jobCategory,
    String? statusAtlm,
    bool? isLocationFree,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      jabatan: jabatan ?? this.jabatan,
      jabatanBlud: jabatanBlud ?? this.jabatanBlud,
      nip: nip ?? this.nip,
      foto: foto ?? this.foto,
      attendanceMode: attendanceMode ?? this.attendanceMode,
      jobCategory: jobCategory ?? this.jobCategory,
      statusAtlm: statusAtlm ?? this.statusAtlm,
      isLocationFree: isLocationFree ?? this.isLocationFree,
    );
  }
}
