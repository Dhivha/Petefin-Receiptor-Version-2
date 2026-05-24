import 'dart:convert';
import 'dart:typed_data';

class ApiResponse {
  final int statusCode;
  final Uint8List bodyBytes;
  final Map<String, String> headers;

  const ApiResponse({
    required this.statusCode,
    required this.bodyBytes,
    this.headers = const {},
  });

  String get body => utf8.decode(bodyBytes, allowMalformed: true);

  int get contentLength => bodyBytes.length;

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}
