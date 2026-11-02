import 'package:baraka_bozor/core/widgets/product_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fadeIn fades a picture that loads later', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: <Widget>[
            ProductImage(url: 'https://x.test/a.webp', size: 80, fadeIn: true),
            ProductImage(url: 'https://x.test/b.webp', size: 80),
          ],
        ),
      ),
    );
    final List<Image> images = tester
        .widgetList<Image>(find.byType(Image))
        .toList();
    final BuildContext context = tester.element(
      find.byType(ProductImage).first,
    );
    const Widget child = SizedBox();

    // Without fadeIn there is no frame builder.
    expect(images[1].frameBuilder, isNull);

    final ImageFrameBuilder build = images[0].frameBuilder!;
    expect(build(context, child, null, false), isA<AnimatedOpacity>());
    expect((build(context, child, null, false) as AnimatedOpacity).opacity, 0);
    final AnimatedOpacity shown =
        build(context, child, 0, false) as AnimatedOpacity;
    expect(shown.opacity, 1);
    expect(shown.duration, const Duration(milliseconds: 250));
    expect(shown.curve, Curves.easeOut);
    // A picture that was there at once is not faded.
    expect(build(context, child, 0, true), same(child));
  });
}
