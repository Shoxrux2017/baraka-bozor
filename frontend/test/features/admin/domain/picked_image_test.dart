import 'dart:typed_data';

import 'package:baraka_bozor/features/admin/domain/admin_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// `BR-CAT-004`: JPEG, PNG or WebP judged by the bytes, at most 5 MiB.
void main() {
  PickedImage image(List<int> head, {int size = 0}) {
    final Uint8List bytes = Uint8List(size > head.length ? size : head.length)
      ..setRange(0, head.length, head);
    return PickedImage(bytes: bytes, name: 'photo.bin');
  }

  test('the three accepted kinds are recognised by their first bytes', () {
    expect(image(<int>[0xFF, 0xD8, 0xFF, 0xE0]).looksLikeAcceptedImage, isTrue);
    expect(
      image(<int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
          .looksLikeAcceptedImage,
      isTrue,
    );
    expect(
      image(<int>[0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])
          .looksLikeAcceptedImage,
      isTrue,
    );
  });

  test('anything else is not, whatever the file is called', () {
    expect(
      image(<int>[0x47, 0x49, 0x46, 0x38, 0x39, 0x61]).looksLikeAcceptedImage,
      isFalse,
    );
    expect(
      image(<int>[0x25, 0x50, 0x44, 0x46]).looksLikeAcceptedImage,
      isFalse,
    );
    expect(
      image(<int>[0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x41, 0x56, 0x49, 0x20])
          .looksLikeAcceptedImage,
      isFalse,
    );
    expect(image(<int>[0xFF]).looksLikeAcceptedImage, isFalse);
    expect(
      PickedImage(
        bytes: Uint8List(0),
        name: 'empty.png',
      ).looksLikeAcceptedImage,
      isFalse,
    );
  });

  test('5 MiB is the limit, counted in bytes', () {
    expect(
      image(<int>[0xFF, 0xD8, 0xFF], size: PickedImage.maxBytes).isTooLarge,
      isFalse,
    );
    expect(
      image(<int>[0xFF, 0xD8, 0xFF], size: PickedImage.maxBytes + 1).isTooLarge,
      isTrue,
    );
  });
}
