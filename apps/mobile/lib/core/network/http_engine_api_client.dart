import 'dart:convert';

import 'package:http/http.dart' as http;

import 'engine_api_client.dart';
import 'request_id.dart';

abstract interface class AccessTokenProvider {
  Future<String?> getAccessToken();
}

class HttpEngineApiClient implements EngineApiClient {
  final String baseUrl;
  final AccessTokenProvider tokenProvider;
  final http.Client _httpClient;

  HttpEngineApiClient({
    required this.baseUrl,
    required this.tokenProvider,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Future<ChartResponseDto> calculateChart(CalculateChartRequestDto request) async {
    final jsonMap = await _post('/engine/v1/charts:calculate', request.toJson());
    return ChartResponseDto.fromJson(jsonMap);
  }

  @override
  Future<ReportResponseDto> generateReport(GenerateReportRequestDto request) async {
    final jsonMap = await _post('/engine/v1/reports:generate', request.toJson());
    return ReportResponseDto.fromJson(jsonMap);
  }

  @override
  Future<DailyFortuneResponseDto> generateDailyFortune(
    GenerateDailyFortuneRequestDto request,
  ) async {
    final jsonMap = await _post('/engine/v1/fortunes:daily', request.toJson());
    return DailyFortuneResponseDto.fromJson(jsonMap);
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final token = await tokenProvider.getAccessToken();
    if (token == null || token.isEmpty) {
      throw const EngineApiException(
        code: 'UNAUTHORIZED',
        message: 'missing access token',
      );
    }

    final requestId = generateRequestId();
    final uri = Uri.parse('$baseUrl$path');
    final response = await _httpClient.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
        'X-Request-Id': requestId,
      },
      body: jsonEncode(body),
    );

    final decoded = _decodeBody(response.body);
    final responseRequestId = (decoded['requestId'] as String?) ?? response.headers['x-request-id'] ?? requestId;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    throw EngineApiException(
      code: decoded['code'] as String? ?? 'ENGINE_API_ERROR',
      message: decoded['message'] as String? ?? 'request failed',
      statusCode: response.statusCode,
      requestId: responseRequestId,
    );
  }

  Map<String, dynamic> _decodeBody(String body) {
    if (body.isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    throw const EngineApiException(
      code: 'INVALID_RESPONSE',
      message: 'response body is not a JSON object',
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

class EngineApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;

  const EngineApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  @override
  String toString() {
    final requestIdText = requestId == null ? '' : ', requestId: $requestId';
    if (statusCode == null) {
      return 'EngineApiException(code: $code, message: $message$requestIdText)';
    }
    return 'EngineApiException(code: $code, status: $statusCode, message: $message$requestIdText)';
  }
}
