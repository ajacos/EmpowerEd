import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/stats_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final StatsService _statsService = StatsService();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );

        if (response.user != null) {
          // Update login streak
          await _statsService.updateLoginStreak();
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } on AuthException catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red,
        ));
      } catch (error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('An unexpected error occurred'),
          backgroundColor: Colors.red,
        ));
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Empowered',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2196F3),
                            ),
                          ),
                          SizedBox(height: 32),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock),
                            ),
                            obscureText: true,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _signIn,
                            child: _isLoading
                                ? CircularProgressIndicator()
                                : Text('Sign In'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                            ),
                          ),
                          SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: Text('Forgot Password?'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(context, '/signup');
                            },
                            child: Text('Don\'t have an account? Sign up'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

