import '../../models/juice_product.dart';

class FuzzyMatchResult {
  final JuiceProduct product;
  final double score; // 0.0 to 1.0
  final String matchedName;
  final bool isExactGrabMatch;

  const FuzzyMatchResult({
    required this.product,
    required this.score,
    required this.matchedName,
    this.isExactGrabMatch = false,
  });

  @override
  String toString() =>
      'FuzzyMatchResult(${product.name}, score: ${(score * 100).toStringAsFixed(1)}%, exact: $isExactGrabMatch)';
}

class ProductFuzzyMatcher {
  static const double defaultThreshold = 0.55;

  /// Direct Grab Catalog lookup dictionary derived from the official GrabFood Merchant export:
  /// /home/chan/Documents/grab/6-C6WWJB3KVACJCT_20261024_f3b1c8a2eeea4d49b4c658d58ca71854.csv
  /// Maps normalized Grab item names -> target Odoo catalog search keys.
  static const Map<String, String> grabDirectMap = {
    // Fresh Juices
    'apel': 'apel',
    'alpukat': 'alpukat',
    'buah naga': 'buah naga',
    'nanas': 'nanas',
    'mangga': 'mangga',
    'melon': 'melon',
    'pepaya': 'pepaya',
    'pisang': 'pisang',
    'pir': 'pir',
    'sirsak': 'sirsak',
    'semangka': 'semangka',
    'strawberry': 'strawberry',
    'timun': 'timun',
    'tomat': 'tomat',
    'wortel': 'wortel',
    'lemon': 'lemon',
    'kale': 'kale',
    'bit': 'bit',
    'kelapa': 'kelapa',
    'mix 2 buah': 'mix 2',
    'mix 3 buah': 'mix 3',
    'avosaurus': 'avosaurus',
    'avocoffee': 'avocoffee',

    // Smoothies & Bowls
    'avomood': 'avomood',
    'pinky crunch': 'pinky crunch',
    'tropical bliss': 'tropical bliss',
    'dragomood': 'dragomood',

    // Cold Pressed Series
    'glowing a cold pressed juice': 'cp glowing a',
    'reduce cholestrol cold pressed juice': 'cp reduce cholestrol',
    'gout free cold pressed juice': 'cp gout free',
    'd-toxing cold pressed juice': 'cp d-toxing',
    'blood up cold pressed juice': 'cp blood up',
    'tensi calmer cold pressed juice': 'cp tensi calmer',
    'beat cancer cold pressed juice': 'cp beat cancer',

    // Detox Series (Standard)
    'no acne': 'no acne',
    'd-toxing': 'd-toxing',
    'glowing a': 'glowing a',
    'gout free': 'gout free',
    'blood up': 'blood up',
    'tensi calmer': 'tensi calmer',
    'beat cancer': 'beat cancer',
    'reduce cholesterol': 'reduce cholesterol',

    // Protein Series
    'choco banana': 'choco banana',
    'choco avocado': 'choco avocado',
    'shake pro': 'shake pro',

    // Bakery & Noura Bread
    'roti tawar': 'roti tawar',
    'tuna mayo': 'tuna mayo',
    'garlic cheese': 'garlic cheese',
    'cheesy bite': 'cheesy bite',
    'kacang merah': 'kacang merah',
    'ube soft bun': 'ube soft bun',
    'korean sausage': 'korean sausage',
    'beef floss': 'beef floss',
    'smoked beef': 'smoked beef',
    'roti keju manis': 'keju',
    'keju': 'keju',
    'pisang keju': 'pisang keju',
    'pisang coklat': 'pisang coklat',
    'nutella': 'nutella',
    'salted caramel': 'salted caramel',
    'classic coklat': 'classic coklat',
    'cinnamon apple': 'cinnamon apple',
    'sausage roll': 'sausage roll',
    'vanilla bun': 'vanilla bun',

    // Chilled Cakes & Rolls
    'japanese roll cake chocolate': 'japanese roll cake (chocolate)',
    'japanese roll cake strawberry': 'japanese roll cake (strawberry)',

    // Kopitiam / Toast
    'kaya toast': 'kaya toast',
    'choco toast': 'choco toast',
    'strawberry toast': 'strawberry toast',
    'peanut toast': 'peanut toast',
    'choco butter toast': 'choco butter toast',
    'kaya butter toast': 'kaya butter toast',
    'strawberry butter toast': 'strawberry butter toast',
    'peanut butter toast': 'peanut butter toast',

    // Sides & Japanese Food
    'french fries': 'french fries',
    'mix french fries + sosis': 'mix french fries + sosis',
  };

  // Common F&B synonyms between English & Indonesian menus
  static const Map<String, String> _synonyms = {
    'coklat': 'cokelat',
    'choco': 'cokelat',
    'chocolate': 'cokelat',
    'keju': 'cheese',
    'kacang': 'peanut',
    'stroberi': 'strawberry',
    'strawberi': 'strawberry',
    'naga': 'dragon',
    'spesial': 'special',
    'ori': 'original',
  };

  /// Find the best matching JuiceProduct for a given raw name from a delivery platform
  static FuzzyMatchResult? findBestMatch(
    String rawName,
    List<JuiceProduct> catalog, {
    double minThreshold = defaultThreshold,
  }) {
    if (catalog.isEmpty || rawName.trim().isEmpty) return null;

    final cleanRaw = _normalize(rawName);

    // 1. FAST PATH: Check Grab Direct Catalog Map
    final directTarget = grabDirectMap[cleanRaw];
    if (directTarget != null) {
      final targetNorm = _normalize(directTarget);
      for (final p in catalog) {
        final pNorm = _normalize(p.name);
        if (pNorm == targetNorm || pNorm == cleanRaw) {
          return FuzzyMatchResult(
            product: p,
            score: 1.0,
            matchedName: p.name,
            isExactGrabMatch: true,
          );
        }
      }
      // If direct target didn't exact match, try matching targetNorm as substring
      for (final p in catalog) {
        final pNorm = _normalize(p.name);
        if (pNorm.contains(targetNorm) || targetNorm.contains(pNorm)) {
          return FuzzyMatchResult(
            product: p,
            score: 0.98,
            matchedName: p.name,
            isExactGrabMatch: true,
          );
        }
      }
    }

    // 2. Exact match against catalog directly
    for (final p in catalog) {
      if (_normalize(p.name) == cleanRaw) {
        return FuzzyMatchResult(
          product: p,
          score: 1.0,
          matchedName: p.name,
        );
      }
    }

    // 3. Fallback to Fuzzy Sørensen-Dice & Token Jaccard Matcher
    FuzzyMatchResult? bestResult;
    double bestScore = 0.0;

    for (final product in catalog) {
      final cleanTarget = _normalize(product.name);

      final score = _calculateSimilarity(cleanRaw, cleanTarget);
      if (score > bestScore) {
        bestScore = score;
        bestResult = FuzzyMatchResult(
          product: product,
          score: score,
          matchedName: product.name,
        );
      }
    }

    if (bestScore >= minThreshold) {
      return bestResult;
    }
    return null;
  }

  /// Calculates composite similarity between 0.0 and 1.0
  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;

    // Substring bonus: If one is fully contained within another
    if (s1.contains(s2) || s2.contains(s1)) {
      final minLen = s1.length < s2.length ? s1.length : s2.length;
      final maxLen = s1.length > s2.length ? s1.length : s2.length;
      final containmentScore = 0.80 + (0.20 * (minLen / maxLen));
      return containmentScore;
    }

    // Token overlap (Word Jaccard)
    final tokens1 = s1.split(' ').where((w) => w.isNotEmpty).toList();
    final tokens2 = s2.split(' ').where((w) => w.isNotEmpty).toList();

    double tokenScore = 0.0;
    if (tokens1.isNotEmpty && tokens2.isNotEmpty) {
      int matchedTokens = 0;
      for (final t1 in tokens1) {
        if (tokens2.contains(t1)) {
          matchedTokens++;
        } else {
          // Check if any token has high bigram similarity
          for (final t2 in tokens2) {
            if (_bigramSimilarity(t1, t2) >= 0.70) {
              matchedTokens++;
              break;
            }
          }
        }
      }
      final totalUnique = (tokens1.toSet().union(tokens2.toSet())).length;
      tokenScore = totalUnique > 0 ? (matchedTokens / totalUnique) : 0.0;
    }

    // Character Bigram Sørensen-Dice coefficient
    final bigramScore = _bigramSimilarity(s1, s2);

    // Weighted composite score (50% bigram, 50% token)
    return (bigramScore * 0.5) + (tokenScore * 0.5);
  }

  static double _bigramSimilarity(String s1, String s2) {
    final clean1 = s1.replaceAll(' ', '');
    final clean2 = s2.replaceAll(' ', '');
    if (clean1 == clean2) return 1.0;
    if (clean1.length < 2 || clean2.length < 2) {
      return clean1 == clean2 ? 1.0 : 0.0;
    }

    final bigrams1 = _getBigrams(clean1);
    final bigrams2 = _getBigrams(clean2);

    int matches = 0;
    final copy2 = List<String>.from(bigrams2);
    for (final bg in bigrams1) {
      final idx = copy2.indexOf(bg);
      if (idx != -1) {
        matches++;
        copy2.removeAt(idx);
      }
    }
    return (2.0 * matches) / (bigrams1.length + bigrams2.length);
  }

  static List<String> _getBigrams(String str) {
    if (str.length < 2) return [str];
    final list = <String>[];
    for (int i = 0; i < str.length - 1; i++) {
      list.add(str.substring(i, i + 2));
    }
    return list;
  }

  static String _normalize(String str) {
    final raw = str
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Apply synonym mapping
    final words = raw.split(' ');
    final mapped = words.map((w) => _synonyms[w] ?? w).join(' ');
    return mapped;
  }
}
