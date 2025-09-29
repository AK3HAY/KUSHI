import 'dart:math';
import 'package:bizil/providers/restaurant_provider.dart';

class EntityExtractor {
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), ' ').trim();

  static List<String> tokens(String s) =>
      normalize(s).split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

  static int levenshtein(String a, String b) {
    a = a.toLowerCase();
    b = b.toLowerCase();
    final n = a.length;
    final m = b.length;
    if (n == 0) return m;
    if (m == 0) return n;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) d[i][0] = i;
    for (var j = 0; j <= m; j++) d[0][j] = j;
    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        d[i][j] = min(d[i - 1][j] + 1, min(d[i][j - 1] + 1, d[i - 1][j - 1] + cost));
      }
    }
    return d[n][m];
  }

  static double similarity(String a, String b) {
    final maxLen = max(a.length, b.length);
    if (maxLen == 0) return 1.0;
    final dist = levenshtein(a, b).toDouble();
    return 1.0 - (dist / maxLen);
  }

  static Restaurant? extractRestaurant(String query, List<Restaurant> restaurants,
      {double fuzzyThreshold = 0.72}) {
    final q = normalize(query);

    for (final r in restaurants) {
      final rn = normalize(r.name);
      if (rn.isNotEmpty && q.contains(rn)) return r;
    }

    Restaurant? best;
    double bestSim = 0.0;
    for (final r in restaurants) {
      final rn = normalize(r.name);
      final sim = similarity(q, rn);
      if (sim > bestSim) {
        bestSim = sim;
        best = r;
      }
    }
    if (best != null && bestSim >= fuzzyThreshold) return best;

    return null;
  }

  static Map<String, dynamic>? extractMenuItem(
      String query, List<Restaurant> restaurants,
      {double tokenOverlapThreshold = 0.6, double fuzzyThreshold = 0.68}) {
    final q = normalize(query);
    final qTokens = tokens(q);

    double scoreItem(String q, List<String> qTokens, Restaurant r, dynamic item) {
      final itemName = normalize(item.itemName ?? item.name ?? '');
      if (itemName.isEmpty) return 0.0;
      if (q.contains(itemName)) return 1.0;

      final itemTokens = tokens(itemName);
      if (itemTokens.isNotEmpty) {
        final matches = itemTokens.where((t) => qTokens.contains(t)).length;
        final overlap = matches / itemTokens.length;
        if (overlap >= tokenOverlapThreshold) return 0.95;
      }
      return similarity(q, itemName);
    }

    final explicitRestaurant = extractRestaurant(query, restaurants, fuzzyThreshold: 0.8);
    final searchList = explicitRestaurant != null ? [explicitRestaurant] : restaurants;

    Map<String, dynamic>? best;
    double bestScore = 0.0;

    for (final r in searchList) {
      for (final item in r.menu) {
        final sc = scoreItem(q, qTokens, r, item);
        if (sc > bestScore) {
          bestScore = sc;
          best = {'restaurant': r, 'item': item, 'score': sc};
        }
        if (sc >= 1.0) return best;
      }
    }

    if (explicitRestaurant != null && bestScore < tokenOverlapThreshold) {
      for (final r in restaurants) {
        for (final item in r.menu) {
          final sc = scoreItem(q, qTokens, r, item);
          if (sc > bestScore) {
            bestScore = sc;
            best = {'restaurant': r, 'item': item, 'score': sc};
          }
          if (sc >= 1.0) return best;
        }
      }
    }

    if (best != null && bestScore >= fuzzyThreshold) {
      return {'restaurant': best['restaurant'], 'item': best['item']};
    }

    return null;
  }
}