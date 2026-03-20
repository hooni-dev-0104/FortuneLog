import 'dart:io';

enum FindingSeverity { blocker, warning, pass }

class ReleaseFinding {
  const ReleaseFinding({
    required this.code,
    required this.severity,
    required this.summary,
    required this.file,
    required this.evidence,
    required this.recommendation,
  });

  final String code;
  final FindingSeverity severity;
  final String summary;
  final String file;
  final String evidence;
  final String recommendation;
}

class ReleaseAuditReport {
  const ReleaseAuditReport(this.findings);

  final List<ReleaseFinding> findings;

  List<ReleaseFinding> bySeverity(FindingSeverity severity) =>
      findings.where((finding) => finding.severity == severity).toList();

  int get blockerCount => bySeverity(FindingSeverity.blocker).length;
}

ReleaseAuditReport auditReleaseReadiness({String rootPath = '.'}) {
  final findings = <ReleaseFinding>[];

  String readFile(String relativePath) {
    final file = File('$rootPath/$relativePath');
    return file.readAsStringSync();
  }

  final androidGradle = readFile('android/app/build.gradle.kts');
  final iosProject = readFile('ios/Runner.xcodeproj/project.pbxproj');
  final myPage = readFile('lib/features/mypage/my_page.dart');
  final policyPage = readFile('lib/features/policy/policy_document_page.dart');
  final iosAppIconSet = File(
      '$rootPath/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png');
  final androidLauncherIcon =
      File('$rootPath/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png');

  if (RegExp(r'namespace\s*=\s*"com\.example\.').hasMatch(androidGradle)) {
    findings.add(
      const ReleaseFinding(
        code: 'android_namespace_placeholder',
        severity: FindingSeverity.blocker,
        summary: 'Android namespace still uses the Flutter sample placeholder.',
        file: 'apps/mobile/android/app/build.gradle.kts',
        evidence: 'namespace = "com.example.fortune_log_mobile"',
        recommendation:
            'Replace the namespace with the final FortuneLog Android package name before Play Store submission.',
      ),
    );
  }

  if (RegExp(r'applicationId\s*=\s*"com\.example\.').hasMatch(androidGradle)) {
    findings.add(
      const ReleaseFinding(
        code: 'android_application_id_placeholder',
        severity: FindingSeverity.blocker,
        summary:
            'Android applicationId still uses the Flutter sample placeholder.',
        file: 'apps/mobile/android/app/build.gradle.kts',
        evidence: 'applicationId = "com.example.fortune_log_mobile"',
        recommendation:
            'Replace the applicationId with the production Play Store package id.',
      ),
    );
  }

  if (androidGradle
      .contains('signingConfig = signingConfigs.getByName("debug")')) {
    findings.add(
      const ReleaseFinding(
        code: 'android_release_debug_signing',
        severity: FindingSeverity.blocker,
        summary: 'Android release builds still use the debug signing config.',
        file: 'apps/mobile/android/app/build.gradle.kts',
        evidence: 'signingConfig = signingConfigs.getByName("debug")',
        recommendation:
            'Wire a real release signing config (or CI-provided signing properties) before generating Play Store artifacts.',
      ),
    );
  }

  if (RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = com\.example\.')
      .hasMatch(iosProject)) {
    findings.add(
      const ReleaseFinding(
        code: 'ios_bundle_identifier_placeholder',
        severity: FindingSeverity.blocker,
        summary:
            'iOS bundle identifiers still use the Flutter sample placeholder.',
        file: 'apps/mobile/ios/Runner.xcodeproj/project.pbxproj',
        evidence: 'PRODUCT_BUNDLE_IDENTIFIER = com.example.fortuneLogMobile',
        recommendation:
            'Replace the Runner and test bundle identifiers with the final Apple app identifier prefix.',
      ),
    );
  }

  if (!iosProject.contains('DEVELOPMENT_TEAM =')) {
    findings.add(
      const ReleaseFinding(
        code: 'ios_development_team_missing',
        severity: FindingSeverity.blocker,
        summary:
            'iOS project does not declare a DEVELOPMENT_TEAM for code signing.',
        file: 'apps/mobile/ios/Runner.xcodeproj/project.pbxproj',
        evidence: 'No DEVELOPMENT_TEAM assignment found in project.pbxproj',
        recommendation:
            'Set the Apple Developer Team in the Runner target before archiving for App Store Connect.',
      ),
    );
  }

  final hasPolicyUrls = myPage.contains('https://fortunelog.app/terms') &&
      myPage.contains('https://fortunelog.app/privacy') &&
      myPage.contains('https://fortunelog.app/refund');
  if (hasPolicyUrls) {
    findings.add(
      const ReleaseFinding(
        code: 'policy_urls_present',
        severity: FindingSeverity.pass,
        summary:
            'Terms, privacy, and refund URLs are wired in the mobile settings surface.',
        file: 'apps/mobile/lib/features/mypage/my_page.dart',
        evidence:
            'POLICY_TERMS_URL / POLICY_PRIVACY_URL / POLICY_REFUND_URL default to fortunelog.app',
        recommendation:
            'Keep the hosted policy pages live and in sync with store metadata.',
      ),
    );
  } else {
    findings.add(
      const ReleaseFinding(
        code: 'policy_urls_missing',
        severity: FindingSeverity.blocker,
        summary:
            'Policy URLs are not fully wired for the mobile settings surface.',
        file: 'apps/mobile/lib/features/mypage/my_page.dart',
        evidence:
            'Expected fortunelog.app terms/privacy/refund URLs were not found together.',
        recommendation:
            'Expose the final hosted terms, privacy, and refund URLs before store review.',
      ),
    );
  }

  if (iosAppIconSet.existsSync() && androidLauncherIcon.existsSync()) {
    findings.add(
      const ReleaseFinding(
        code: 'store_icons_present',
        severity: FindingSeverity.pass,
        summary:
            'Primary Android/iOS launcher assets are present for store packaging.',
        file:
            'apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png',
        evidence:
            'iOS 1024x1024 icon and Android launcher mipmap assets exist in the repo.',
        recommendation:
            'Verify the final artwork matches brand guidelines before uploading store listings.',
      ),
    );
  }

  final supportPattern = RegExp(
    r'''(support@|help@|contact@|mailto:|https?://[^\s'"]*(support|help|contact)[^\s'"]*)''',
    caseSensitive: false,
  );
  final supportSurfacePresent =
      supportPattern.hasMatch(policyPage) || supportPattern.hasMatch(myPage);
  if (!supportSurfacePresent) {
    findings.add(
      const ReleaseFinding(
        code: 'support_contact_missing',
        severity: FindingSeverity.warning,
        summary:
            'The mobile settings/policy surfaces do not expose a concrete support email or support URL.',
        file: 'apps/mobile/lib/features/mypage/my_page.dart',
        evidence:
            'Policy copy references a customer inquiry channel, but no concrete support URL/email is surfaced in MyPage or PolicyDocumentPage.',
        recommendation:
            'Add the real support URL/email to app settings and mirror it in App Store Connect / Play Console listing metadata.',
      ),
    );
  }

  return ReleaseAuditReport(findings);
}

String _severityLabel(FindingSeverity severity) {
  switch (severity) {
    case FindingSeverity.blocker:
      return 'BLOCKER';
    case FindingSeverity.warning:
      return 'WARNING';
    case FindingSeverity.pass:
      return 'PASS';
  }
}

void main(List<String> args) {
  final strict = args.contains('--strict');
  final report = auditReleaseReadiness();

  stdout.writeln('FortuneLog mobile release readiness audit');
  stdout.writeln('Root: ${Directory.current.path}');
  stdout.writeln('');

  for (final severity in FindingSeverity.values) {
    final section = report.bySeverity(severity);
    if (section.isEmpty) {
      continue;
    }
    stdout.writeln('${_severityLabel(severity)} (${section.length})');
    for (final finding in section) {
      stdout.writeln('- [${finding.code}] ${finding.summary}');
      stdout.writeln('  file: ${finding.file}');
      stdout.writeln('  evidence: ${finding.evidence}');
      stdout.writeln('  next: ${finding.recommendation}');
    }
    stdout.writeln('');
  }

  if (strict && report.blockerCount > 0) {
    exitCode = 1;
  }
}
