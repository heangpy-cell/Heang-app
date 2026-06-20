import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:link_grab/main.dart';
import 'package:link_grab/providers/download_provider.dart';

void main() {
  testWidgets('LinkGrab app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => DownloadProvider(),
        child: const LinkGrabApp(),
      ),
    );
    expect(find.text('LINK GRAB'), findsOneWidget);
  });
}
