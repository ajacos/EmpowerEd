import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/sidebar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../widgets/stats_bar.dart';
import '../services/stats_service.dart';

class EducationalContentScreen extends StatefulWidget {
  @override
  _EducationalContentScreenState createState() => _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _animationController;
  int _expandedIndex = -1;
  int _currentTopicIndex = -1;
  int _currentModuleIndex = -1;
  bool _showingQuiz = false;
  bool _showingReflection = false;
  bool _showingCompletion = false;
  Map<String, int> _quizAnswers = {};
  String _reflectionText = '';
  List<dynamic>? _educationalContent;
  Map<String, dynamic>? _userProgress;
  final _supabase = Supabase.instance.client;
  final _reflectionController = TextEditingController();
  final StatsService _statsService = StatsService();
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final content = await loadEducationalContent();
      final progress = await _statsService.getCompletedQuizzes();
      final stats = await _statsService.getUserStats();
      if (mounted) {
        setState(() {
          _educationalContent = content;
          _userProgress = {'completed_quizzes': progress};
          _userStats = stats;
        });
      }
    } catch (e) {
      print('Error loading initial data: $e');
      // Handle error (e.g., show error message to user)
    }
  }

  Future<List<dynamic>> loadEducationalContent() async {
    try {
      final String jsonContent = await rootBundle.loadString('assets/data/educational_content.json');
      final data = json.decode(jsonContent);
      return data['topics'];
    } catch (e) {
      print('Error loading educational content: $e');
      return [];
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _reflectionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
          ),
        ),
        child: SafeArea(
          child: Row(
            children: [
              if (isDesktop) Sidebar(user: user),
              Expanded(
                child: _educationalContent == null || _userProgress == null || _userStats == null
                    ? Center(child: CircularProgressIndicator())
                    : _buildContent(_educationalContent!, _userProgress!, _userStats!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> educationalContent, Map<String, dynamic> userProgress, Map<String, dynamic> userStats) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: StatsBar(
            completedModules: userStats['completed_modules'] ?? 0,
            streak: userStats['streak'] ?? 0,
            badges: userStats['badges'] ?? [],
          ),
        ),
        Expanded(
          child: _buildMainContent(educationalContent, userProgress),
        ),
      ],
    );
  }

  Widget _buildMainContent(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    if (_currentTopicIndex == -1) {
      return _buildTopicList(educationalContent, userProgress);
    } else if (_showingQuiz) {
      return _buildQuiz(educationalContent, userProgress);
    } else if (_showingReflection) {
      return _buildReflection(educationalContent, userProgress);
    } else if (_showingCompletion) {
      return _buildCompletionScreen(educationalContent, userProgress);
    } else if (_currentModuleIndex != -1) {
      return _buildModuleContent(educationalContent, userProgress);
    } else if (_currentTopicIndex != -1) {
      return _buildModuleList(educationalContent, userProgress);
    } else {
      return _buildTopicList(educationalContent, userProgress);
    }
  }

  Widget _buildTopicList(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Educational Content',
            style: GoogleFonts.poppins(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: educationalContent.length,
            itemBuilder: (context, index) {
              final topic = educationalContent[index];
              final isExpanded = _expandedIndex == index;
              return _buildTopicItem(topic, isExpanded, index, userProgress);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopicItem(dynamic topic, bool isExpanded, int index, Map<String, dynamic> userProgress) {
    final totalModules = (topic['modules'] as List).length;
    int completedModules = 0;

    for (var module in topic['modules'] as List) {
      final quizId = '${topic['title']}_${module['title']}';
      final completedQuizzes = userProgress['completed_quizzes'] as List<dynamic>? ?? [];
      final quizAttempt = completedQuizzes.cast<Map<String, dynamic>>().firstWhere(
        (quiz) => quiz['quiz_id'] == quizId,
        orElse: () => <String, dynamic>{},
      );
      final isCompleted = quizAttempt.isNotEmpty;
      if (isCompleted) {
        completedModules++;
      }
    }

    final percentage = totalModules > 0
        ? ((completedModules / totalModules) * 100).toInt()
        : 0;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (isExpanded) {
                _expandedIndex = -1;
                _animationController.reverse();
              } else {
                _expandedIndex = index;
                _animationController.forward();
              }
            });
          },
          child: Container(
            margin: EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      topic['title'],
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    ' - $percentage%',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: 8),
                  AnimatedIcon(
                    icon: AnimatedIcons.menu_close,
                    progress: _animationController,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: Container(height: 0),
          secondChild: Column(
            children: (topic['modules'] as List).map<Widget>((module) {
              final quizId = '${topic['title']}_${module['title']}';
              final completedQuizzes = userProgress['completed_quizzes'] as List<dynamic>? ?? [];
              final quizAttempt = completedQuizzes.cast<Map<String, dynamic>>().firstWhere(
                (quiz) => quiz['quiz_id'] == quizId,
                orElse: () => <String, dynamic>{},
              );
              final isCompleted = quizAttempt.isNotEmpty;
              return InkWell(
                onTap: () {
                  setState(() {
                    _currentTopicIndex = index;
                    _currentModuleIndex = (topic['modules'] as List).indexOf(module);
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(left: 24, right: 24, bottom: 8),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Color(0xFF4CAF50) // Solid green for completed modules
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ListTile(
                    title: Text(
                      module['title'],
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    subtitle: isCompleted
                        ? Text(
                            'Score: ${quizAttempt['score'] ?? 'N/A'}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.white54,
                            ),
                          )
                        : null,
                    trailing: Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                  ),
                ),
              );
            }).toList(),
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: Duration(milliseconds: 300),
        ),
      ],
    );
  }

  Widget _buildModuleList(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    final currentTopic = educationalContent[_currentTopicIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentTopicIndex = -1;
                    _expandedIndex = -1;
                  });
                },
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  currentTopic['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: (currentTopic['modules'] as List).length,
            itemBuilder: (context, index) {
              final module = currentTopic['modules'][index];
              final quizId = '${currentTopic['title']}_${module['title']}';
              final completedQuizzes = userProgress['completed_quizzes'] as List<dynamic>? ?? [];
              final quizAttempt = completedQuizzes.cast<Map<String, dynamic>>().firstWhere(
                (quiz) => quiz['quiz_id'] == quizId,
                orElse: () => <String, dynamic>{},
              );
              final isCompleted = quizAttempt.isNotEmpty;
              return Column(
                children: [
                  InkWell(
                    onTap: () {
                      setState(() {
                        _currentModuleIndex = index;
                      });
                    },
                    child: Container(
                      margin: EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? Color(0xFF4CAF50).withOpacity(0.3)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        title: Text(
                          module['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: isCompleted
                            ? Text(
                                'Score: ${quizAttempt['score'] ?? 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white54,
                                ),
                              )
                            : null,
                        trailing: isCompleted
                            ? Icon(Icons.check_circle, color: Colors.white)
                            : Icon(Icons.chevron_right, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentModuleIndex = index;
                        _showingQuiz = true;
                        _quizAnswers = {};  // Reset quiz answers when starting a new attempt
                      });
                    },
                    child: Text(isCompleted ? 'Retake Quiz' : 'Take Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF4CAF50),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      textStyle: GoogleFonts.poppins(fontSize: 14),
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModuleContent(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
    final quizId = '${currentTopic['title']}_${currentModule['title']}';
    final completedQuizzes = userProgress['completed_quizzes'] as List<dynamic>? ?? [];
    final quizAttempt = completedQuizzes.cast<Map<String, dynamic>>().firstWhere(
      (quiz) => quiz['quiz_id'] == quizId,
      orElse: () => <String, dynamic>{},
    );
    final hasAttemptedQuiz = quizAttempt.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _currentModuleIndex = -1;
                  });
                },
              ),
              SizedBox(width: 16),
              Expanded(
                child: Text(
                  currentModule['title'],
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Text(
              currentModule['content'],
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                height: 1.6,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasAttemptedQuiz)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'Previous Score: ${quizAttempt['score'] ?? 'N/A'}',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showingQuiz = true;
                    _quizAnswers = {};  // Reset quiz answers when starting a new attempt
                  });
                },
                child: Text(hasAttemptedQuiz ? 'Retake Quiz' : 'Take Quiz'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF4CAF50),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  textStyle: GoogleFonts.poppins(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuiz(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
    final quiz = currentModule['quiz'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Quiz: ${currentModule['title']}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            itemCount: quiz.length,
            itemBuilder: (context, index) {
              final question = quiz[index];
              return Card(
                color: Colors.white.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${index + 1}: ${question['question']}',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      ...List.generate(
                        question['options'].length,
                        (optionIndex) => RadioListTile<int>(
                          title: Text(
                            question['options'][optionIndex],
                            style: GoogleFonts.poppins(color: Colors.white70),
                          ),
                          value: optionIndex,
                          groupValue: _quizAnswers['$index'],
                          onChanged: (value) {
                            setState(() {
                              _quizAnswers['$index'] = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showingQuiz = false;
                _showingReflection = true;
              });
            },
            child: Text('Finish Quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: GoogleFonts.poppins(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReflection(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
    final reflectionPrompt = currentModule['reflectionPrompt'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Reflection',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            reflectionPrompt,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: TextField(
              controller: _reflectionController,
              maxLines: null,
              expands: true,
              decoration: InputDecoration(
                hintText: 'Enter your reflection here...',
                hintStyle: GoogleFonts.poppins(color: Colors.white54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white30),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white30),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white),
                ),
              ),
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () async {
              // Save the quiz results and reflection
              await saveQuizAttempt();

              setState(() {
                _showingReflection = false;
                _showingCompletion = true;
              });
            },
            child: Text('Finish'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF4CAF50),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: GoogleFonts.poppins(fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionScreen(List<dynamic> educationalContent, Map<String, dynamic> userProgress) {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
    final quizId = '${currentTopic['title']}_${currentModule['title']}';
    final completedQuizzes = userProgress['completed_quizzes'] as List<dynamic>? ?? [];
    final quizAttempt = completedQuizzes.cast<Map<String, dynamic>>().firstWhere(
      (quiz) => quiz['quiz_id'] == quizId,
      orElse: () => <String, dynamic>{},
    );
    final score = quizAttempt['score'] ?? 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.celebration,
          size: 100,
          color: Colors.yellow,
        ),
        SizedBox(height: 24),
        Text(
          'Congratulations!',
          style: GoogleFonts.poppins(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'You have completed the "${currentModule['title']}" module.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ),
        SizedBox(height: 24),
        Text(
          'Your Score: $score',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 48),
        ElevatedButton(
          onPressed: () async {
            await _loadInitialData();
            setState(() {
              _currentTopicIndex = -1;
              _currentModuleIndex = -1;
              _expandedIndex = -1;
              _showingQuiz = false;
              _showingReflection = false;
              _showingCompletion = false;
              _quizAnswers = {};
              _reflectionController.clear();
            });
          },
          child: Text('Back to Topics'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4CAF50),
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: GoogleFonts.poppins(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Future<void> saveQuizAttempt() async {
    final currentTopic = _educationalContent![_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
    final quizId = '${currentTopic['title']}_${currentModule['title']}';

    // Calculate the score
    int score = 0;
    final quiz = currentModule['quiz'];
    for (int i = 0; i < quiz.length; i++) {
      if (_quizAnswers['$i'] == quiz[i]['correctAnswer']) {
        score++;
      }
    }

    try {
      await _statsService.saveQuizAttempt(quizId, _quizAnswers, score);

      // Update the local user progress immediately
      setState(() {
        if (_userProgress != null) {
          final completedQuizzes = _userProgress!['completed_quizzes'] as List<dynamic>? ?? [];
          final existingAttemptIndex = completedQuizzes.indexWhere((quiz) => quiz['quiz_id'] == quizId);
          if (existingAttemptIndex != -1) {
            completedQuizzes[existingAttemptIndex] = {
              'quiz_id': quizId,
              'score': score,
              'created_at': DateTime.now().toIso8601String(),
            };
          } else {
            completedQuizzes.add({
              'quiz_id': quizId,
              'score': score,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
          _userProgress!['completed_quizzes'] = completedQuizzes;
        }
      });
      await _loadInitialData();
    } catch (error) {
      print('Error saving quiz attempt: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save quiz results. Please try again.')),
      );
    }
  }
}

