import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bizil/main.dart';
import 'package:bizil/services/ai_service.dart';
import 'package:bizil/services/voice_service.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MyApp(
        aiService: AiService(),
        voiceService: VoiceService(),
      ),
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
