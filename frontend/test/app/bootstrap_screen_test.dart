import 'dart:async';

import 'package:baraka_bozor/core/storage/token_store.dart';
import 'package:baraka_bozor/core/widgets/brand_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_auth_repository.dart';
import '../support/in_memory_stores.dart';

void main() {
  testWidgets('a session that never resolves shows the wordmark, no spinner', (
    WidgetTester tester,
  ) async {
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

    expect(find.byType(BrandWordmark), findsOneWidget);
    expect(find.text('BarakaBozor'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      Colors.white,
    );
  });
}
