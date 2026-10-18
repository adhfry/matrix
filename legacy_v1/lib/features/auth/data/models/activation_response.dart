import 'package:json_annotation/json_annotation.dart';
import 'user_model.dart';

part 'activation_response.g.dart';

@JsonSerializable()
class ActivationRequestResponse {
  final String status;
  final String message;
  final ActivationRequestData? data;

  ActivationRequestResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ActivationRequestResponse.fromJson(Map<String, dynamic> json) =>
      _$ActivationRequestResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ActivationRequestResponseToJson(this);
}

@JsonSerializable()
class ActivationRequestData {
  final String email;
  @JsonKey(name: 'expires_in')
  final int expiresIn;

  ActivationRequestData({
    required this.email,
    required this.expiresIn,
  });

  factory ActivationRequestData.fromJson(Map<String, dynamic> json) =>
      _$ActivationRequestDataFromJson(json);
  Map<String, dynamic> toJson() => _$ActivationRequestDataToJson(this);
}

@JsonSerializable()
class ActivationVerifyResponse {
  final String status;
  final String message;
  final ActivationVerifyData? data;

  ActivationVerifyResponse({
    required this.status,
    required this.message,
    this.data,
  });

  factory ActivationVerifyResponse.fromJson(Map<String, dynamic> json) =>
      _$ActivationVerifyResponseFromJson(json);
  Map<String, dynamic> toJson() => _$ActivationVerifyResponseToJson(this);
}

@JsonSerializable()
class ActivationVerifyData {
  final String token;
  final UserModel user;

  ActivationVerifyData({
    required this.token,
    required this.user,
  });

  factory ActivationVerifyData.fromJson(Map<String, dynamic> json) =>
      _$ActivationVerifyDataFromJson(json);
  Map<String, dynamic> toJson() => _$ActivationVerifyDataToJson(this);
}
