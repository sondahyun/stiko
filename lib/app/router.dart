import 'package:go_router/go_router.dart';

import '../features/settings/presentation/settings_screen.dart';
import '../features/todos/presentation/todo_list_screen.dart';

/// Named route paths used across the app.
class StikoRoutes {
  const StikoRoutes._();

  static const String home = '/';
  static const String settings = '/settings';
}

/// Top-level router configuration.
final GoRouter appRouter = GoRouter(
  initialLocation: StikoRoutes.home,
  routes: <RouteBase>[
    GoRoute(
      path: StikoRoutes.home,
      builder: (context, state) => const TodoListScreen(),
    ),
    GoRoute(
      path: StikoRoutes.settings,
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
