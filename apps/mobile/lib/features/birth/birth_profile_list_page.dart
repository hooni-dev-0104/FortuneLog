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
  bool _showAll = false;
  bool _deletingAll = false;

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
    final userId = session.user.id;

    final rows = await supabase
        .from('birth_profiles')
        .select(
          'id,birth_datetime_local,birth_timezone,birth_location,calendar_type,is_leap_month,gender,unknown_birth_time,created_at',
        )
        // Even if RLS is misconfigured, always filter client-side by current user.
        .eq('user_id', userId)
        // Some environments don't have updated_at yet. created_at exists by default.
        .order('created_at', ascending: false);

    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<void> _refresh() async {
    setState(() => _future = _fetch());
  }

  Future<void> _deleteAllMyProfiles(int count) async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      throw StateError('로그인이 필요합니다.');
    }
    final userId = session.user.id;

    final controller = TextEditingController();
    bool confirmed = false;

    // Ask for an explicit confirmation keyword to prevent accidental data loss.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('전체 삭제'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('내 출생 프로필 $count개를 삭제합니다.'),
              const SizedBox(height: 8),
              const Text(
                '연동된 사주 차트/리포트/오늘 운세 데이터도 함께 삭제될 수 있습니다.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Text('진행하려면 아래에 "삭제"를 입력하세요.'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: '삭제'),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                final ok = value.text.trim() == '삭제';
                return FilledButton(
                  onPressed: ok
                      ? () {
                          confirmed = true;
                          Navigator.pop(context);
                        }
                      : null,
                  child: const Text('삭제하기'),
                );
              },
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (!confirmed) return;

    setState(() => _deletingAll = true);
    try {
      // Delete only my rows; DB FKs should cascade related rows (charts/reports).
      await supabase.from('birth_profiles').delete().eq('user_id', userId);
      if (!mounted) return;
      setState(() => _showAll = false);
      await _refresh();
    } finally {
      if (mounted) setState(() => _deletingAll = false);
    }
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
            String msg;
            final err = snapshot.error;
            if (err is StateError) {
              msg = err.message;
            } else if (err is PostgrestException) {
              msg = err.message;
            } else {
              msg = '목록 조회에 실패했습니다.';
            }
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
          final visibleProfiles = _showAll ? profiles : (profiles.isEmpty ? profiles : profiles.take(1).toList());
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            children: [
              PageSection(
                title: '프로필',
                subtitle: profiles.isEmpty
                    ? '새로 만들면 대시보드/오늘 운세에서 바로 사용할 수 있습니다.'
                    : (_showAll ? '전체 ${profiles.length}개' : '최신 1개 표시 (총 ${profiles.length}개)'),
                child: Column(
                  children: [
                    if (profiles.isEmpty) ...[
                      EmptyState(
                        title: '아직 출생 프로필이 없습니다',
                        description: '새 프로필을 만들어 사주 계산을 시작할 수 있습니다.',
                        actionText: '새로 만들기',
                        onAction: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BirthInputPage(forceCreate: true)),
                        ).then((_) => _refresh()),
                      ),
                    ] else ...[
                      if (profiles.length > 1) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => setState(() => _showAll = !_showAll),
                            child: Text(_showAll ? '최신 1개만 보기' : '전체 보기'),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      for (final p in visibleProfiles) ...[
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
                                        '생성: ${(p['created_at'] as String?) ?? '-'}',
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
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BirthInputPage(forceCreate: true)),
                        ).then((_) => _refresh()),
                        child: const Text('새 프로필 만들기'),
                      ),
                      if (profiles.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _deletingAll ? null : () => _deleteAllMyProfiles(profiles.length),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9A3025),
                            side: const BorderSide(color: Color(0xFFF3C4C1)),
                          ),
                          child: _deletingAll
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('내 출생 프로필 전체 삭제'),
                        ),
                      ],
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
