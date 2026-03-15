import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PolicyDocumentRouteArgs {
  const PolicyDocumentRouteArgs({
    required this.type,
    required this.externalUrl,
  });

  final PolicyDocumentType type;
  final Uri externalUrl;
}

enum PolicyDocumentType {
  terms,
  privacy,
  refund,
}

class PolicyDocumentPage extends StatelessWidget {
  const PolicyDocumentPage({super.key, required this.args});

  static const routeName = '/policy';

  final PolicyDocumentRouteArgs args;

  @override
  Widget build(BuildContext context) {
    final doc = _policyDocument(args.type);
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        children: [
          Text(
            '최종 업데이트: ${doc.updatedAt}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            '베타 배포 기준 정책 문서입니다. 최신 고지본은 웹 문서에서 확인할 수 있습니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => _openExternal(context, args.externalUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('웹 문서 열기'),
          ),
          const SizedBox(height: 16),
          for (final section in doc.sections) ...[
            Text(section.heading,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(section.body, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Future<void> _openExternal(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('웹 정책 문서를 열 수 없습니다.')),
    );
  }
}

class _PolicyDocument {
  const _PolicyDocument({
    required this.title,
    required this.updatedAt,
    required this.sections,
  });

  final String title;
  final String updatedAt;
  final List<_PolicySection> sections;
}

class _PolicySection {
  const _PolicySection({
    required this.heading,
    required this.body,
  });

  final String heading;
  final String body;
}

_PolicyDocument _policyDocument(PolicyDocumentType type) {
  switch (type) {
    case PolicyDocumentType.terms:
      return const _PolicyDocument(
        title: '이용약관',
        updatedAt: '2026-03-15',
        sections: [
          _PolicySection(
            heading: '1. 서비스 소개',
            body: 'FortuneLog는 사용자가 입력한 출생정보를 기반으로 사주 차트와 해석 콘텐츠를 제공하는 서비스입니다.',
          ),
          _PolicySection(
            heading: '2. 계정 및 이용 제한',
            body: '회원은 본인 정보를 정확히 입력해야 하며, 계정 공유/도용/비정상 접근 시 이용이 제한될 수 있습니다.',
          ),
          _PolicySection(
            heading: '3. 유료 기능',
            body: '일부 리포트와 기능은 유료로 제공됩니다. 가격, 결제 수단, 구독 조건은 앱과 스토어 정책을 따릅니다.',
          ),
          _PolicySection(
            heading: '4. 금지 행위',
            body:
                '서비스 악용, 자동화된 비정상 호출, 타인 정보 무단 수집, 법령 위반 행위는 금지되며 계정이 제한될 수 있습니다.',
          ),
          _PolicySection(
            heading: '5. 약관 변경',
            body: '법령/서비스 변경 시 약관이 수정될 수 있으며, 중요한 변경은 앱 공지 또는 웹 공지로 안내합니다.',
          ),
        ],
      );
    case PolicyDocumentType.privacy:
      return const _PolicyDocument(
        title: '개인정보 처리방침',
        updatedAt: '2026-03-15',
        sections: [
          _PolicySection(
            heading: '1. 수집 항목',
            body:
                '계정 정보(이메일, 닉네임), 출생정보(생년월일/시간/장소/성별), 결제 상태, 서비스 이용 로그를 처리합니다.',
          ),
          _PolicySection(
            heading: '2. 이용 목적',
            body:
                '회원 식별, 서비스 제공(사주 계산/리포트), 결제 상태 반영, 오류 대응 및 품질 개선을 위해 사용합니다.',
          ),
          _PolicySection(
            heading: '3. 보관 기간',
            body: '관계 법령상 보존 의무가 없는 정보는 회원 탈퇴 요청 처리 완료 후 비식별화 또는 삭제됩니다.',
          ),
          _PolicySection(
            heading: '4. 제3자 제공',
            body:
                '법령상 근거가 있는 경우를 제외하고 개인정보를 제3자에게 판매하지 않습니다. 결제/인증 제공자와의 처리 위탁이 포함될 수 있습니다.',
          ),
          _PolicySection(
            heading: '5. 이용자 권리',
            body:
                '이용자는 조회/정정/삭제/처리정지를 요청할 수 있으며, 앱 내 회원 탈퇴 요청 기능을 통해 파기 절차를 시작할 수 있습니다.',
          ),
        ],
      );
    case PolicyDocumentType.refund:
      return const _PolicyDocument(
        title: '환불 정책',
        updatedAt: '2026-03-15',
        sections: [
          _PolicySection(
            heading: '1. 기본 원칙',
            body:
                '디지털 콘텐츠 특성상 사용이 시작된 상품은 환불이 제한될 수 있습니다. 최종 환불 판단은 결제 스토어 정책을 따릅니다.',
          ),
          _PolicySection(
            heading: '2. 환불 가능 사례',
            body:
                '중복 결제, 시스템 장애로 인한 미제공, 관련 법령상 청약철회 가능 요건을 충족하는 경우 환불을 검토합니다.',
          ),
          _PolicySection(
            heading: '3. 환불 제한 사례',
            body:
                '콘텐츠 열람/사용 후 단순 변심, 이용자 환경 문제(기기, 네트워크), 약관 위반으로 인한 제한은 환불이 제한될 수 있습니다.',
          ),
          _PolicySection(
            heading: '4. 신청 방법',
            body:
                '스토어 결제는 App Store/Google Play 환불 절차를 우선 이용하고, 추가 확인이 필요하면 고객 문의 채널로 영수증과 계정 정보를 제출합니다.',
          ),
          _PolicySection(
            heading: '5. 처리 기간',
            body:
                '환불 심사는 접수 후 영업일 기준으로 순차 처리되며, 결제 수단에 따라 실제 환불 반영 시점이 달라질 수 있습니다.',
          ),
        ],
      );
  }
}
