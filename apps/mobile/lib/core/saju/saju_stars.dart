// Minimal "신살/귀인" helpers derived from the 4 pillars string.
//
// This is intentionally lightweight and UI-facing. If/when the engine becomes authoritative for
// interpretations, move this to the backend and store in chart_json/report content.

class SajuStars {
  static const _stems = <String>['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branches = <String>['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];
  static const _stemHanja = <String, String>{
    '갑': '甲',
    '을': '乙',
    '병': '丙',
    '정': '丁',
    '무': '戊',
    '기': '己',
    '경': '庚',
    '신': '辛',
    '임': '壬',
    '계': '癸',
  };
  static const _branchHanja = <String, String>{
    '자': '子',
    '축': '丑',
    '인': '寅',
    '묘': '卯',
    '진': '辰',
    '사': '巳',
    '오': '午',
    '미': '未',
    '신': '申',
    '유': '酉',
    '술': '戌',
    '해': '亥',
  };

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

  static String? stemHanja(String stem) => _stemHanja[stem];
  static String? branchHanja(String branch) => _branchHanja[branch];

  static String? pillarHanja(String pillar) {
    final s = stemOf(pillar);
    final b = branchOf(pillar);
    if (s == null || b == null) return null;
    final hs = stemHanja(s);
    final hb = branchHanja(b);
    if (hs == null || hb == null) return null;
    return '$hs$hb';
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

  // 양인살: day stem -> 1 branch (간단 버전).
  // Source: widely-used tables in Korean 명리 references.
  static const Map<String, String> _yangIn = {
    '갑': '묘',
    '을': '인',
    '병': '오',
    '정': '사',
    '무': '오',
    '기': '사',
    '경': '유',
    '신': '신',
    '임': '자',
    '계': '해',
  };

  // 괴강살: day pillar is one of these (narrow/common variant).
  static const Set<String> _gueGangDayPillars = {'경진', '경술', '임진', '임술'};

  // 십악대패: day pillar is one of these 10.
  static const Set<String> _sipAkDaePaeDayPillars = {
    '갑진',
    '을사',
    '병신',
    '정해',
    '무술',
    '기축',
    '경진',
    '신사',
    '임신',
    '계해',
  };

  static String? yangInTarget(String dayStem) => _yangIn[dayStem];
  static bool isGueGangDayPillar(String dayPillar) => _gueGangDayPillars.contains(dayPillar.trim());
  static bool isSipAkDaePaeDayPillar(String dayPillar) => _sipAkDaePaeDayPillars.contains(dayPillar.trim());

  // 현침살(간단): 甲/辛/卯/午/申 요소가 2개 이상이면 성립으로 소개되는 경우가 많음.
  // We compute by counting stems+branches matches across all four pillars.
  static int hyeonChimCount(Iterable<String> pillars) {
    int count = 0;
    for (final p in pillars) {
      final s = stemOf(p);
      final b = branchOf(p);
      if (s == '갑' || s == '신') count++;
      if (b == '묘' || b == '오' || b == '신') count++;
    }
    return count;
  }

  static bool hasAnyBranch(Iterable<String> branches, String target) {
    for (final b in branches) {
      if (b == target) return true;
    }
    return false;
  }
}
