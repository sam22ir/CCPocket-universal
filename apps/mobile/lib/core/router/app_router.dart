// ============================================================
// app_router.dart — Go Router Config (مع دعم المشاريع + ChatArgs)
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/sessions/presentation/sessions_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/chat/providers/chat_provider.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../core/services/storage_service.dart';

// ── Custom Page Transitions ──────────────────────────────────

CustomTransitionPage<T> _slideRight<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<T>(
      key:   state.pageKey,
      child: child,
      transitionsBuilder: (ctx, anim, _, ch) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end:   Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: ch,
      ),
      transitionDuration: const Duration(milliseconds: 320),
    );

CustomTransitionPage<T> _slideUp<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<T>(
      key:   state.pageKey,
      child: child,
      transitionsBuilder: (ctx, anim, _, ch) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.06),
          end:   Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim, child: ch),
      ),
      transitionDuration: const Duration(milliseconds: 300),
    );

CustomTransitionPage<T> _fade<T>(
  BuildContext context,
  GoRouterState state,
  Widget child,
) => CustomTransitionPage<T>(
      key:   state.pageKey,
      child: child,
      transitionsBuilder: (ctx, anim, _, ch) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
        child: ch,
      ),
      transitionDuration: const Duration(milliseconds: 250),
    );

// ── Router ───────────────────────────────────────────────────

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/projects',
    routes: [
      // ── الصفحة الرئيسية: قائمة المشاريع
      GoRoute(
        path: '/projects',
        pageBuilder: (ctx, state) => _fade(ctx, state, const ProjectsScreen()),
      ),

      // ── جلسات مشروع محدد
      GoRoute(
        path: '/projects/:projectId/sessions',
        pageBuilder: (ctx, state) {
          final extra = state.extra as StoredProject?;
          return _slideRight(ctx, state, SessionsScreen(
            projectId:   state.pathParameters['projectId']!,
            projectName: extra?.name ?? 'مشروع',
            projectPath: extra?.path ?? '',
          ));
        },
      ),

      // ── الجلسات العامة
      GoRoute(
        path: '/sessions',
        pageBuilder: (ctx, state) {
          final project = state.extra as StoredProject?;
          if (project != null) {
            return _slideRight(ctx, state, SessionsScreen(
              projectId:   project.id,
              projectName: project.name,
              projectPath: project.path,
            ));
          }
          return _slideRight(ctx, state, const SessionsScreen());
        },
      ),

      // ── شاشة المحادثة — extra = ChatArgs
      GoRoute(
        path: '/chat/:sessionId',
        pageBuilder: (ctx, state) {
          final extra = state.extra;
          if (extra is ChatArgs) {
            return _slideRight(ctx, state, ChatScreen(args: extra));
          }
          return _slideRight(ctx, state, ChatScreen(
            args: ChatArgs(sessionId: state.pathParameters['sessionId']!),
          ));
        },
      ),

      // ── الإعدادات
      GoRoute(
        path: '/settings',
        pageBuilder: (ctx, state) => _slideUp(ctx, state, const SettingsScreen()),
      ),
    ],
  );
});
