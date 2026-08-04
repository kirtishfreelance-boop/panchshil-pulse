import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

/// Thin wrapper over Dio that attaches the session token, normalises errors
/// into [ApiException], and notifies the app when a session goes stale.
class ApiClient {
  ApiClient(this._session, {Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              // A saved override wins, so a single build can be repointed at a
              // different server from inside the app.
              baseUrl: _session.apiBaseUrl ?? AppConfig.apiBaseUrl,
              connectTimeout: AppConfig.connectTimeout,
              receiveTimeout: AppConfig.receiveTimeout,
              contentType: Headers.jsonContentType,
              // Let non-2xx reach the error interceptor with its body intact.
              validateStatus: (code) => code != null && code < 400,
            )) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _session.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (e, handler) {
          if (e.response?.statusCode == 401) {
            onUnauthorized?.call();
          }
          handler.next(e);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint('[api] $o'),
      ));
    }
  }

  final Dio _dio;
  final SessionStore _session;

  /// Set by AuthProvider so an expired token bounces the user to login.
  VoidCallback? onUnauthorized;

  String get baseUrl => _dio.options.baseUrl;

  /// Repoints the client at another server and remembers the choice.
  /// Passing null restores the URL the app was built with.
  Future<void> setBaseUrl(String? url) async {
    await _session.setApiBaseUrl(url);
    _dio.options.baseUrl = _session.apiBaseUrl ?? AppConfig.apiBaseUrl;
  }

  /// Cheap reachability probe used by the splash and the server picker.
  Future<bool> ping() async {
    try {
      final json = await get('/health');
      return json['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.post(path, data: body, queryParameters: query));

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
  }) =>
      _send(() => _dio.patch(path, data: body));

  Future<Map<String, dynamic>> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
  }) =>
      _send(() => _dio.delete(path, data: body, queryParameters: query));

  Future<Map<String, dynamic>> _send(Future<Response> Function() call) async {
    try {
      final response = await call();
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is List) return {'data': data};
      return const {};
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

/// Pulls a typed list out of an envelope like `{"events": [...]}`.
List<T> listFrom<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final raw = json[key];
  if (raw is! List) return const [];
  return raw
      .whereType<Map<String, dynamic>>()
      .map(parse)
      .toList(growable: false);
}
