import 'package:baraka_bozor/features/legal/domain/legal.dart';
import 'package:baraka_bozor/features/legal/domain/legal_text.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client copy of the server's `LegalText::blocks`: the same three cases
/// as `backend/tests/Unit/Legal/LegalTextTest.php`.
void main() {
  List<(LegalBlockType, String)> parse(String body) =>
      <(LegalBlockType, String)>[
        for (final LegalBlock block in legalBlocksOf(body))
          (block.type, block.text),
      ];

  test('blocks', () {
    expect(
      parse('## Цены\nЦены примерные.\n\n- Один\n- Два\r\nКонец'),
      <(LegalBlockType, String)>[
        (LegalBlockType.heading, 'Цены'),
        (LegalBlockType.paragraph, 'Цены примерные.'),
        (LegalBlockType.item, 'Один'),
        (LegalBlockType.item, 'Два'),
        (LegalBlockType.paragraph, 'Конец'),
      ],
    );
  });

  test('lines are trimmed and empty markers dropped', () {
    expect(parse('   Текст  \n\n##\n- \n   \n'), <(LegalBlockType, String)>[
      (LegalBlockType.paragraph, 'Текст'),
    ]);
  });

  test('markup stays literal text', () {
    expect(parse('<script>x</script>'), <(LegalBlockType, String)>[
      (LegalBlockType.paragraph, '<script>x</script>'),
    ]);
  });
}
