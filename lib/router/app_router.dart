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
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/team_management_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isGoingToLoginOrSignup = state.matchedLocation == '/login' || state.matchedLocation == '/signup';

    if (!isLoggedIn && !isGoingToLoginOrSignup) {
      return '/login';
    }
    if (isLoggedIn && isGoingToLoginOrSignup) {
      return '/dashboard';
    }
    if (isLoggedIn && state.matchedLocation == '/') {
      return '/dashboard';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
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
    GoRoute(
      path: '/team_management',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TeamManagementScreen(),
    ),
  ],
);
