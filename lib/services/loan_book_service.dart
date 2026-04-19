import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';

/// Background service that polls /api/LoanBook/value every 2 minutes.
class LoanBookService {
  static final LoanBookService _instance = LoanBookService._internal();
  factory LoanBookService() => _instance;
  LoanBookService._internal();

  final ApiService _api = ApiService();

  double? _cachedValue;
  DateTime? _lastUpdated;
  Timer? _timer;
  bool _fetching = false;

  double? get cachedValue => _cachedValue;
  DateTime? get lastUpdated => _lastUpdated;

  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() {
    for (final l in List.of(_listeners)) l();
  }

  void start(String branch) {
    _timer?.cancel();
    _fetch(branch);
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _fetch(branch));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _fetch(String branch) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final endpoint = '/api/LoanBook/value/${Uri.encodeComponent(branch)}';
      final response = await _api.get(endpoint);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final value = (json['LoanBookValue'] as num?)?.toDouble();
        if (value != null) {
          _cachedValue = value;
          _lastUpdated = DateTime.now();
          _notify();
        }
      }
    } catch (_) {
      // silent — never crash
    } finally {
      _fetching = false;
    }
  }
}
