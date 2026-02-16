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

  static List<String> stemsOfPillars(Iterable<String> pillars) =>
      pillars.map(stemOf).whereType<String>().toList(growable: false);

  static List<String> branchesOfPillars(Iterable<String> pillars) =>
      pillars.map(branchOf).whereType<String>().toList(growable: false);

  static bool hasStem(Iterable<String> pillars, String stem) => stemsOfPillars(pillars).contains(stem);

  static bool hasBranch(Iterable<String> pillars, String branch) => branchesOfPillars(pillars).contains(branch);

  static String? previousBranch(String branch) {
    final i = _branches.indexOf(branch);
    if (i < 0) return null;
    return _branches[(i + _branches.length - 1) % _branches.length];
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

  // 월덕귀인/천덕귀인: month branch -> stem (common "triad" table).
  // Notes:
  // - There are multiple variants in the wild (some include stem+branch targets).
  // - We intentionally implement a widely-used stem-only table for consistency in UI.
  // - If later needed, we can extend to stem/branch targets with disambiguation.
  static String? wolDeokStemByMonthBranch(String monthBranch) {
    // 寅午戌 -> 丙, 巳酉丑 -> 庚, 申子辰 -> 壬, 亥卯未 -> 甲
    switch (monthBranch) {
      case '인':
      case '오':
      case '술':
        return '병';
      case '사':
      case '유':
      case '축':
        return '경';
      case '신':
      case '자':
      case '진':
        return '임';
      case '해':
      case '묘':
      case '미':
        return '갑';
      default:
        return null;
    }
  }

  static String? cheonDeokStemByMonthBranch(String monthBranch) {
    // 寅午戌 -> 丁, 巳酉丑 -> 庚, 申子辰 -> 壬, 亥卯未 -> 甲
    // (A common simplified variant; some sources differ.)
    switch (monthBranch) {
      case '인':
      case '오':
      case '술':
        return '정';
      case '사':
      case '유':
      case '축':
        return '경';
      case '신':
      case '자':
      case '진':
        return '임';
      case '해':
      case '묘':
      case '미':
        return '갑';
      default:
        return null;
    }
  }

  static String? cheonEuiTargetByMonthBranch(String monthBranch) => previousBranch(monthBranch);

  // 태극귀인: day stem -> branches (표 기준).
  static const Map<String, List<String>> _taeGeuk = {
    '갑': ['자', '오'],
    '을': ['자', '오'],
    '병': ['묘', '유'],
    '정': ['묘', '유'],
    '무': ['축', '진', '미', '술'],
    '기': ['축', '진', '미', '술'],
    '경': ['인', '해'],
    '신': ['인', '해'],
    '임': ['사', '신'],
    '계': ['사', '신'],
  };

  // 천주귀인(=천주귀인/천주성): day stem -> branch.
  static const Map<String, String> _cheonJu = {
    '갑': '사',
    '을': '오',
    '병': '사',
    '정': '오',
    '무': '신',
    '기': '유',
    '경': '해',
    '신': '자',
    '임': '인',
    '계': '묘',
  };

  // 관귀학관(사관귀인): day stem -> branch.
  static const Map<String, String> _gwanGwiHakGwan = {
    '갑': '사',
    '을': '사',
    '병': '신',
    '정': '신',
    '무': '해',
    '기': '해',
    '경': '인',
    '신': '인',
    '임': '신',
    '계': '신',
  };

  // 문곡귀인: day stem -> branch.
  static const Map<String, String> _munGok = {
    '갑': '해',
    '을': '자',
    '병': '인',
    '정': '묘',
    '무': '인',
    '기': '묘',
    '경': '사',
    '신': '오',
    '임': '신',
    '계': '유',
  };

  // 학당귀인: day stem -> branch.
  static const Map<String, String> _hakDang = {
    '갑': '해',
    '을': '오',
    '병': '인',
    '정': '유',
    '무': '인',
    '기': '유',
    '경': '사',
    '신': '자',
    '임': '신',
    '계': '묘',
  };

  // 금여록: day stem -> branch.
  static const Map<String, String> _geumYeo = {
    '갑': '진',
    '을': '사',
    '병': '미',
    '정': '신',
    '무': '미',
    '기': '신',
    '경': '술',
    '신': '해',
    '임': '축',
    '계': '인',
  };

  // 암록: day stem -> branch.
  static const Map<String, String> _amRok = {
    '갑': '해',
    '을': '술',
    '병': '신',
    '정': '미',
    '무': '신',
    '기': '미',
    '경': '사',
    '신': '진',
    '임': '인',
    '계': '축',
  };

  // 십간록(건록): day stem -> branch.
  static const Map<String, String> _geonRok = {
    '갑': '인',
    '을': '묘',
    '병': '사',
    '정': '오',
    '무': '사',
    '기': '오',
    '경': '신',
    '신': '유',
    '임': '해',
    '계': '자',
  };

  static List<String> taeGeukTargets(String dayStem) => _taeGeuk[dayStem] ?? const [];
  static String? cheonJuTarget(String dayStem) => _cheonJu[dayStem];
  static String? gwanGwiHakGwanTarget(String dayStem) => _gwanGwiHakGwan[dayStem];
  static String? munGokTarget(String dayStem) => _munGok[dayStem];
  static String? hakDangTarget(String dayStem) => _hakDang[dayStem];
  static String? geumYeoTarget(String dayStem) => _geumYeo[dayStem];
  static String? amRokTarget(String dayStem) => _amRok[dayStem];
  static String? geonRokBranch(String dayStem) => _geonRok[dayStem];

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

  static String? yeokMaTargetByBranch(String baseBranch) {
    // 역마: (연지 또는 일지) 기준 삼합의 첫 글자를 충하는 지지.
    // 인오술 -> 신, 신자진 -> 인, 사유축 -> 해, 해묘미 -> 사
    switch (baseBranch) {
      case '인':
      case '오':
      case '술':
        return '신';
      case '신':
      case '자':
      case '진':
        return '인';
      case '사':
      case '유':
      case '축':
        return '해';
      case '해':
      case '묘':
      case '미':
        return '사';
      default:
        return null;
    }
  }

  static String? yeokMaTarget({String? yearBranch, String? dayBranch}) {
    final base = yearBranch ?? dayBranch;
    if (base == null) return null;
    return yeokMaTargetByBranch(base);
  }

  static bool hasSamGi(Iterable<String> pillars) {
    final stems = stemsOfPillars(pillars).toSet();
    const cheonSang = {'갑', '무', '경'};
    const jiHa = {'을', '병', '정'};
    const inJung = {'임', '계', '신'}; // here '신' is the stem 辛
    return stems.containsAll(cheonSang) || stems.containsAll(jiHa) || stems.containsAll(inJung);
  }
}
