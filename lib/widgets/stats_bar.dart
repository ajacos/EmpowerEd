import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StatsBar extends StatelessWidget {
  final int completedModules;
  final int streak;
  final List<dynamic> badges;

  const StatsBar({
    Key? key,
    required this.completedModules,
    required this.streak,
    required this.badges,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            icon: Icons.school,
            value: completedModules.toString(),
            label: 'Modules',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.local_fire_department,
            value: streak.toString(),
            label: 'Day Streak',
          ),
          _buildDivider(),
          _buildStatItem(
            icon: Icons.military_tech,
            value: badges.length.toString(),
            label: 'Badges',
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white24,
    );
  }
}

