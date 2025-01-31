import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/sidebar.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;

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
  Map<String, int> _quizAnswers = {};
  String _reflectionText = '';
  late Future<List<dynamic>> _educationalContent;

  Future<List<dynamic>> loadEducationalContent() async {
    final String jsonContent = await rootBundle.loadString('data/educational_content.json');
    final data = json.decode(jsonContent);
    return data['topics'];
  }

  @override
  void initState() {
    super.initState();
    _educationalContent = loadEducationalContent();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
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
                child: FutureBuilder<List<dynamic>>(
                  future: _educationalContent,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    } else if (snapshot.hasData) {
                      return _buildContent(snapshot.data!);
                    } else {
                      return Center(child: Text('No data available'));
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<dynamic> educationalContent) {
    if (_currentTopicIndex == -1) {
      return _buildTopicList(educationalContent);
    } else if (_showingQuiz) {
      return _buildQuiz(educationalContent);
    } else if (_showingReflection) {
      return _buildReflection(educationalContent);
    } else if (_currentModuleIndex != -1) {
      return _buildModuleContent(educationalContent);
    } else if (_currentTopicIndex != -1) {
      return _buildModuleList(educationalContent);
    } else {
      return _buildTopicList(educationalContent);
    }
  }

  Widget _buildTopicList(List<dynamic> educationalContent) {
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
                        title: Text(
                          topic['title'],
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                        trailing: AnimatedIcon(
                          icon: AnimatedIcons.menu_close,
                          progress: _animationController,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  AnimatedCrossFade(
                    firstChild: Container(height: 0),
                    secondChild: Column(
                      children: (topic['modules'] as List).map<Widget>((module) {
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
                              color: Colors.white.withOpacity(0.05),
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
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModuleList(List<dynamic> educationalContent) {
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
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
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
                        trailing: Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _currentModuleIndex = index;
                        _showingQuiz = true;
                      });
                    },
                    child: Text('Take Quiz'),
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

  Widget _buildModuleContent(List<dynamic> educationalContent) {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];
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
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _showingQuiz = true;
              });
            },
            child: Text('Take Quiz'),
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

  Widget _buildQuiz(List<dynamic> educationalContent) {
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

  Widget _buildReflection(List<dynamic> educationalContent) {
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
              onChanged: (value) {
                setState(() {
                  _reflectionText = value;
                });
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () {
              // Here you would typically save the reflection and quiz results
              print('Quiz Answers: $_quizAnswers');
              print('Reflection: $_reflectionText');
              setState(() {
                _currentTopicIndex = -1;
                _currentModuleIndex = -1;
                _expandedIndex = -1;
                _showingQuiz = false;
                _showingReflection = false;
                _quizAnswers = {};
                _reflectionText = '';
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
}

