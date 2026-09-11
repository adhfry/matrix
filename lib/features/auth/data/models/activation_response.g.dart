// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activation_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivationRequestResponse _$ActivationRequestResponseFromJson(
        Map<String, dynamic> json) =>
    ActivationRequestResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : ActivationRequestData.fromJson(
              json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ActivationRequestResponseToJson(
        ActivationRequestResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

ActivationRequestData _$ActivationRequestDataFromJson(
        Map<String, dynamic> json) =>
    ActivationRequestData(
      email: json['email'] as String,
      expiresIn: (json['expires_in'] as num).toInt(),
    );

Map<String, dynamic> _$ActivationRequestDataToJson(
        ActivationRequestData instance) =>
    <String, dynamic>{
      'email': instance.email,
      'expires_in': instance.expiresIn,
    };

ActivationVerifyResponse _$ActivationVerifyResponseFromJson(
        Map<String, dynamic> json) =>
    ActivationVerifyResponse(
      status: json['status'] as String,
      message: json['message'] as String,
      data: json['data'] == null
          ? null
          : ActivationVerifyData.fromJson(json['data'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ActivationVerifyResponseToJson(
        ActivationVerifyResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'message': instance.message,
      'data': instance.data,
    };

ActivationVerifyData _$ActivationVerifyDataFromJson(
        Map<String, dynamic> json) =>
    ActivationVerifyData(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$ActivationVerifyDataToJson(
        ActivationVerifyData instance) =>
    <String, dynamic>{
      'token': instance.token,
      'user': instance.user,
    };
