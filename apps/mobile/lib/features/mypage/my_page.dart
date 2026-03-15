import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/network/engine_api_client.dart';
import '../../core/network/engine_api_client_factory.dart';
import '../../core/network/engine_error_mapper.dart';
import '../../core/network/http_engine_api_client.dart';
import '../../core/ui/app_widgets.dart';
import '../auth/login_page.dart';
import '../birth/birth_input_page.dart';
import '../birth/birth_profile_list_page.dart';
import '../policy/policy_document_page.dart';

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const int _maxProfilesForFreeTier = 4;
  static final Uri _termsPolicyUrl = Uri.parse(const String.fromEnvironment(
    'POLICY_TERMS_URL',
    defaultValue: 'https://fortunelog.app/terms',
  ));
  static final Uri _privacyPolicyUrl = Uri.parse(const String.fromEnvironment(
    'POLICY_PRIVACY_URL',
    defaultValue: 'https://fortunelog.app/privacy',
  ));
  static final Uri _refundPolicyUrl = Uri.parse(const String.fromEnvironment(
    'POLICY_REFUND_URL',
    defaultValue: 'https://fortunelog.app/refund',
  ));

  bool _loggingOut = false;
  bool _deletionRequestSubmitting = false;
  late Future<_CommerceSummary> _commerceSummaryFuture;

  @override
  void initState() {
    super.initState();
    _commerceSummaryFuture = _loadCommerceSummary();
  }

  Future<Map<String, dynamic>> _birthProfileSummary() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      return {
        'title': '로그인이 필요합니다',
        'subtitle': '로그인 후 사용 가능합니다.',
        'count': 0,
        'canAdd': false,
      };
    }
    final userId = session.user.id;

    final rows = await supabase
        .from('birth_profiles')
        .select('id,created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) {
      return {
        'title': '출생 프로필 0개',
        'subtitle': '아직 생성된 프로필이 없습니다.',
        'count': 0,
        'canAdd': true,
      };
    }

    final count = list.length;
    return {
      'title': '출생 프로필 $count개',
      'subtitle': '무료 버전 최대 4개까지 관리할 수 있습니다.',
      'count': count,
      'canAdd': count < _maxProfilesForFreeTier,
    };
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
      Navigator.pushNamedAndRemoveUntil(
          context, LoginPage.routeName, (route) => false);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '로그아웃에 실패했습니다. 다시 시도해주세요.');
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  EngineApiClient _engineClient() {
    final baseUrl = const String.fromEnvironment('ENGINE_BASE_URL');
    if (baseUrl.isEmpty) {
      throw const FormatException('ENGINE_BASE_URL is empty');
    }
    return EngineApiClientFactory.create(baseUrl: baseUrl);
  }

  Future<void> _requestAccountDeletion() async {
    setState(() => _deletionRequestSubmitting = true);
    try {
      final response = await _engineClient().requestAccountDeletion(
        const RequestAccountDeletionRequestDto(),
      );
      await Supabase.instance.client.auth.signOut();

      if (!mounted) return;
      showAppSnackBar(
        context,
        response.alreadyRequested
            ? '이미 탈퇴 요청이 접수된 계정입니다. 로그아웃합니다.'
            : '탈퇴 요청이 접수되었습니다. 로그아웃합니다.',
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginPage.routeName,
        (route) => false,
      );
    } on FormatException catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'ENGINE_BASE_URL이 비어 있습니다. .env 설정을 확인해주세요.');
    } on EngineApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, EngineErrorMapper.userMessage(e));
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, '탈퇴 요청 중 오류가 발생했습니다. 잠시 후 다시 시도해주세요.');
    } finally {
      if (mounted) {
        setState(() => _deletionRequestSubmitting = false);
      }
    }
  }

  Future<void> _confirmAndRequestAccountDeletion() async {
    if (_deletionRequestSubmitting || _loggingOut) {
      return;
    }

    final proceedFirst = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원 탈퇴 요청'),
        content: const Text(
          '탈퇴 요청 시 계정 접근이 제한되며, 개인정보 비식별화/파기 작업이 순차 처리됩니다.\n'
          '진행하시겠어요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('다음'),
          ),
        ],
      ),
    );

    if (proceedFirst != true || !mounted) {
      return;
    }

    final proceedFinal = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('최종 확인'),
        content: const Text(
          '탈퇴 요청 후에는 동일 계정으로 즉시 이용할 수 없으며, 처리 완료 시 결제/구독 정보가 비활성화될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('탈퇴 요청'),
          ),
        ],
      ),
    );

    if (proceedFinal == true && mounted) {
      await _requestAccountDeletion();
    }
  }

  Future<_CommerceSummary> _loadCommerceSummary() async {
    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;
    if (session == null) {
      return const _CommerceSummary(orders: [], subscriptions: []);
    }

    final userId = session.user.id;

    final results = await Future.wait([
      supabase
          .from('orders')
          .select('status,provider,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3),
      supabase
          .from('subscriptions')
          .select('plan_code,status,expires_at,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(3),
    ]);

    final orders = (results[0] as List).cast<Map<String, dynamic>>();
    final subscriptions = (results[1] as List).cast<Map<String, dynamic>>();
    return _CommerceSummary(orders: orders, subscriptions: subscriptions);
  }

  void _refreshCommerceSummary() {
    setState(() {
      _commerceSummaryFuture = _loadCommerceSummary();
    });
  }

  Future<void> _openPolicy(PolicyDocumentType type, Uri uri) async {
    await Navigator.pushNamed(
      context,
      PolicyDocumentPage.routeName,
      arguments: PolicyDocumentRouteArgs(type: type, externalUrl: uri),
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '-';
    final local = parsed.toLocal();

    String pad(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${pad(local.month)}-${pad(local.day)} ${pad(local.hour)}:${pad(local.minute)}';
  }

  String _orderStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return '결제 완료';
      case 'failed':
        return '결제 실패';
      case 'canceled':
        return '결제 취소';
      case 'pending':
      default:
        return '결제 대기';
    }
  }

  BadgeTone _orderStatusTone(String status) {
    switch (status) {
      case 'paid':
        return BadgeTone.success;
      case 'failed':
        return BadgeTone.danger;
      case 'pending':
        return BadgeTone.warning;
      case 'canceled':
      default:
        return BadgeTone.neutral;
    }
  }

  String _subscriptionStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'active(이용중)';
      case 'grace':
        return 'grace(유예기간)';
      case 'expired':
        return 'expired(만료)';
      case 'canceled':
      default:
        return 'canceled(해지)';
    }
  }

  BadgeTone _subscriptionStatusTone(String status) {
    switch (status) {
      case 'active':
        return BadgeTone.success;
      case 'grace':
        return BadgeTone.warning;
      case 'expired':
      case 'canceled':
      default:
        return BadgeTone.neutral;
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
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('로그아웃'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _deletionRequestSubmitting || _loggingOut
                    ? null
                    : _confirmAndRequestAccountDeletion,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: _deletionRequestSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('회원 탈퇴 요청'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '출생정보 관리',
          subtitle: '마이페이지에서 최대 4개까지 직접 등록/수정할 수 있습니다.',
          child: FutureBuilder<Map<String, dynamic>>(
            future: _birthProfileSummary(),
            builder: (context, snapshot) {
              final waiting = snapshot.connectionState != ConnectionState.done;
              final hasError = snapshot.hasError;
              final canAdd = (snapshot.data?['canAdd'] as bool?) ?? false;
              final count = (snapshot.data?['count'] as int?) ?? 0;

              final title = snapshot.data?['title'] ?? '출생 프로필';
              final subtitle = hasError
                  ? '불러오지 못했습니다. 눌러서 다시 확인해주세요.'
                  : (snapshot.data?['subtitle'] ??
                      (waiting ? '불러오는 중...' : '내 프로필을 확인하고 수정할 수 있습니다.'));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MenuRow(
                    title: title,
                    subtitle: subtitle,
                    onTap: () => Navigator.pushNamed(
                        context, BirthProfileListPage.routeName),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: waiting
                              ? null
                              : () => Navigator.pushNamed(
                                  context, BirthProfileListPage.routeName),
                          child: const Text('목록에서 관리'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: (!waiting && !hasError && canAdd)
                              ? () async {
                                  await Navigator.pushNamed(
                                      context, BirthInputPage.routeName);
                                  if (!mounted) return;
                                  setState(() {});
                                }
                              : null,
                          child: Text(canAdd ? '새 출생정보 추가' : '4개 등록 완료'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$count/$_maxProfilesForFreeTier 사용 중',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '주문 / 결제 · 구독',
          child: FutureBuilder<_CommerceSummary>(
            future: _commerceSummaryFuture,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '결제/구독 상태를 불러오지 못했습니다.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: _refreshCommerceSummary,
                      child: const Text('다시 시도'),
                    ),
                  ],
                );
              }

              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final summary = snapshot.data ??
                  const _CommerceSummary(orders: [], subscriptions: []);
              final orderWidgets = summary.orders
                  .map(
                    (order) => _StatusRow(
                      label:
                          '${order['provider'] ?? '결제'} · ${_formatDateTime(order['created_at'])}',
                      badge: _orderStatusLabel(
                          (order['status'] ?? 'pending').toString()),
                      tone: _orderStatusTone(
                        (order['status'] ?? 'pending').toString(),
                      ),
                    ),
                  )
                  .toList();
              final subscriptionWidgets = summary.subscriptions
                  .map(
                    (subscription) => _StatusRow(
                      label:
                          '${subscription['plan_code'] ?? '구독 플랜'} · ${_formatDateTime(subscription['expires_at'])}',
                      badge: _subscriptionStatusLabel(
                        (subscription['status'] ?? 'canceled').toString(),
                      ),
                      tone: _subscriptionStatusTone(
                        (subscription['status'] ?? 'canceled').toString(),
                      ),
                    ),
                  )
                  .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('최근 주문', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (orderWidgets.isEmpty)
                    Text('아직 주문 내역이 없습니다.',
                        style: Theme.of(context).textTheme.bodySmall)
                  else
                    ..._withVerticalSpacing(orderWidgets),
                  const SizedBox(height: 12),
                  Text('구독 상태', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (subscriptionWidgets.isEmpty)
                    Text('현재 활성 구독이 없습니다.',
                        style: Theme.of(context).textTheme.bodySmall)
                  else
                    ..._withVerticalSpacing(subscriptionWidgets),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: _refreshCommerceSummary,
                      child: const Text('새로고침'),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        PageSection(
          title: '정책 문서',
          child: Column(
            children: [
              _MenuRow(
                title: '이용약관',
                subtitle: '최종 업데이트: 2026-03-15',
                onTap: () =>
                    _openPolicy(PolicyDocumentType.terms, _termsPolicyUrl),
              ),
              const SizedBox(height: 8),
              _MenuRow(
                title: '개인정보 처리방침',
                subtitle: '최종 업데이트: 2026-03-15',
                onTap: () =>
                    _openPolicy(PolicyDocumentType.privacy, _privacyPolicyUrl),
              ),
              const SizedBox(height: 8),
              _MenuRow(
                title: '환불 정책',
                subtitle: '최종 업데이트: 2026-03-15',
                onTap: () =>
                    _openPolicy(PolicyDocumentType.refund, _refundPolicyUrl),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommerceSummary {
  const _CommerceSummary({required this.orders, required this.subscriptions});

  final List<Map<String, dynamic>> orders;
  final List<Map<String, dynamic>> subscriptions;
}

List<Widget> _withVerticalSpacing(List<Widget> children) {
  if (children.isEmpty) return const [];
  final widgets = <Widget>[];
  for (var i = 0; i < children.length; i++) {
    widgets.add(children[i]);
    if (i < children.length - 1) {
      widgets.add(const SizedBox(height: 8));
    }
  }
  return widgets;
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
  const _StatusRow(
      {required this.label, required this.badge, required this.tone});

  final String label;
  final String badge;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge)),
        StatusBadge(label: badge, tone: tone),
      ],
    );
  }
}
