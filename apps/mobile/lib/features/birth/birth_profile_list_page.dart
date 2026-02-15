import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import 'birth_input_page.dart';

class BirthProfileListPage extends StatefulWidget {
  const BirthProfileListPage({super.key});

  static const routeName = '/birth-profiles';

  @override
  State<BirthProfileListPage> createState() => _BirthProfileListPageState();
}

class _BirthProfileListPageState extends State<BirthProfileListPage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final rows = await supabase
        .from('birth_profiles')
        .select(
          'id,birth_datetime_local,birth_timezone,birth_location,calendar_type,is_leap_month,gender,unknown_birth_time,updated_at,created_at',
        )
        .order('updated_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetch());
  }

  String _titleFor(Map<String, dynamic> p) {
    final dt = (p['birth_datetime_local'] as String?) ?? '';
    final location = (p['birth_location'] as String?) ?? '';
    final calendarType = (p['calendar_type'] as String?) ?? 'solar';
    final unknown = (p['unknown_birth_time'] as bool?) ?? false;

    final date = dt.contains('T') ? dt.split('T').first : dt;
    final time = dt.contains('T') ? dt.split('T').last.substring(0, 5) : '';
    final timeLabel = unknown ? '시간 미상' : (time.isEmpty ? '' : time);
    final calLabel = calendarType == 'lunar' ? '음력' : '양력';

    final parts = <String>[
      if (date.isNotEmpty) date,
      if (timeLabel.isNotEmpty) timeLabel,
      calLabel,
      if (location.isNotEmpty) location,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('출생정보 관리'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                const PageSection(
                  title: '불러오는 중',
                  child: SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            final msg = snapshot.error is StateError ? (snapshot.error as StateError).message : '목록 조회에 실패했습니다.';
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                StatusNotice.error(message: msg, requestId: 'birth-profiles'),
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: _refresh, child: const Text('재시도')),
              ],
            );
          }

          final profiles = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              PageSection(
                title: '프로필',
                subtitle: '탭하면 수정할 수 있습니다.',
                child: Column(
                  children: [
                    if (profiles.isEmpty) ...[
                      EmptyState(
                        title: '아직 출생 프로필이 없습니다',
                        description: '새 프로필을 만들어 사주 계산을 시작할 수 있습니다.',
                        actionText: '새로 만들기',
                        onAction: () => Navigator.pushNamed(context, BirthInputPage.routeName).then((_) => _refresh()),
                      ),
                    ] else ...[
                      for (final p in profiles) ...[
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BirthInputPage(initialProfile: p)),
                            ).then((_) => _refresh());
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _titleFor(p),
                                        style: Theme.of(context).textTheme.titleMedium,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '수정: ${(p['updated_at'] as String?) ?? (p['created_at'] as String?) ?? '-'}',
                                        style: Theme.of(context).textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                      ],
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => Navigator.pushNamed(context, BirthInputPage.routeName).then((_) => _refresh()),
                        child: const Text('새 프로필 만들기'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
