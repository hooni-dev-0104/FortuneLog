// Minimal "신살/귀인" helpers derived from the 4 pillars string.
//
// This is intentionally lightweight and UI-facing. If/when the engine becomes authoritative for
// interpretations, move this to the backend and store in chart_json/report content.

class SajuStars {
  static const _stems = <String>['갑', '을', '병', '정', '무', '기', '경', '신', '임', '계'];
  static const _branches = <String>['자', '축', '인', '묘', '진', '사', '오', '미', '신', '유', '술', '해'];

  // Element keys: wood/fire/earth/metal/water
  static String? stemElementKey(String stem) {
    switch (stem) {
      case '갑':
      case '을':
        return 'wood';
      case '병':
      case '정':
        return 'fire';
      case '무':
      case '기':
        return 'earth';
      case '경':
      case '신':
        return 'metal';
      case '임':
      case '계':
        return 'water';
    }
    return null;
  }

  static String? branchElementKey(String branch) {
    switch (branch) {
      case '자':
      case '해':
        return 'water';
      case '축':
      case '진':
      case '미':
      case '술':
        return 'earth';
      case '인':
      case '묘':
        return 'wood';
      case '사':
      case '오':
        return 'fire';
      case '신':
      case '유':
        return 'metal';
    }
    return null;
  }

  static String? pillarStemElementKey(String pillar) {
    final s = stemOf(pillar);
    return s == null ? null : stemElementKey(s);
  }

  static String? pillarBranchElementKey(String pillar) {
    final b = branchOf(pillar);
    return b == null ? null : branchElementKey(b);
  }

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

  static String? branchAtOffset(String branch, int delta) {
    final i = _branches.indexOf(branch);
    if (i < 0) return null;
    final n = _branches.length;
    final j = (i + delta) % n;
    return _branches[(j + n) % n];
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

  // ---- Additional 길신/흉살 helpers (UI-facing) ----

  // 홍염살: day stem -> branch (from common tables).
  static const Map<String, String> _hongYeom = {
    '갑': '오',
    '을': '오',
    '병': '인',
    '정': '미',
    '무': '진',
    '기': '진',
    '경': '술',
    '신': '유',
    '임': '자',
    '계': '신',
  };

  static String? hongYeomTarget(String dayStem) => _hongYeom[dayStem];

  // 백호살(백호대살): 7 pillars (presence if any pillar matches; strongest when day pillar).
  static const Set<String> _baekHoPillars = {
    '갑진',
    '을미',
    '병술',
    '정축',
    '무진',
    '임술',
    '계축',
  };

  static bool isBaekHoPillar(String pillar) => _baekHoPillars.contains(pillar.trim());

  // 격각살: year branch + day branch combos (table-form).
  static bool isGyeokGak({required String? yearBranch, required String? dayBranch}) {
    if (yearBranch == null || dayBranch == null) return false;
    if (const {'인', '묘', '진'}.contains(yearBranch)) return dayBranch == '오';
    if (const {'사', '오', '미'}.contains(yearBranch)) return dayBranch == '유';
    if (const {'신', '유', '술'}.contains(yearBranch)) return dayBranch == '자';
    if (const {'해', '자', '축'}.contains(yearBranch)) return dayBranch == '묘';
    return false;
  }

  // 고진살(=고신살로 부르는 경우가 많음): base(연지/일지) -> target branch.
  static String? goJinTargetByBaseBranch(String baseBranch) {
    if (const {'인', '묘', '진'}.contains(baseBranch)) return '사';
    if (const {'사', '오', '미'}.contains(baseBranch)) return '신';
    if (const {'신', '유', '술'}.contains(baseBranch)) return '해';
    if (const {'해', '자', '축'}.contains(baseBranch)) return '인';
    return null;
  }

  // 과숙살: base(연지/일지) -> target branch.
  static String? gwaSukTargetByBaseBranch(String baseBranch) {
    if (const {'인', '묘', '진'}.contains(baseBranch)) return '축';
    if (const {'사', '오', '미'}.contains(baseBranch)) return '진';
    if (const {'신', '유', '술'}.contains(baseBranch)) return '미';
    if (const {'해', '자', '축'}.contains(baseBranch)) return '술';
    return null;
  }

  // 귀문관살: adjacent pairs among (month/day) or (day/hour).
  static const List<Set<String>> _gwiMunPairs = [
    {'진', '해'},
    {'축', '오'},
    {'사', '술'},
    {'묘', '신'},
    {'인', '미'},
    {'자', '유'},
  ];

  static bool _isGwiMunPair(String a, String b) {
    for (final p in _gwiMunPairs) {
      if (p.contains(a) && p.contains(b)) return true;
    }
    return false;
  }

  static bool hasGwiMunGwanSal({required String? monthBranch, required String? dayBranch, required String? hourBranch}) {
    if (monthBranch == null || dayBranch == null) return false;
    if (_isGwiMunPair(monthBranch, dayBranch)) return true;
    if (hourBranch != null && _isGwiMunPair(dayBranch, hourBranch)) return true;
    return false;
  }

  // 급각살: month-branch season group -> target branches; present if target appears in any pillar.
  static Set<String> geupGakTargetsByMonthBranch(String monthBranch) {
    if (const {'인', '묘', '진'}.contains(monthBranch)) return const {'해', '자'};
    if (const {'사', '오', '미'}.contains(monthBranch)) return const {'묘', '미'};
    if (const {'신', '유', '술'}.contains(monthBranch)) return const {'인', '술'};
    if (const {'해', '자', '축'}.contains(monthBranch)) return const {'진', '축'};
    return const {};
  }

  // 단교관살: month branch -> target branch; present if day/hour branch equals the target.
  static const Map<String, String> _danGyoGwan = {
    '인': '오',
    '묘': '묘',
    '진': '신',
    '사': '축',
    '오': '술',
    '미': '유',
    '신': '진',
    '유': '사',
    '술': '오',
    '해': '미',
    '자': '해',
    '축': '자',
  };

  static String? danGyoGwanTargetByMonthBranch(String monthBranch) => _danGyoGwan[monthBranch];

  // 곡각살: commonly cited pillar sets.
  static const Set<String> _gokGakPillars = {
    '을축',
    '을사',
    '을미',
    '을유',
    '을해',
    '기축',
    '기사',
    '기미',
    '기유',
    '기해',
    '정사',
    '신사',
    '계사',
  };

  static bool isGokGakPillar(String pillar) => _gokGakPillars.contains(pillar.trim());

  // 천라지망: day-branch + (other branch) pair.
  // We keep it simple:
  // - 천라: 일지가 술/해이고, 다른 지지에 술 또는 해가 함께 있으면 성립.
  // - 지망: 일지가 진/사이고, 다른 지지에 진 또는 사가 함께 있으면 성립.
  static String? cheonRaJiMangType({required String? dayBranch, required List<String> allBranches}) {
    if (dayBranch == null) return null;
    if (dayBranch == '술' || dayBranch == '해') {
      final other = dayBranch == '술' ? '해' : '술';
      return allBranches.contains(other) ? '천라' : null;
    }
    if (dayBranch == '진' || dayBranch == '사') {
      final other = dayBranch == '진' ? '사' : '진';
      return allBranches.contains(other) ? '지망' : null;
    }
    return null;
  }

  // 평두살(간단): 특정 글자(예: 甲, 丙, 丁, 壬, 辰, 子)가 4자 이상이면 성립으로 소개되는 경우가 있음.
  static const Set<String> _pyeongDuStems = {'갑', '병', '정', '임'};
  static const Set<String> _pyeongDuBranches = {'진', '자'};

  static int pyeongDuCount(Iterable<String> pillars) {
    int c = 0;
    for (final p in pillars) {
      final s = stemOf(p);
      final b = branchOf(p);
      if (s != null && _pyeongDuStems.contains(s)) c++;
      if (b != null && _pyeongDuBranches.contains(b)) c++;
    }
    return c;
  }

  // 상문살/조객살: year branch -> target branch (often used in 운(年) 해석; we provide a natal "presence" helper).
  static String? sangMunTargetByYearBranch(String yearBranch) => branchAtOffset(yearBranch, 2);
  static String? joGaekTargetByYearBranch(String yearBranch) => branchAtOffset(yearBranch, -2);

  // 대모살(대耗): In some references used as an alias of 겁살.
  // We compute a commonly used "겁살" target from year-branch's 삼합 group.
  static String? daeMoTargetByYearBranch(String yearBranch) {
    // 인오술 -> 해, 사유축 -> 인, 신자진 -> 사, 해묘미 -> 신
    if (const {'인', '오', '술'}.contains(yearBranch)) return '해';
    if (const {'사', '유', '축'}.contains(yearBranch)) return '인';
    if (const {'신', '자', '진'}.contains(yearBranch)) return '사';
    if (const {'해', '묘', '미'}.contains(yearBranch)) return '신';
    return null;
  }

  // 구교살(=구추살 九醜煞 로 소개되는 경우가 많음): 9 day-pillar set.
  static const Set<String> _guGyoDayPillars = {
    '갑술',
    '을유',
    '병신',
    '정미',
    '무오',
    '기사',
    '경진',
    '신묘',
    '임인',
  };

  static bool isGuGyoDayPillar(String dayPillar) => _guGyoDayPillars.contains(dayPillar.trim());

  // 장형살(간단): 형(刑) 계열 조합이 있을 때 "규정/처벌"로 풀이되는 경우가 있어,
  // 대표 조합(자묘형, 인사신 삼형, 축미술 삼형, 진/오/유/해 자형)을 체크합니다.
  static bool hasJangHyeongSal(List<String> branches) {
    if (branches.contains('자') && branches.contains('묘')) return true; // 자묘형
    const insasin = {'인', '사', '신'};
    if (branches.toSet().containsAll(insasin)) return true;
    const chukmisul = {'축', '미', '술'};
    if (branches.toSet().containsAll(chukmisul)) return true;

    // 자형(自刑) - 진/오/유/해가 2개 이상 등장하는 경우
    for (final b in const ['진', '오', '유', '해']) {
      int c = 0;
      for (final x in branches) {
        if (x == b) c++;
      }
      if (c >= 2) return true;
    }
    return false;
  }

  // 정인(십신) - day stem 기준으로 다른 stem이 정인에 해당하는지 (본가인 신살과는 다른 계산일 수 있음).
  static const Map<String, int> _stemIndex = {
    '갑': 0,
    '을': 1,
    '병': 2,
    '정': 3,
    '무': 4,
    '기': 5,
    '경': 6,
    '신': 7,
    '임': 8,
    '계': 9,
  };

  static bool _isYangStem(String stem) {
    final i = _stemIndex[stem];
    if (i == null) return false;
    return i % 2 == 0;
  }

  static String? jeongInStemForDayStem(String dayStem) {
    final dayEl = stemElementKey(dayStem);
    if (dayEl == null) return null;
    final resourceEl = switch (dayEl) {
      'wood' => 'water',
      'fire' => 'wood',
      'earth' => 'fire',
      'metal' => 'earth',
      'water' => 'metal',
      _ => null,
    };
    if (resourceEl == null) return null;

    // 정인: same polarity as day stem among resource element stems.
    final wantYang = _isYangStem(dayStem);
    final candidates = switch (resourceEl) {
      'wood' => const ['갑', '을'],
      'fire' => const ['병', '정'],
      'earth' => const ['무', '기'],
      'metal' => const ['경', '신'],
      'water' => const ['임', '계'],
      _ => const <String>[],
    };
    if (candidates.isEmpty) return null;
    return wantYang ? candidates.first : candidates.last;
  }
}
