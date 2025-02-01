import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../services/stats_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/home_skeleton.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final StatsService _statsService = StatsService();
  Map<String, dynamic>? _userStats;
  bool _isLoading = true;
  String? _error;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _dragExtent = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _loadData();
    _fadeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final statsService = StatsService();
    final stats = await statsService.getUserStats();
    if (mounted) {
      setState(() {
        _userStats = stats;
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }


  Future<void> _signOut() async {
    try {
      await Supabase.instance.client.auth.signOut();
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error signing out')),
      );
    }
  }

  String _formatStreak(int streak) {
    if (streak == 0) return 'No streak yet';
    if (streak == 1) return '1 day';
    return '$streak days';
  }

  Widget _buildStat(BuildContext context, String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        SizedBox(height: 8),
        Text(
          title,
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return VerticalDivider(color: Colors.white, thickness: 1);
  }

  Widget _buildStatsOverview(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat(context, 'Modules', '${_userStats!['completed_modules']}', Icons.school),
          _buildStatDivider(),
          _buildStat(context, 'Streak', '${_userStats!['streak']}', Icons.local_fire_department),
          _buildStatDivider(),
          _buildStat(context, 'Badges', '${(_userStats!['badges'] as List).length}', Icons.military_tech),
        ],
      ),
    );
  }

  double _getResponsiveFontSize(BuildContext context, double defaultSize) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 350) return defaultSize * 0.8;
    if (screenWidth < 400) return defaultSize * 0.9;
    return defaultSize;
  }

  Widget _buildBadgesSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Badges Earned',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 24),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: (_userStats!['badges'] as List).map((badge) {
            return Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: _getResponsiveFontSize(context, 24),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildWelcomeSection(BuildContext context, User? user, String today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome Back!',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 32),
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '${user?.email ?? 'User'}',
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 20),
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          today,
          style: TextStyle(
            fontSize: _getResponsiveFontSize(context, 16),
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, color.withOpacity(0.7)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 48),
            SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 18),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 14),
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, String title, String subtitle, double progress, String progressText, Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.2),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 18),
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: Colors.white,
            ),
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
          SizedBox(height: 8),
          Text(
            progressText,
            style: TextStyle(
              fontSize: _getResponsiveFontSize(context, 14),
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final user = Supabase.instance.client.auth.currentUser;
    final today = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      key: _scaffoldKey,
      appBar: isDesktop ? null : AppBar(
        title: Text('Empowered'),
        backgroundColor: Color(0xFF1A237E),
      ),
      drawer: isDesktop ? null : Drawer(
        child: Sidebar(user: user),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              setState(() {
                _dragExtent += details.delta.dx;
                _dragExtent = math.max(0, math.min(_dragExtent, 250));
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragExtent > 100) {
                _scaffoldKey.currentState?.openDrawer();
              }
              setState(() {
                _dragExtent = 0;
              });
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.8],
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (isDesktop) Sidebar(user: user),
                    Expanded(
                      child: _isLoading
                          ? HomeSkeleton(isDesktop: isDesktop)
                          : FadeTransition(
                              opacity: _fadeAnimation,
                              child: CustomScrollView(
                                slivers: [
                                  SliverPadding(
                                    padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
                                    sliver: SliverToBoxAdapter(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _buildWelcomeSection(context, user, today),
                                          SizedBox(height: isDesktop ? 40 : 30),
                                          _buildStatsOverview(context),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isDesktop ? 32.0 : 20.0,
                                      vertical: isDesktop ? 24.0 : 16.0,
                                    ),
                                    sliver: SliverGrid(
                                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: isDesktop ? 3 : 2,
                                        childAspectRatio: isDesktop ? 1.1 : 1.2,
                                        crossAxisSpacing: isDesktop ? 24.0 : 16.0,
                                        mainAxisSpacing: isDesktop ? 24.0 : 16.0,
                                      ),
                                      delegate: SliverChildListDelegate([
                                        _buildFeatureCard(context, 'Video Conference', 'Connect with support groups', Icons.video_call, Color(0xFF00E676), () => Navigator.pushNamed(context, '/video')),
                                        _buildFeatureCard(context, 'Educational Content', 'Learn coping strategies', Icons.school, Color(0xFFFFD600), () => Navigator.pushNamed(context, '/education')),
                                        _buildFeatureCard(context, 'Community Forum', 'Share and connect', Icons.forum, Color(0xFFE040FB), () {}),
                                        _buildFeatureCard(context, 'Resources', 'Access helpful materials', Icons.library_books, Color(0xFFFF6E40), () {}),
                                      ]),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(isDesktop ? 32.0 : 20.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Your Progress',
                                            style: TextStyle(
                                              fontSize: _getResponsiveFontSize(context, 24),
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          SizedBox(height: isDesktop ? 24 : 16),
                                          _buildProgressCard(context, 'Coping Strategies', 'Advanced techniques for stress management', 0.7, '7/10 modules', Color(0xFF00E5FF)),
                                          SizedBox(height: 16),
                                          _buildProgressCard(context, 'Mindfulness Techniques', 'Meditation and breathing exercises', 0.4, '2/5 modules', Color(0xFFFF4081)),
                                          SizedBox(height: isDesktop ? 40 : 30),
                                          _buildBadgesSection(context),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!isDesktop && _dragExtent > 0)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: _dragExtent,
              child: Opacity(
                opacity: _dragExtent / 250,
                child: Sidebar(user: user),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String badge) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          badge,
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

