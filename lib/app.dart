import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'app_environment.dart';
import 'app_scope.dart';
import 'screens/login_screen.dart';

class SignageMobileApp extends StatelessWidget {
  const SignageMobileApp({
    super.key,
    this.environment,
    this.dependencies,
  });

  final AppEnvironment? environment;
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    const seedColor = Color(0xFF24C3B0);
    const navy = Color(0xFF27364A);
    final resolvedEnvironment = environment ?? AppEnvironment.current;
    final resolvedDependencies =
        dependencies ?? AppDependencies.fromEnvironment(resolvedEnvironment);

    return AppScope(
      environment: resolvedEnvironment,
      authService: resolvedDependencies.authService,
      contentService: resolvedDependencies.contentService,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Signage Mobile App',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: seedColor,
            brightness: Brightness.light,
            primary: seedColor,
            surface: Colors.white,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5FBFA),
          textTheme: ThemeData.light().textTheme.apply(
                bodyColor: navy,
                displayColor: navy,
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: navy,
            foregroundColor: Colors.white,
            centerTitle: false,
            elevation: 0,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            labelStyle: const TextStyle(color: Color(0xFF5C6B7E)),
            hintStyle: const TextStyle(color: Color(0xFF97A6B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD7E6E4)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFD7E6E4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: seedColor, width: 1.5),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: seedColor,
              foregroundColor: Colors.white,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            backgroundColor: navy.withValues(alpha: 0.95),
            contentTextStyle: const TextStyle(color: Colors.white),
          ),
        ),
        home: const LoginScreen(),
      ),
    );
  }
}
