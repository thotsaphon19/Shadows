// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'theme/app_theme.dart';
import 'pages/login_page.dart';
import 'services/app_image_service.dart';
import 'services/cloudflare_r2_service.dart';
import 'services/tts_service.dart';
import 'pages/home_page.dart';
import 'pages/lessons_page.dart';
import 'pages/lesson_content_page.dart';
import 'pages/tutor_selection_page.dart';
import 'pages/practice_page.dart';
import 'pages/leaderboard_page.dart';
import 'pages/premium_page.dart';
import 'pages/profile_page.dart';
import 'pages/avatar_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  await Firebase.initializeApp();
  await AppImageService.init();
  await R2Service.init();
  await TtsService.init();
  runApp(const ShadowsApp());
}

class ShadowsApp extends StatelessWidget {
  const ShadowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shadows by yannawut',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _AuthGate(),
      onGenerateRoute: _generateRoute,
    );
  }

  Route<dynamic>? _generateRoute(RouteSettings s) {
    switch (s.name) {
      case '/login':
        return _slide(const LoginPage());
      case '/home':
        return _slide(const HomePage());
      case '/lessons':
        final a = s.arguments as Map<String, dynamic>?;
        return _slide(LessonsPage(
          languageId: a?['languageId'] ?? 'English',
          tutorId:    a?['tutorId']    ?? '',
        ));
      case '/tutors':
        final a = s.arguments as Map<String, dynamic>?;
        return _slide(TutorSelectionPage(
          languageId: a?['languageId'] ?? 'English',
        ));
      case '/lesson-content':
        final a = s.arguments as Map<String, dynamic>? ?? {};
        return _slide(LessonContentPage(
          category:     a['category']   as String? ?? '',
          categoryIcon: a['icon']       as String? ?? '📚',
          languageId:   a['languageId'] as String? ?? 'English',
          tutorId:      a['tutorId']    as String? ?? '',
          wordCount:    a['wordCount']  as int?    ?? 50,
        ));
      case '/practice':
        final a = s.arguments as Map<String, dynamic>? ?? {};
        return _slide(PracticePage(
          tutorId:    a['tutorId']    as String? ?? 'tutor_01',
          lessonId:   a['lessonId']   as String? ?? 'lesson_01',
          languageId: a['languageId'] as String? ?? 'English',
          lessonText: a['lessonText'] as String? ?? '',
        ));
      case '/leaderboard':
        final a = s.arguments as Map<String, dynamic>?;
        return _slide(LeaderboardPage(languageId: a?['languageId'] ?? 'English'));
      case '/premium':
        return _slide(const PremiumPage());
      case '/profile':
        return _slide(const ProfilePage());
      case '/avatar':
        return _slide(const AvatarPage());
      default:
        return _slide(const _AuthGate());
    }
  }

  PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, anim, __, child) =>
      SlideTransition(position: Tween(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)), child: child),
    transitionDuration: const Duration(milliseconds: 260),
  );
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ));
        }
        return snap.hasData ? const HomePage() : const LoginPage();
      },
    );
  }
}
