import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanis/widgets/reset_account_page.dart';
import 'package:liblanis/liblanis.dart';

import '../helpers/test_app.dart';

const _account = ClearTextAccount(
  localId: 1,
  schoolID: 1,
  username: 'u',
  password: 'p',
  schoolName: 'Test',
);

void main() {
  tearDown(LanisClient.reset);

  testWidgets('password dialog shows the saved username as read-only', (
    tester,
  ) async {
    await pumpTestApp(
      tester,
      child: const ResetAccountPage(account: _account),
    );
    await tester.tap(find.widgetWithIcon(ElevatedButton, Icons.password));
    await tester.pumpAndSettle();

    final fields = tester
        .widgetList<EditableText>(
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.byType(EditableText),
          ),
        )
        .toList();
    expect(fields, hasLength(2));
    expect(fields.first.readOnly, isTrue);
    expect(fields.first.controller.text, 'u');
    expect(fields.last.obscureText, isTrue);
    expect(fields.last.controller.text, isEmpty);
  });

}
