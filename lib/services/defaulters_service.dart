import 'dart:async';
import 'dart:convert';
import '../services/api_service.dart';
import '../models/defaulter.dart';

/// Background service that keeps fetching default amount silently.
/// It never blocks the UI — it just updates cached values.
class DefaultersService {
  static final DefaultersService _instance = DefaultersService._internal();
  factory DefaultersService() => _instance;
  DefaultersService._internal();

  final ApiService _api = ApiService();

  double? _cachedAmount;
  DateTime? _lastUpdated;
  Timer? _timer;
  bool _fetching = false;

  double? get cachedAmount => _cachedAmount;
  DateTime? get lastUpdated => _lastUpdated;

  // Listeners notified on new data
  final List<void Function()> _listeners = [];

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);
  void _notify() { for (final l in List.of(_listeners)) l(); }

  /// Start background polling every 2 minutes for the given branch.
  void start(String branch) {
    _timer?.cancel();
    _fetchAmount(branch); // immediate first fetch
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => _fetchAmount(branch));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _fetchAmount(String branch) async {
    if (_fetching) return;
    _fetching = true;
    try {
      final endpoint =
          '/api/PreciseDefault/get-default-amount?branchName=${Uri.encodeComponent(branch)}&targetDate=${_todayDate()}';
      final response = await _api.get(endpoint);
      if (response.statusCode == 200) {
        final value = double.tryParse(response.body.trim());
        if (value != null) {
          _cachedAmount = value;
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

  /// Fetch full default details for a branch and date (called on demand).
  Future<DefaultDetails?> fetchDetails(String branch, String targetDate) async {
    try {
      final endpoint =
          '/api/PreciseDefault/get-default-details?branchName=${Uri.encodeComponent(branch)}&targetDate=${Uri.encodeComponent(targetDate)}';
      final response = await _api.get(endpoint);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return DefaultDetails.fromJson(json);
      }
    } catch (_) {}
    return null;
  }
}
