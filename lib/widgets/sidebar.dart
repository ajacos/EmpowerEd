import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Sidebar extends StatelessWidget {
  final User? user;

  const Sidebar({Key? key, this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: Color(0xFF1A237E),
      child: Column(
        children: [
          SizedBox(height: 50),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white24,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
          SizedBox(height: 10),
          Text(
            user?.email?.split('@')[0] ?? 'User',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          SizedBox(height: 30),
          _buildMenuItem(context, 'Home', Icons.home, () => Navigator.pushReplacementNamed(context, '/home')),
          _buildMenuItem(context, 'Video Conference', Icons.video_call, () => Navigator.pushNamed(context, '/video')),
          _buildMenuItem(context, 'Educational Content', Icons.school, () => Navigator.pushReplacementNamed(context, '/education')),
          _buildMenuItem(context, 'Community Forum', Icons.forum, () {}),
          _buildMenuItem(context, 'Resources', Icons.library_books, () {}),
          Spacer(),
          _buildMenuItem(context, 'Logout', Icons.logout, () => _showLogoutConfirmation(context)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(title, style: TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color(0xFF1A237E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Confirm Logout', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel', style: TextStyle(color: Colors.white70)),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Logout', style: TextStyle(color: Colors.red[300])),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                Navigator.of(context).pushNamedAndRemoveUntil('/', (Route<dynamic> route) => false);
              },
            ),
          ],
        );
      },
    );
  }
}

