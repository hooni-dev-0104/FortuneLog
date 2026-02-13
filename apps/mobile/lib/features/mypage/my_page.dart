import 'package:flutter/material.dart';

import '../../core/ui/app_widgets.dart';

class MyPage extends StatelessWidget {
  const MyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: const [
        PageSection(
          title: '계정 정보',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('kodekk0713@gmail.com'),
              SizedBox(height: 6),
              Text('로그인 계정 관리, 로그아웃'),
            ],
          ),
        ),
        SizedBox(height: 10),
        PageSection(
          title: '출생정보 관리',
          subtitle: '기존 프로필 재사용 또는 수정',
          child: _MenuRow(title: '출생 프로필 2개', subtitle: '최근 수정: 2026-02-13'),
        ),
        SizedBox(height: 10),
        PageSection(
          title: '주문 / 결제',
          child: Column(
            children: [
              _StatusRow(label: '프리미엄 리포트', badge: '결제 완료', tone: BadgeTone.success),
              SizedBox(height: 8),
              _StatusRow(label: '월간 분석 리포트', badge: '결제 대기', tone: BadgeTone.warning),
            ],
          ),
        ),
        SizedBox(height: 10),
        PageSection(
          title: '구독 관리',
          child: Column(
            children: [
              _StatusRow(label: 'Fortune Plus', badge: 'active(이용중)', tone: BadgeTone.success),
              SizedBox(height: 8),
              _StatusRow(label: '결제수단 갱신 필요', badge: 'grace(유예기간)', tone: BadgeTone.warning),
            ],
          ),
        ),
        SizedBox(height: 10),
        PageSection(
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
  const _MenuRow({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
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
