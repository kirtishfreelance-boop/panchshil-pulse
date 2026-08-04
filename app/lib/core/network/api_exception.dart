import 'package:dio/dio.dart';

/// A failure the UI can show verbatim.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final Map<String, dynamic>? data;

  bool get isUnauthorized => statusCode == 401;
  bool get isPaymentRequired => statusCode == 402;
  bool get isConflict => statusCode == 409;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final body = response?.data;

    if (body is Map<String, dynamic> && body['message'] is String) {
      return ApiException(
        body['message'] as String,
        statusCode: response?.statusCode,
        data: body,
      );
    }

    final message = switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout =>
        'The connection timed out. Check your network and try again.',
      DioExceptionType.connectionError =>
        'Cannot reach Pulse right now. Check your internet connection.',
      DioExceptionType.badCertificate => 'The server certificate could not be verified.',
      DioExceptionType.cancel => 'Request cancelled.',
      // 0 stands in for "no response at all", which falls through to the default.
      _ => switch (response?.statusCode ?? 0) {
          401 => 'Your session has expired. Please sign in again.',
          403 => 'You do not have access to this.',
          404 => 'We could not find what you were looking for.',
          >= 500 => 'Pulse is having trouble. Please try again shortly.',
          _ => 'Something went wrong. Please try again.',
        },
    };

    return ApiException(message, statusCode: response?.statusCode);
  }

  @override
  String toString() => message;
}
