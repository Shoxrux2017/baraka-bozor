import 'dart:async';

import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/brand_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_auth_repository.dart';
import '../support/in_memory_stores.dart';

void main() {
  testWidgets('a session that never resolves shows the wordmark on white, '
      'no spinner before 1.5 s', (WidgetTester tester) async {
    final FakeAuthRepository repository = FakeAuthRepository()
      ..identities[SessionSlot.customer] = user()
      ..holdAnswers = Completer<void>();
    await tester.pumpWidget(
      appUnderTest(
        tokens: InMemoryTokenStore(<SessionSlot, String>{
          SessionSlot.customer: 'c',
        }),
        repository: repository,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    // The page under the curtain is plain white; the wordmark is the curtain's.
    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('BarakaBozor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
    expect(
      tester
          .widget<Material>(
            find.descendant(
              of: find.byKey(const ValueKey<String>('launch-curtain')),
              matching: find.byType(Material),
            ),
          )
          .color,
      Colors.white,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
