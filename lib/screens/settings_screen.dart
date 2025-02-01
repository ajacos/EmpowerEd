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
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  File? _imageFile;
  bool _isLoading = false;
  String? _errorMessage;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('username, avatar_url')
            .eq('id', user.id)
            .single();

        if (response.error != null) {
          throw Exception('Failed to load user data: ${response.error!.message}');
        }

        setState(() {
          _usernameController.text = response['username'] ?? '';
          _currentAvatarUrl = response['avatar_url'];
        });
      }
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user data: $error'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
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
        final usernameResponse = await Supabase.instance.client
            .from('profiles')
            .update({'username': _usernameController.text})
            .eq('id', user.id);

        if (usernameResponse.error != null) {
          throw Exception('Failed to update username: ${usernameResponse.error!.message}');
        }

        // Update password if provided
        if (_currentPasswordController.text.isNotEmpty &&
            _newPasswordController.text.isNotEmpty) {
          final passwordResponse = await Supabase.instance.client.auth.updateUser(
            UserAttributes(
              password: _newPasswordController.text,
            ),
          );

          if (passwordResponse.error != null) {
            throw Exception('Failed to update password: ${passwordResponse.error!.message}');
          }
        }

        // Update profile picture if selected
        if (_imageFile != null) {
          final bytes = await _imageFile!.readAsBytes();
          final fileExt = _imageFile!.path.split('.').last;
          final fileName = '${DateTime.now().toIso8601String()}.$fileExt';
          final filePath = fileName;

          final uploadResponse = await Supabase.instance.client.storage
              .from('avatars')
              .uploadBinary(
                filePath,
                bytes,
                fileOptions: FileOptions(contentType: 'image/$fileExt'),
              );

          if (uploadResponse.error != null) {
            throw Exception('Failed to upload image: ${uploadResponse.error!.message}');
          }

          final imageUrl = Supabase.instance.client.storage
              .from('avatars')
              .getPublicUrl(filePath);

          final avatarResponse = await Supabase.instance.client
              .from('profiles')
              .update({'avatar_url': imageUrl})
              .eq('id', user.id);

          if (avatarResponse.error != null) {
            throw Exception('Failed to update avatar URL: ${avatarResponse.error!.message}');
          }

          setState(() {
            _currentAvatarUrl = imageUrl;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Settings updated successfully')),
        );
      } catch (error) {
        setState(() {
          _errorMessage = error.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $_errorMessage'), backgroundColor: Colors.red),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
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
                            Center(
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 50,
                                    backgroundImage: _imageFile != null
                                        ? FileImage(_imageFile!)
                                        : (_currentAvatarUrl != null
                                            ? NetworkImage(_currentAvatarUrl!)
                                            : null) as ImageProvider?,
                                    child: _imageFile == null &&
                                            _currentAvatarUrl == null
                                        ? Icon(Icons.person,
                                            size: 50, color: Colors.white)
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: CircleAvatar(
                                      backgroundColor: Colors.white,
                                      radius: 18,
                                      child: IconButton(
                                        icon: Icon(Icons.camera_alt,
                                            size: 18, color: Color(0xFF3949AB)),
                                        onPressed: _pickImage,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 24),
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
                              controller: _currentPasswordController,
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
                                if (_currentPasswordController.text.isNotEmpty &&
                                    (value == null || value.isEmpty)) {
                                  return 'Please enter a new password';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            TextFormField(
                              controller: _confirmPasswordController,
                              decoration: InputDecoration(
                                labelText: 'Confirm New Password',
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
                                if (_newPasswordController.text.isNotEmpty &&
                                    value != _newPasswordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
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
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

