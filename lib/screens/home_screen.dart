import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar.dart';
import 'dart:math' as math;
import '../widgets/home_skeleton.dart';
import 'package:flutter/animation.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  double _dragExtent = 0;
  bool _isLoading = true;

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

  Future<void> _loadData() async {
    // Simulate data loading
    await Future.delayed(Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _fadeController.forward();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Helper function to calculate responsive font size
  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return baseSize * 1.3;
    if (screenWidth > 900) return baseSize * 1.15;
    if (screenWidth > 600) return baseSize * 1.0;
    return baseSize * 0.85;
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
                                        _buildFeatureCard(context, 'Video Conference', 'Connect with support groups', Icons.video_call, Color(0xFF4CAF50), () => Navigator.pushNamed(context, '/video')),
                                        _buildFeatureCard(context, 'Educational Content', 'Learn coping strategies', Icons.school, Color(0xFFFFA000), () => Navigator.pushNamed(context, '/education')),
                                        _buildFeatureCard(context, 'Community Forum', 'Share and connect', Icons.forum, Color(0xFF9C27B0), () {}),
                                        _buildFeatureCard(context, 'Resources', 'Access helpful materials', Icons.library_books, Color(0xFF795548), () {}),
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
                                          _buildProgressCard(context, 'Coping Strategies', 'Advanced techniques for stress management', 0.7, '7/10 modules', Color(0xFF00BCD4)),
                                          SizedBox(height: 16),
                                          _buildProgressCard(context, 'Mindfulness Techniques', 'Meditation and breathing exercises', 0.4, '2/5 modules', Color(0xFFE91E63)),
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

  Widget _buildWelcomeSection(BuildContext context, User? user, String today) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back,',
          style: TextStyle(
            color: Colors.white60,
            fontSize: _getResponsiveFontSize(context, 16),
          ),
        ),
        SizedBox(height: 4),
        Text(
          user?.email?.split('@')[0] ?? 'User',
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveFontSize(context, 24),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          today,
          style: TextStyle(
            color: Colors.white70,
            fontSize: _getResponsiveFontSize(context, 14),
          ),
        ),
      ],
    );
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
          _buildStat(context, 'Courses', '4', Icons.school),
          _buildStatDivider(),
          _buildStat(context, 'Hours', '12.5', Icons.timer),
          _buildStatDivider(),
          _buildStat(context, 'Completed', '2', Icons.task_alt),
        ],
      ),
    );
  }

  Widget _buildStat(BuildContext context, String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: _getResponsiveFontSize(context, 20),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white60,
            fontSize: _getResponsiveFontSize(context, 12),
          ),
        ),
      ],
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white24,
    );
  }

  Widget _buildFeatureCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      elevation: 8,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.8)],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
                SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 14),
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Flexible(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 11),
                      color: Colors.white70,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, String title, String description, double progress, String subtitle, Color color) {
    return Card(
      elevation: 8,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.white.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
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
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: _getResponsiveFontSize(context, 12),
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${(progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: _getResponsiveFontSize(context, 12),
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Container(
                  height: 8,
                  width: MediaQuery.of(context).size.width * progress,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: _getResponsiveFontSize(context, 12),
                color: Colors.white60,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

