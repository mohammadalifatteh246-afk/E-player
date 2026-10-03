import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('App loads smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EPlayerApp());

    // Verify that the title 'E-Player' appears.
    expect(find.text('E-Player'), findsOneWidget);
  });
}
