import 'package:go_router/go_router.dart';

import 'package:meu_app_android/features/auth/screens/login_screen.dart';

final appRouter = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);