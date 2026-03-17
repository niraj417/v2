import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/lead_model.dart';
import '../screens/dashboard_screen.dart';
import '../screens/lead_generator_screen.dart';
import '../screens/leads_list_screen.dart';
import '../screens/pipeline_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/main_layout.dart';
import '../screens/lead_details_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainLayout(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/generate',
              builder: (context, state) => const LeadGeneratorScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/leads',
              builder: (context, state) => const LeadsListScreen(),
              routes: [
                GoRoute(
                  path: 'details',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) => LeadDetailsScreen(lead: state.extra as Lead),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/pipeline',
              builder: (context, state) => const PipelineScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
    // Added a global route alternative just in case we route from pipeline directly
    GoRoute(
      path: '/lead_details',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => LeadDetailsScreen(lead: state.extra as Lead),
    ),
  ],
);
