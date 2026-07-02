import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

class PageSection extends StatelessWidget {
  const PageSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
    this.showHeader = true,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      // Row는 non-flex child에게 가로 제약을 풀어주는데(=maxWidth Infinity),
                      // Material 버튼류는 무한 너비 제약에서 assert가 날 수 있다.
                      // trailing은 대부분 "자기 크기"로 그리면 되므로 버튼 최소 폭을 compact하게 덮어쓴다.
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          filledButtonTheme: FilledButtonThemeData(
                            style: FilledButton.styleFrom(
                              minimumSize:
                                  const Size(0, AppTheme.controlHeightSmall),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          outlinedButtonTheme: OutlinedButtonThemeData(
                            style: OutlinedButton.styleFrom(
                              minimumSize:
                                  const Size(0, AppTheme.controlHeightSmall),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ),
                        child: IntrinsicWidth(child: trailing!),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class AppBottomActionBar extends StatelessWidget {
  const AppBottomActionBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppTheme.pagePadding,
      10,
      AppTheme.pagePadding,
      16,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: EdgeInsets.zero,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.surfaceRaised,
          border: Border(top: BorderSide(color: AppTheme.border)),
        ),
        child: Padding(
          padding: padding,
          child: child,
        ),
      ),
    );
  }
}

enum NoticeTone { error, warning, info, success }

class StatusNotice extends StatelessWidget {
  const StatusNotice.error({super.key, required this.message, this.requestId})
      : tone = NoticeTone.error;

  const StatusNotice.warning({super.key, required this.message, this.requestId})
      : tone = NoticeTone.warning;

  const StatusNotice.info({super.key, required this.message, this.requestId})
      : tone = NoticeTone.info;

  const StatusNotice.success({super.key, required this.message, this.requestId})
      : tone = NoticeTone.success;

  final String message;
  final String? requestId;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (tone) {
      NoticeTone.error => (AppTheme.dangerStrong, Icons.error_outline, '오류'),
      NoticeTone.warning => (
          AppTheme.warningStrong,
          Icons.warning_amber_rounded,
          '주의'
        ),
      NoticeTone.info => (AppTheme.info, Icons.info_outline, '안내'),
      NoticeTone.success => (
          AppTheme.success,
          Icons.check_circle_outline,
          '완료'
        ),
    };
    final showDebugIds =
        kDebugMode && const bool.fromEnvironment('SHOW_DEBUG_IDS');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: color)),
          if (showDebugIds && requestId != null && requestId!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('요청 ID: $requestId',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

enum BadgeTone { neutral, success, warning, danger, info, brand }

class StatusBadge extends StatelessWidget {
  const StatusBadge(
      {super.key, required this.label, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = switch (tone) {
      BadgeTone.success => (
          AppTheme.success,
          AppTheme.successFill,
          AppTheme.successBorder
        ),
      BadgeTone.warning => (
          AppTheme.warning,
          AppTheme.warningFill,
          AppTheme.warningBorder
        ),
      BadgeTone.danger => (
          AppTheme.danger,
          AppTheme.dangerFill,
          AppTheme.dangerBorder
        ),
      BadgeTone.info => (AppTheme.info, AppTheme.infoFill, AppTheme.infoBorder),
      BadgeTone.brand => (
          AppTheme.onBrandTint,
          AppTheme.brandTint,
          AppTheme.brandTintLine
        ),
      BadgeTone.neutral => (
          AppTheme.neutral,
          AppTheme.neutralFill,
          AppTheme.neutralBorder
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AppMiniChip extends StatelessWidget {
  const AppMiniChip(
      {super.key, required this.label, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = switch (tone) {
      BadgeTone.success => (
          AppTheme.success,
          AppTheme.successFill,
          AppTheme.successBorder
        ),
      BadgeTone.warning => (
          AppTheme.warning,
          AppTheme.warningFill,
          AppTheme.warningBorder
        ),
      BadgeTone.danger => (
          AppTheme.danger,
          AppTheme.dangerFill,
          AppTheme.dangerBorder
        ),
      BadgeTone.info => (AppTheme.info, AppTheme.infoFill, AppTheme.infoBorder),
      BadgeTone.brand => (
          AppTheme.onBrandTint,
          AppTheme.brandTint,
          AppTheme.brandTintLine
        ),
      BadgeTone.neutral => (
          AppTheme.textStrong,
          AppTheme.surfaceRaised,
          AppTheme.border
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: borderColor),
        color: bgColor,
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: textColor)),
    );
  }
}

class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.title,
    required this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leadingIcon != null) ...[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppTheme.brandTint,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(color: AppTheme.brandTintLine),
                ),
                child: Icon(
                  leadingIcon,
                  size: 18,
                  color: AppTheme.onBrandTint,
                ),
              ),
              const SizedBox(width: 10),
            ],
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
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ] else if (onTap != null) ...[
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: AppTheme.textWeak),
            ],
          ],
        ),
      ),
    );
  }
}

class AppKeyValueTable extends StatelessWidget {
  const AppKeyValueTable({
    super.key,
    required this.firstHeader,
    required this.secondHeader,
    required this.rows,
    this.firstColumnWidth = 86,
  });

  final String firstHeader;
  final String secondHeader;
  final List<(String, String)> rows;
  final double firstColumnWidth;

  TableRow _row(
    BuildContext context, {
    required String left,
    required String right,
    bool header = false,
  }) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontWeight: header ? FontWeight.w700 : FontWeight.w500,
          color: header ? AppTheme.textStrong : AppTheme.textWeak,
        );

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(left, style: style),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          child: Text(right, style: style),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.border),
          color: AppTheme.surfaceRaised,
        ),
        child: Table(
          columnWidths: {
            0: FixedColumnWidth(firstColumnWidth),
            1: const FlexColumnWidth(),
          },
          border: const TableBorder(
            horizontalInside: BorderSide(color: AppTheme.border),
            verticalInside: BorderSide(color: AppTheme.border),
          ),
          children: [
            _row(context, left: firstHeader, right: secondHeader, header: true),
            for (final row in rows) _row(context, left: row.$1, right: row.$2),
          ],
        ),
      ),
    );
  }
}

enum AppListMarker { bullet, check, number }

class AppTextList extends StatelessWidget {
  const AppTextList({
    super.key,
    required this.items,
    this.marker = AppListMarker.bullet,
    this.emptyText = '표시할 정보가 없습니다.',
  });

  final List<String> items;
  final AppListMarker marker;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyText, style: Theme.of(context).textTheme.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _AppTextListItem(
            text: items[i],
            marker: marker,
            number: i + 1,
          ),
          if (i < items.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _AppTextListItem extends StatelessWidget {
  const _AppTextListItem({
    required this.text,
    required this.marker,
    required this.number,
  });

  final String text;
  final AppListMarker marker;
  final int number;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    final markerWidget = switch (marker) {
      AppListMarker.check => const Icon(
          Icons.check_circle_outline,
          size: 16,
          color: AppTheme.onBrandTint,
        ),
      AppListMarker.number => SizedBox(
          width: 20,
          child: Text(
            '$number.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.onBrandTint,
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      AppListMarker.bullet => Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.onBrandTint,
            shape: BoxShape.circle,
          ),
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: marker == AppListMarker.bullet ? 9 : 3),
          child: markerWidget,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: textStyle)),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    this.actionText,
    this.onAction,
    this.icon = Icons.inbox_outlined,
    this.tone = BadgeTone.neutral,
  });

  final String title;
  final String description;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData icon;
  final BadgeTone tone;

  (Color, Color) _toneColors() {
    return switch (tone) {
      BadgeTone.success => (AppTheme.success, AppTheme.successFill),
      BadgeTone.warning => (AppTheme.warning, AppTheme.warningFill),
      BadgeTone.danger => (AppTheme.danger, AppTheme.dangerFill),
      BadgeTone.info => (AppTheme.info, AppTheme.infoFill),
      BadgeTone.brand => (AppTheme.onBrandTint, AppTheme.brandTint),
      BadgeTone.neutral => (AppTheme.neutral, AppTheme.surfaceRaised),
    };
  }

  @override
  Widget build(BuildContext context) {
    final (iconColor, iconBg) = _toneColors();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(AppTheme.radius2xl),
                border: Border.all(color: AppTheme.border),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center),
            if (actionText != null) ...[
              const SizedBox(height: 14),
              FilledButton(onPressed: onAction, child: Text(actionText!)),
            ],
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.textStrong,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      duration: const Duration(seconds: 2),
    ),
  );
}

class PageLoading extends StatelessWidget {
  const PageLoading({super.key, this.title = '불러오는 중', this.message});

  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (message != null && message!.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppSkeleton extends StatelessWidget {
  const AppSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = AppTheme.radiusXl,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.skeleton,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ScoreDonut extends StatelessWidget {
  const ScoreDonut({
    super.key,
    required this.score,
    this.size = 120,
    this.label,
    this.caption,
    this.tone = BadgeTone.brand,
  });

  final int score;
  final double size;
  final String? label;
  final String? caption;
  final BadgeTone tone;

  Color _arcColor() {
    return switch (tone) {
      BadgeTone.success => AppTheme.success,
      BadgeTone.warning => AppTheme.warningStrong,
      BadgeTone.danger => AppTheme.dangerStrong,
      BadgeTone.info => AppTheme.info,
      BadgeTone.neutral => AppTheme.neutral,
      BadgeTone.brand => AppTheme.brand,
    };
  }

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(size),
                painter: _ScoreDonutPainter(
                  progress: clamped / 100,
                  color: _arcColor(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$clamped',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w800, height: 1),
                  ),
                  Text('점',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!, style: Theme.of(context).textTheme.labelLarge),
        ],
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(caption!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _ScoreDonutPainter extends CustomPainter {
  const _ScoreDonutPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 11.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.surfaceSunken;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreDonutPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

class CategoryScoreRow extends StatelessWidget {
  const CategoryScoreRow({
    super.key,
    required this.icon,
    required this.label,
    required this.score,
    this.summary,
  });

  final IconData icon;
  final String label;
  final int score;
  final String? summary;

  Color _scoreColor() {
    if (score >= 75) return AppTheme.elementWood;
    if (score >= 50) return AppTheme.gold;
    if (score >= 30) return AppTheme.warningStrong;
    return AppTheme.dangerStrong;
  }

  @override
  Widget build(BuildContext context) {
    final clamped = score.clamp(0, 100);
    final tone = _scoreColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.brandTint,
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: AppTheme.onBrandTint, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontSize: 15),
              ),
            ),
            Text(
              '$clamped',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: tone, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            Text('점',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.textFaint)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 6,
            backgroundColor: AppTheme.surfaceSunken,
            valueColor: AlwaysStoppedAnimation<Color>(tone),
          ),
        ),
        if (summary != null && summary!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(summary!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }
}

class CategoryInsightSection extends StatelessWidget {
  const CategoryInsightSection({
    super.key,
    required this.label,
    required this.icon,
    required this.score,
    this.summary,
    this.good = const [],
    this.cautions = const [],
    this.actions = const [],
  });

  final String label;
  final IconData icon;
  final int score;
  final String? summary;
  final List<String> good;
  final List<String> cautions;
  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return PageSection(
      title: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CategoryScoreRow(
            icon: icon,
            label: label,
            score: score,
            summary: summary,
          ),
          if (good.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('좋은 흐름', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            AppTextList(items: good),
          ],
          if (cautions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('주의 포인트', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            AppTextList(items: cautions),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('추천 행동', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            AppTextList(items: actions, marker: AppListMarker.check),
          ],
        ],
      ),
    );
  }
}

class ElementDistributionBar extends StatelessWidget {
  const ElementDistributionBar({super.key, required this.counts});

  final Map<String, int> counts;

  static const _order = [
    ('wood', '목'),
    ('fire', '화'),
    ('earth', '토'),
    ('metal', '금'),
    ('water', '수'),
  ];

  @override
  Widget build(BuildContext context) {
    final largestValue = _order
        .map((item) => counts[item.$1] ?? 0)
        .fold<int>(0, (largest, value) => value > largest ? value : largest);
    final maxValue = largestValue < 1 ? 1 : largestValue;
    return Column(
      children: [
        for (final item in _order) ...[
          _ElementDistributionRow(
            elementKey: item.$1,
            label: item.$2,
            value: counts[item.$1] ?? 0,
            maxValue: maxValue,
          ),
          if (item != _order.last) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class ElementGlyphTile extends StatelessWidget {
  const ElementGlyphTile({
    super.key,
    required this.primaryText,
    this.secondaryText,
    this.elementKey,
    this.height,
    this.aspectRatio = 1,
    this.radius = AppTheme.radiusMd,
    this.primaryTextStyle,
    this.showElementLabel = true,
  });

  final String primaryText;
  final String? secondaryText;
  final String? elementKey;
  final double? height;
  final double aspectRatio;
  final double radius;
  final TextStyle? primaryTextStyle;
  final bool showElementLabel;

  @override
  Widget build(BuildContext context) {
    final bg = elementKey == null
        ? AppTheme.surfaceSunken
        : AppTheme.elementColor(elementKey!);
    final border = elementKey == null ? AppTheme.border : Colors.transparent;
    final fg = ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : AppTheme.textStrong;
    final elementLabel =
        elementKey == null ? null : AppTheme.elementLabel(elementKey!);

    final tile = Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              primaryText,
              textAlign: TextAlign.center,
              style: (primaryTextStyle ??
                      Theme.of(context).textTheme.headlineSmall)
                  ?.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
          if (secondaryText != null && secondaryText!.trim().isNotEmpty)
            Positioned(
              left: 8,
              bottom: 6,
              child: Text(
                secondaryText!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: fg.withValues(alpha: 0.92)),
              ),
            ),
          if (showElementLabel &&
              elementLabel != null &&
              elementLabel.trim().isNotEmpty)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceRaised.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  border: Border.all(
                    color: AppTheme.surfaceRaised.withValues(alpha: 0.38),
                  ),
                ),
                child: Text(
                  elementLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                ),
              ),
            ),
        ],
      ),
    );

    if (height != null) return tile;
    return AspectRatio(aspectRatio: aspectRatio, child: tile);
  }
}

class _ElementDistributionRow extends StatelessWidget {
  const _ElementDistributionRow({
    required this.elementKey,
    required this.label,
    required this.value,
    required this.maxValue,
  });

  final String elementKey;
  final String label;
  final int value;
  final int maxValue;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.elementColor(elementKey);
    final onColor =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? Colors.white
            : AppTheme.textStrong;
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: onColor, fontSize: 14)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(label,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textStrong))),
                  Text('$value',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                child: LinearProgressIndicator(
                  value: value / maxValue,
                  minHeight: 8,
                  backgroundColor: AppTheme.surfaceSunken,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
