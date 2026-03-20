import 'package:flutter_test/flutter_test.dart';

import '../../tool/release_readiness_audit.dart';

void main() {
  test('audit captures current release blockers and ready signals', () {
    final report = auditReleaseReadiness(rootPath: '.');
    final blockerCodes =
        report.bySeverity(FindingSeverity.blocker).map((it) => it.code).toSet();
    final warningCodes =
        report.bySeverity(FindingSeverity.warning).map((it) => it.code).toSet();
    final passCodes =
        report.bySeverity(FindingSeverity.pass).map((it) => it.code).toSet();

    expect(
      blockerCodes,
      containsAll(<String>{
        'ios_development_team_missing',
      }),
    );
    expect(warningCodes, contains('support_contact_missing'));
    expect(
      passCodes,
      containsAll(<String>{'policy_urls_present', 'store_icons_present'}),
    );
  });
}
