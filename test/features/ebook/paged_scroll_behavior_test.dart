import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:steeped/features/ebook/epub_reader_screen.dart';

Widget _host({required bool paged, required ScrollController controller}) =>
    MaterialApp(
      home: ScrollConfiguration(
        behavior: PagedScrollBehavior(paged: paged),
        child: ListView(
          controller: controller,
          children: [
            for (var i = 0; i < 60; i++)
              SizedBox(height: 80, child: Text('row $i')),
          ],
        ),
      ),
    );

void main() {
  testWidgets('switching Pages/Scroll takes effect without remounting', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(_host(paged: true, controller: controller));

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.offset, 0, reason: 'paged mode blocks finger scrolling');

    await tester.pumpWidget(_host(paged: false, controller: controller));
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));

    await tester.pumpWidget(_host(paged: true, controller: controller));
    final before = controller.offset;
    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(controller.offset, before);
  });
}
