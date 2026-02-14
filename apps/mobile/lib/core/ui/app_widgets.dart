import 'package:flutter/material.dart';

import 'app_theme.dart';

class PageSection extends StatelessWidget {
  const PageSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    // Row는 non-flex child에게 가로 제약을 풀어주는데(=maxWidth Infinity),
                    // Material 버튼류는 무한 너비 제약에서 assert가 날 수 있다.
                    // trailing은 대부분 "자기 크기"로 그리면 되므로 IntrinsicWidth로 폭을 고정한다.
                    child: IntrinsicWidth(child: trailing!),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class StatusNotice extends StatelessWidget {
  const StatusNotice.error({super.key, required this.message, this.requestId}) : isError = true;

  const StatusNotice.warning({super.key, required this.message, this.requestId}) : isError = false;

  final String message;
  final String? requestId;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final tone = isError ? AppTheme.danger : AppTheme.warning;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: tone)),
          if (requestId != null && requestId!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('requestId: $requestId', style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

enum BadgeTone { neutral, success, warning, danger }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, this.tone = BadgeTone.neutral});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (textColor, bgColor, borderColor) = switch (tone) {
      BadgeTone.success => (const Color(0xFF096B52), const Color(0xFFE8F5F1), const Color(0xFFBFE2D8)),
      BadgeTone.warning => (const Color(0xFF8A5A00), const Color(0xFFFFF3DE), const Color(0xFFF0D3A2)),
      BadgeTone.danger => (const Color(0xFF9A3025), const Color(0xFFFCECEB), const Color(0xFFF3C4C1)),
      BadgeTone.neutral => (const Color(0xFF42514B), Colors.white, AppTheme.border),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textColor, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onAction,
  });

  final String title;
  final String description;
  final String actionText;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.inbox_outlined, size: 36),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: onAction, child: Text(actionText)),
          ],
        ),
      ),
    );
  }
}
