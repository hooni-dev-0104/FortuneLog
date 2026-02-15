import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ui/app_widgets.dart';
import '../auth/login_page.dart';
import '../birth/birth_profile_list_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  bool _loggingOut = false;

  Future<Map<String, String>> _birthProfileSummary() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      return {'title': '로그인이 필요합니다', 'subtitle': '로그인 후 사용 가능합니다.'};
    }

    final rows = await supabase
        .from('birth_profiles')
        .select('id,updated_at,created_at')
        .order('updated_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      return {'title': '출생 프로필 0개', 'subtitle': '아직 생성된 프로필이 없습니다.'};
    }

    final latest = (list.first['updated_at'] as String?) ?? (list.first['created_at'] as String?) ?? '-';
    return {'title': '출생 프로필 ${list.length}개', 'subtitle': '최근 수정: $latest'};
  }

  String _currentEmail() {
    try {
      return Supabase.instance.client.auth.currentUser?.email ?? '로그인 없음';
    } catch (_) {
      return 'Supabase 미연결';
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, LoginPage.routeName, (route) => false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('로그아웃에 실패했습니다. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _currentEmail();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        PageSection(
          title: '계정 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: _loggingOut ? null : _logout,
                child: _loggingOut
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('로그아웃'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '출생정보 관리',
          subtitle: '기존 프로필 재사용 또는 수정',
          child: FutureBuilder<Map<String, String>>(
            future: _birthProfileSummary(),
            builder: (context, snapshot) {
              final title = snapshot.data?['title'] ?? '출생 프로필';
              final subtitle = snapshot.data?['subtitle'] ?? '목록 불러오는 중...';
              return _MenuRow(
                title: title,
                subtitle: subtitle,
                onTap: () => Navigator.pushNamed(context, BirthProfileListPage.routeName),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        const PageSection(
          title: '주문 / 결제',
          child: Column(
            children: [
              _StatusRow(label: '프리미엄 리포트', badge: '결제 완료', tone: BadgeTone.success),
              SizedBox(height: 8),
              _StatusRow(label: '월간 분석 리포트', badge: '결제 대기', tone: BadgeTone.warning),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const PageSection(
          title: '구독 관리',
          child: Column(
            children: [
              _StatusRow(label: 'Fortune Plus', badge: 'active(이용중)', tone: BadgeTone.success),
              SizedBox(height: 8),
              _StatusRow(label: '결제수단 갱신 필요', badge: 'grace(유예기간)', tone: BadgeTone.warning),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const PageSection(
          title: '정책 문서',
          child: Column(
            children: [
              _MenuRow(title: '이용약관', subtitle: '최종 업데이트: 2026-02-01'),
              SizedBox(height: 8),
              _MenuRow(title: '개인정보 처리방침', subtitle: '최종 업데이트: 2026-02-01'),
            ],
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.badge, required this.tone});

  final String label;
  final String badge;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        StatusBadge(label: badge, tone: tone),
      ],
    );
  }
}
