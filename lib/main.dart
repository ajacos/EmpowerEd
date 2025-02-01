import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/verify_email_screen.dart';
import 'screens/home_screen.dart';
import 'screens/video_conference/index.dart';
import 'screens/educational_content_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/settings_screen.dart';

// Conditionally import uni_links
import 'package:uni_links/uni_links.dart' if (dart.library.html) 'package:empowered/utils/web_links.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://yvaqvatvowoahxqqplze.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl2YXF2YXR2b3dvYWh4cXFwbHplIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc1NDU0MDYsImV4cCI6MjA1MzEyMTQwNn0.QKP4EQUIfq_gNe3a0yqoUgwx8cpO591UksDeNCDVleY',
  );


  runApp(EmpoweredApp());
}

class EmpoweredApp extends StatefulWidget {
  @override
  _EmpoweredAppState createState() => _EmpoweredAppState();
}

class _EmpoweredAppState extends State<EmpoweredApp> with SingleTickerProviderStateMixin {
  StreamSubscription? _sub;
  bool _isLoading = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initUniLinks();
    }
    _initializeAnimations();
    _simulateLoading();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initUniLinks() async {
    if (kIsWeb) return;

    try {
      final initialUri = await getInitialUri();
      if (initialUri != null && mounted) {
        _handleIncomingLink(initialUri);
      }

      _sub = uriLinkStream.listen((Uri? uri) {
        if (uri != null && mounted) {
          _handleIncomingLink(uri);
        }
      }, onError: (err) {
        print('Error in URI stream: $err');
      });
    } catch (e) {
      print('Error getting initial URI: $e');
    }
  }

  void _handleIncomingLink(Uri uri) {
    if (uri.path.contains('verify-email')) {
      Navigator.of(context).pushNamed('/verify-email');
    }
  }

  void _simulateLoading() {
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _fadeController.forward();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Empowered',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
        ).copyWith(
          secondary: Color(0xFF64B5F6),
        ),
        primaryColor: Color(0xFF2196F3),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF2196F3),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF2196F3),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
        ),
        fontFamily: 'Roboto',
      ),
      home: AnimatedSwitcher(
        duration: Duration(milliseconds: 500),
        child: _isLoading
            ? LoadingScreen()
            : FadeTransition(
                opacity: _fadeAnimation,
                child: LoginScreen(),
              ),
      ),
      routes: {
        '/signup': (context) => SignupScreen(),
        '/verify-email': (context) => VerifyEmailScreen(),
        '/home': (context) => HomeScreen(),
        '/video': (context) => VideoConferenceScreen(),
        '/education': (context) => EducationalContentScreen(),
        '/settings': (context) => SettingsScreen(),
      },
    );
  }
}

