// Minimal "신살/귀인" helpers derived from the 4 pillars string.
//
// This is intentionally lightweight and UI-facing. If/when the engine becomes authoritative for
// interpretations, move this to the backend and store in chart_json/report content.

class SajuStars {
  static const _stems = <String>['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branches = <String>['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

  static String? stemOf(String pillar) {
    final p = pillar.trim();
    if (p.length < 2) return null;
    final s = p.substring(0, 1);
    return _stems.contains(s) ? s : null;
  }

  static String? branchOf(String pillar) {
    final p = pillar.trim();
    if (p.length < 2) return null;
    final b = p.substring(1, 2);
    return _branches.contains(b) ? b : null;
  }

  // 천을귀인: day stem -> 2 branches
  // Mapping widely used in 명리 tables (간단 버전).
  static const Map<String, List<String>> _cheonEul = {
    '갑': ['축', '미'],
    '을': ['자', '신'],
    '병': ['해', '유'],
    '정': ['해', '유'],
    '무': ['축', '미'],
    '기': ['자', '신'],
    '경': ['축', '미'],
    '신': ['인', '오'],
    '임': ['묘', '사'],
    '계': ['묘', '사'],
  };

  // 문창귀인: day stem -> 1 branch
  static const Map<String, String> _munChang = {
    '갑': '사',
    '을': '오',
    '병': '신',
    '정': '유',
    '무': '신',
    '기': '유',
    '경': '해',
    '신': '자',
    '임': '인',
    '계': '묘',
  };

  static List<String> cheonEulTargets(String dayStem) => _cheonEul[dayStem] ?? const [];
  static String? munChangTarget(String dayStem) => _munChang[dayStem];

  static bool hasAnyBranch(Iterable<String> branches, String target) {
    for (final b in branches) {
      if (b == target) return true;
    }
    return false;
  }
}
