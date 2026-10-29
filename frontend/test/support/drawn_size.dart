import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The size of the part of a button that is drawn: the first [Material] below
/// [button]. A button with padded tap targets is laid out larger than that
/// (DL-117), so a test of the drawing reads it here.
Size drawnSize(WidgetTester tester, Finder button) => tester.getSize(
  find.descendant(of: button, matching: find.byType(Material)).first,
);
