import 'package:flutter_test/flutter_test.dart';

import 'package:time_tracker/main.dart';

void main() {
  testWidgets('App builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const FieldClockApp());
    await tester.pump();
  });
}
