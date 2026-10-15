import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../domain/app_user.dart';
import 'phone_screen.dart';
import 'staff_login_screen.dart';

/// `/auth`: the sign-in of the surface. The phone and its Telegram code on
/// mobile; the staff sign-in on the web panel, which has no code.
class AuthEntryScreen extends ConsumerWidget {
  const AuthEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(surfaceProvider) == Surface.web
        ? const StaffLoginScreen()
        : const PhoneScreen();
  }
}
