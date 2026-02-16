import 'package:flutter/material.dart';

import 'saju_stars.dart';

class SajuManseoryeok {
  static bool isYangStem(String stem) => const {'갑', '병', '무', '경', '임'}.contains(stem);

  static String? tenGod({required String dayStem, required String targetStem}) {
    final dayEl = SajuStars.stemElementKey(dayStem);
    final targetEl = SajuStars.stemElementKey(targetStem);
    if (dayEl == null || targetEl == null) return null;

    final samePolarity = isYangStem(dayStem) == isYangStem(targetStem);

    // Element relations from the Day Master perspective.
    // wood -> fire -> earth -> metal -> water -> wood
    bool produces(String a, String b) {
      return (a == 'wood' && b == 'fire') ||
          (a == 'fire' && b == 'earth') ||
          (a == 'earth' && b == 'metal') ||
          (a == 'metal' && b == 'water') ||
          (a == 'water' && b == 'wood');
    }

    bool controls(String a, String b) {
      return (a == 'wood' && b == 'earth') ||
          (a == 'earth' && b == 'water') ||
          (a == 'water' && b == 'fire') ||
          (a == 'fire' && b == 'metal') ||
          (a == 'metal' && b == 'wood');
    }

    if (dayEl == targetEl) {
      return samePolarity ? '비견' : '겁재';
    }
    if (produces(dayEl, targetEl)) {
      return samePolarity ? '식신' : '상관';
    }
    if (controls(dayEl, targetEl)) {
      return samePolarity ? '편재' : '정재';
    }
    if (controls(targetEl, dayEl)) {
      return samePolarity ? '편관' : '정관';
    }
    if (produces(targetEl, dayEl)) {
      return samePolarity ? '편인' : '정인';
    }
    return null;
  }

  static const Map<String, List<String>> _hiddenStemsByBranch = {
    '자': ['계'],
    '축': ['기', '계', '신'],
    '인': ['갑', '병', '무'],
    '묘': ['을'],
    '진': ['무', '을', '계'],
    '사': ['병', '무', '경'],
    '오': ['정', '기'],
    '미': ['기', '정', '을'],
    '신': ['경', '임', '무'],
    '유': ['신'],
    '술': ['무', '신', '정'],
    '해': ['임', '갑'],
  };

  static List<String> hiddenStems(String branch) => _hiddenStemsByBranch[branch] ?? const [];

  static String? stemCombine(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    final set = {x, y};
    if (set.containsAll({'갑', '기'})) return '갑기합';
    if (set.containsAll({'을', '경'})) return '을경합';
    if (set.containsAll({'병', '신'})) return '병신합';
    if (set.containsAll({'정', '임'})) return '정임합';
    if (set.containsAll({'무', '계'})) return '무계합';
    return null;
  }

  static String? branchClash(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    final set = {x, y};
    if (set.containsAll({'자', '오'})) return '자오충';
    if (set.containsAll({'축', '미'})) return '축미충';
    if (set.containsAll({'인', '신'})) return '인신충';
    if (set.containsAll({'묘', '유'})) return '묘유충';
    if (set.containsAll({'진', '술'})) return '진술충';
    if (set.containsAll({'사', '해'})) return '사해충';
    return null;
  }

  static String? branchSixCombine(String a, String b) {
    final x = a.trim();
    final y = b.trim();
    final set = {x, y};
    if (set.containsAll({'자', '축'})) return '자축합';
    if (set.containsAll({'인', '해'})) return '인해합';
    if (set.containsAll({'묘', '술'})) return '묘술합';
    if (set.containsAll({'진', '유'})) return '진유합';
    if (set.containsAll({'사', '신'})) return '사신합';
    if (set.containsAll({'오', '미'})) return '오미합';
    return null;
  }

  static Color elementColor(String key) {
    switch (key) {
      case 'wood':
        return const Color(0xFF1F8A5B);
      case 'fire':
        return const Color(0xFFE14C3A);
      case 'earth':
        return const Color(0xFFF0C24A);
      case 'metal':
        return const Color(0xFF9CA3AF);
      case 'water':
        return const Color(0xFF0F172A);
    }
    return const Color(0xFFF3F4F6);
  }

  static String elementLabel(String key) {
    switch (key) {
      case 'wood':
        return '목';
      case 'fire':
        return '화';
      case 'earth':
        return '토';
      case 'metal':
        return '금';
      case 'water':
        return '수';
    }
    return '';
  }
}

