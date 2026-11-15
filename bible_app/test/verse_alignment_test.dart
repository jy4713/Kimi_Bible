import 'package:bible_app/models/verse.dart';
import 'package:bible_app/providers/settings_provider.dart';
import 'package:bible_app/screens/bible/verse_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fontSize in [10.0, 16.0, 24.0, 32.0]) {
    for (final systemScale in [1.0, 1.4]) {
      testWidgets('절 번호와 본문 정렬: $fontSize, 배율 $systemScale', (tester) async {
        const body = '태초에 하나님이 천지를 창조하시니라';
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(600, 800),
              textScaler: TextScaler.linear(systemScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: ChangeNotifierProvider.value(
                  value: SettingsProvider(),
                  child: VerseListView(
                    fontSize: fontSize,
                    verses: const [
                      Verse(
                        id: 1,
                        book: 1,
                        chapter: 1,
                        verse: 1,
                        text: body,
                        translationId: 'test',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final number = tester.widget<Text>(find.text('1'));
        final text = tester.widget<Text>(find.text(body));
        expect(number.style?.fontSize, fontSize);
        expect(text.style?.fontSize, fontSize);
        expect(number.style?.height, text.style?.height);
        expect(
          tester.getTopLeft(find.text('1')).dy,
          closeTo(tester.getTopLeft(find.text(body)).dy, 0.01),
        );
        final numberBaseline = tester
            .renderObject<RenderParagraph>(find.text('1'))
            .computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final bodyBaseline = tester
            .renderObject<RenderParagraph>(find.text(body))
            .computeDistanceToActualBaseline(TextBaseline.alphabetic);
        expect(numberBaseline, closeTo(bodyBaseline, 0.01));
      });
    }
  }

  for (final fontSize in [10.0, 16.0, 24.0, 32.0]) {
    for (final systemScale in [1.0, 1.4]) {
      testWidgets('Strong 본문 배율과 정렬: $fontSize, 배율 $systemScale',
          (tester) async {
        const body = '태초에 하나님이 천지를 창조하시니라';
        const raw = '태초에 하나님 <WH430> 천지를 창조하시니라';
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(600, 800),
              textScaler: TextScaler.linear(systemScale),
            ),
            child: MaterialApp(
              home: Scaffold(
                body: ChangeNotifierProvider.value(
                  value: SettingsProvider(),
                  child: VerseListView(
                    fontSize: fontSize,
                    verses: const [
                      Verse(
                        id: 1,
                        book: 1,
                        chapter: 1,
                        verse: 1,
                        text: body,
                        rawText: raw,
                        translationId: 'test',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final richFinder = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains('태초에') &&
              widget.text.toPlainText().contains('창조하시니라'),
        );
        final rich = tester.widget<RichText>(richFinder);
        expect(rich.textScaler, TextScaler.linear(systemScale));
        expect(
          tester.getTopLeft(find.text('1')).dy,
          closeTo(tester.getTopLeft(richFinder).dy, 0.01),
        );
        final numberBaseline = tester
            .renderObject<RenderParagraph>(find.text('1'))
            .computeDistanceToActualBaseline(TextBaseline.alphabetic);
        final bodyBaseline = tester
            .renderObject<RenderParagraph>(richFinder)
            .computeDistanceToActualBaseline(TextBaseline.alphabetic);
        expect(numberBaseline, isNotNull);
        expect(bodyBaseline, isNotNull);
        expect(numberBaseline, closeTo(bodyBaseline!, 0.01));
      });
    }
  }
}
