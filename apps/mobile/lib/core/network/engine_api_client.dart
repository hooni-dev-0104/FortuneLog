abstract interface class EngineApiClient {
  Future<ChartResponseDto> calculateChart(CalculateChartRequestDto request);
  Future<ReportResponseDto> generateReport(GenerateReportRequestDto request);
  Future<DailyFortuneResponseDto> generateDailyFortune(
    GenerateDailyFortuneRequestDto request,
  );
}

class CalculateChartRequestDto {
  final String userId;
  final String birthProfileId;
  final String birthDate;
  final String birthTime;
  final String birthTimezone;
  final String birthLocation;
  final String calendarType;
  final bool leapMonth;
  final String gender;
  final bool unknownBirthTime;

  const CalculateChartRequestDto({
    required this.userId,
    required this.birthProfileId,
    required this.birthDate,
    required this.birthTime,
    required this.birthTimezone,
    required this.birthLocation,
    required this.calendarType,
    required this.leapMonth,
    required this.gender,
    required this.unknownBirthTime,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'birthProfileId': birthProfileId,
    'birthDate': birthDate,
    'birthTime': birthTime,
    'birthTimezone': birthTimezone,
    'birthLocation': birthLocation,
    'calendarType': calendarType,
    'leapMonth': leapMonth,
    'gender': gender,
    'unknownBirthTime': unknownBirthTime,
  };
}

class GenerateReportRequestDto {
  final String userId;
  final String chartId;
  final String reportType;

  const GenerateReportRequestDto({
    required this.userId,
    required this.chartId,
    required this.reportType,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'chartId': chartId,
    'reportType': reportType,
  };
}

class GenerateDailyFortuneRequestDto {
  final String userId;
  final String chartId;
  final String date;

  const GenerateDailyFortuneRequestDto({
    required this.userId,
    required this.chartId,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'chartId': chartId,
    'date': date,
  };
}

class ChartResponseDto {
  final String chartId;
  final String engineVersion;
  final Map<String, String> chart;
  final Map<String, int> fiveElements;

  const ChartResponseDto({
    required this.chartId,
    required this.engineVersion,
    required this.chart,
    required this.fiveElements,
  });

  factory ChartResponseDto.fromJson(Map<String, dynamic> json) {
    return ChartResponseDto(
      chartId: json['chartId'] as String,
      engineVersion: json['engineVersion'] as String,
      chart: (json['chart'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      fiveElements: (json['fiveElements'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as int),
      ),
    );
  }
}

class ReportResponseDto {
  final String chartId;
  final String reportType;
  final Map<String, dynamic> content;

  const ReportResponseDto({
    required this.chartId,
    required this.reportType,
    required this.content,
  });

  factory ReportResponseDto.fromJson(Map<String, dynamic> json) {
    return ReportResponseDto(
      chartId: json['chartId'] as String,
      reportType: json['reportType'] as String,
      content: json['content'] as Map<String, dynamic>,
    );
  }
}

class DailyFortuneResponseDto {
  final String userId;
  final String date;
  final int score;
  final Map<String, String> category;
  final List<String> actions;

  const DailyFortuneResponseDto({
    required this.userId,
    required this.date,
    required this.score,
    required this.category,
    required this.actions,
  });

  factory DailyFortuneResponseDto.fromJson(Map<String, dynamic> json) {
    return DailyFortuneResponseDto(
      userId: json['userId'] as String,
      date: json['date'] as String,
      score: json['score'] as int,
      category: (json['category'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      ),
      actions: List<String>.from(json['actions'] as List<dynamic>),
    );
  }
}
