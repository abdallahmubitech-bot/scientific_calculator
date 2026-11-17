import 'dart:convert';

/// A single evaluated calculation stored in the history list.
class CalculationHistory {
  const CalculationHistory({
    required this.tokens,
    required this.result,
    required this.timestamp,
  });

  /// Expression tokens exactly as they were entered (e.g. `sin(`, `3`, `0`, `)`).
  final List<String> tokens;

  /// Formatted result, re-parsable by the math engine (e.g. `0.5`, `1.2E21`).
  final String result;

  final DateTime timestamp;

  String get expression => tokens.join();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Human readable timestamp such as `13 Nov 2026, 09:41`.
  String get formattedTimestamp {
    final t = timestamp.toLocal();
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '${t.day} ${_months[t.month - 1]} ${t.year}, $hh:$mm';
  }

  Map<String, dynamic> toJson() => {
        'tokens': tokens,
        'result': result,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory CalculationHistory.fromJson(Map<String, dynamic> json) {
    return CalculationHistory(
      tokens: (json['tokens'] as List<dynamic>).map((e) => e as String).toList(),
      result: json['result'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  static String encodeList(List<CalculationHistory> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  /// Decodes a stored list. Corrupt or missing data yields an empty list.
  static List<CalculationHistory> decodeList(String? source) {
    if (source == null || source.isEmpty) return [];
    try {
      final decoded = jsonDecode(source) as List<dynamic>;
      return decoded
          .map((e) => CalculationHistory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
