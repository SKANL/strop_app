import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:strop_app/core/constants/app_constants.dart';

class DioClient {
  DioClient(this._tokenProvider) {
    _dio
      ..options.baseUrl = AppConstants.supabaseUrl
      ..options.connectTimeout = const Duration(seconds: 15)
      ..options.receiveTimeout = const Duration(seconds: 15)
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            final token = await _tokenProvider();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
            options.headers['apikey'] = AppConstants.supabaseAnonKey;
            return handler.next(options);
          },
        ),
      );

    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(),
      );
    }
  }

  final Future<String?> Function() _tokenProvider;
  final Dio _dio = Dio();

  Dio get dio => _dio;
}
