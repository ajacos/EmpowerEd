import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/sidebar.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCurrentUsername();
  }

  Future<void> _loadCurrentUsername() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .single();
      setState(() {
        _usernameController.text = response['username'] ?? '';
      });
    }
  }

  Future<void> _updateSettings() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final user = Supabase.instance.client.auth.currentUser;
        if (user == null) throw Exception('User not logged in');

        // Update username
        await Supabase.instance.client.from('profiles').upsert({
          'id': user.id,
          'username': _usernameController.text,
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Update password if provided
        if (_passwordController.text.isNotEmpty && _newPasswordController.text.isNotEmpty) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              password: _newPasswordController.text,
            ),
          );
        }

        // Update profile picture if selected
        if (_imageFile != null) {
          final bytes = await _imageFile!.readAsBytes();
          final fileExt = _imageFile!.path.split('.').last;
          final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
          final filePath = fileName;
          await Supabase.instance.client.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: 'image/$fileExt'),
          );
          final imageUrl = Supabase.instance.client.storage.from('avatars').getPublicUrl(filePath);
          await Supabase.instance.client.from('profiles').upsert({
            'id': user.id,
            'avatar_url': imageUrl,
            'updated_at': DateTime.now().toIso8601String(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings updated successfully')),
        );
      } catch (error) {
        setState(() {
          _errorMessage = error.toString();
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3949AB), Color(0xFF283593)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            Sidebar(user: user),
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 24),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _usernameController,
                              decoration: InputDecoration(
                                labelText: 'Username',
                                labelStyle: TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                              ),
                              style: TextStyle(color: Colors.white),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a username';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Current Password',
                                labelStyle: TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                              ),
                              obscureText: true,
                              style: TextStyle(color: Colors.white),
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _newPasswordController,
                              decoration: InputDecoration(
                                labelText: 'New Password',
                                labelStyle: TextStyle(color: Colors.white70),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white30),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.white),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.1),
                              ),
                              obscureText: true,
                              style: TextStyle(color: Colors.white),
                              validator: (value) {
                                if (_passwordController.text.isNotEmpty && (value == null || value.isEmpty)) {
                                  return 'Please enter a new password';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _pickImage,
                              child: Text('Select Profile Picture'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                side: BorderSide(color: Colors.white),
                              ),
                            ),
                            if (_imageFile != null) ...[
                              SizedBox(height: 16),
                              Text(
                                'Selected image: ${_imageFile!.path.split('/').last}',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                            SizedBox(height: 24),
                            if (_errorMessage != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Text(
                                  _errorMessage!,
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _updateSettings,
                              child: _isLoading
                                  ? CircularProgressIndicator(color: Colors.white)
                                  : Text('Save Changes'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                                side: BorderSide(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }
}

