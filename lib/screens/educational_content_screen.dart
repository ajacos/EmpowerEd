import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/sidebar.dart';
import 'dart:math' as math;

class EducationalContentScreen extends StatefulWidget {
  @override
  _EducationalContentScreenState createState() => _EducationalContentScreenState();
}

class _EducationalContentScreenState extends State<EducationalContentScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  double _dragExtent = 0;
  int _currentTopicIndex = 0;
  int _currentModuleIndex = 0;
  bool _showingQuestionnaire = false;

  final List<Map<String, dynamic>> educationalContent = [
    {
      'title': 'Stress Management',
      'modules': [
        {
          'title': 'Understanding Stress',
          'content': 'Stress is the body\'s response to pressure. Many different situations or life events can cause stress. It is often triggered when we experience something new, unexpected or that threatens our sense of self, or when we feel we have little control over a situation. We all deal with stress differently. Our ability to cope can depend on our genetics, early life events, personality and social and economic circumstances.',
        },
        {
          'title': 'Identifying Stress Triggers',
          'content': 'Stress triggers can be internal or external. Internal triggers include perfectionism, negative self-talk, and unrealistic expectations. External triggers can be work-related pressures, financial problems, relationship issues, or major life changes. Keeping a stress diary can help you identify your personal stress triggers.',
        },
        {
          'title': 'Stress Reduction Techniques',
          'content': 'There are many techniques to reduce stress, including deep breathing exercises, progressive muscle relaxation, mindfulness meditation, regular physical exercise, and maintaining a healthy diet. It\'s important to find what works best for you and practice these techniques regularly.',
        },
      ],
      'questionnaire': [
        {
          'question': 'What is stress?',
          'options': [
            'A type of food',
            'The body\'s response to pressure',
            'A form of exercise',
            'A medical condition'
          ],
          'correctAnswer': 1,
        },
        {
          'question': 'Which of the following is NOT a common stress trigger?',
          'options': [
            'Work-related pressures',
            'Financial problems',
            'Eating healthy food',
            'Relationship issues'
          ],
          'correctAnswer': 2,
        },
        {
          'question': 'Which of these is a stress reduction technique?',
          'options': [
            'Watching TV all day',
            'Eating junk food',
            'Deep breathing exercises',
            'Ignoring the problem'
          ],
          'correctAnswer': 2,
        },
      ],
    },
    {
      'title': 'Mindfulness Techniques',
      'modules': [
        {
          'title': 'Introduction to Mindfulness',
          'content': 'Mindfulness is the basic human ability to be fully present, aware of where we are and what we\'re doing, and not overly reactive or overwhelmed by what\'s going on around us. While mindfulness is something we all naturally possess, it\'s more readily available to us when we practice on a daily basis.',
        },
        {
          'title': 'Mindful Breathing',
          'content': 'Mindful breathing is a simple yet powerful mindfulness technique. It involves focusing your attention on your breath — the inhale and exhale. This practice can help calm your mind and body, reduce stress, and increase your ability to focus. Try to practice mindful breathing for a few minutes each day, gradually increasing the duration as you become more comfortable with the practice.',
        },
        {
          'title': 'Body Scan Meditation',
          'content': 'Body scan meditation is a practice where you pay attention to parts of the body and bodily sensations in a gradual sequence from feet to head. By mentally scanning yourself, you bring awareness to every single part of your body, noticing any aches, pains, tension, or general discomfort. This practice can be particularly helpful for people dealing with stress, anxiety, or chronic pain.',
        },
      ],
      'questionnaire': [
        {
          'question': 'What is mindfulness?',
          'options': [
            'The ability to read minds',
            'Being fully present and aware',
            'A type of medication',
            'A form of physical exercise'
          ],
          'correctAnswer': 1,
        },
        {
          'question': 'What does mindful breathing involve?',
          'options': [
            'Holding your breath for as long as possible',
            'Breathing as fast as you can',
            'Focusing your attention on your breath',
            'Breathing only through your mouth'
          ],
          'correctAnswer': 2,
        },
        {
          'question': 'What is the purpose of a body scan meditation?',
          'options': [
            'To fall asleep quickly',
            'To increase heart rate',
            'To bring awareness to every part of your body',
            'To improve physical strength'
          ],
          'correctAnswer': 2,
        },
      ],
    },
    {
      'title': 'Building Resilience',
      'modules': [
        {
          'title': 'Understanding Resilience',
          'content': 'Resilience is the ability to adapt well in the face of adversity, trauma, tragedy, threats, or significant sources of stress. It means "bouncing back" from difficult experiences. Resilience is not a trait that people either have or do not have. It involves behaviors, thoughts, and actions that can be learned and developed in anyone.',
        },
        {
          'title': 'Developing a Growth Mindset',
          'content': 'A growth mindset is the belief that abilities and intelligence can be developed through effort, learning, and persistence. This mindset can significantly contribute to building resilience. When faced with challenges, individuals with a growth mindset are more likely to persevere, learn from their experiences, and ultimately overcome obstacles.',
        },
        {
          'title': 'Building Strong Relationships',
          'content': 'Strong, positive relationships can provide support and acceptance in both good times and bad. Prioritize relationships with empathetic and understanding people. Join local groups or organizations to expand your social network. Helping others in their time of need can also benefit the helper, creating a sense of purpose and fostering self-worth.',
        },
      ],
      'questionnaire': [
        {
          'question': 'What is resilience?',
          'options': [
            'The ability to avoid all problems',
            'The ability to adapt well in the face of adversity',
            'The ability to predict the future',
            'The ability to never feel stressed'
          ],
          'correctAnswer': 1,
        },
        {
          'question': 'What characterizes a growth mindset?',
          'options': [
            'Believing that abilities are fixed and cannot be changed',
            'Avoiding all challenges',
            'Believing that abilities can be developed through effort and learning',
            'Focusing only on natural talents'
          ],
          'correctAnswer': 2,
        },
        {
          'question': 'How can building strong relationships contribute to resilience?',
          'options': [
            'It doesn\'t contribute to resilience',
            'By providing support and acceptance in good times and bad',
            'By eliminating all sources of stress',
            'By making you immune to adversity'
          ],
          'correctAnswer': 1,
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      key: _scaffoldKey,
      drawer: isDesktop ? null : Drawer(
        child: Sidebar(user: user),
      ),
      body: Stack(
        children: [
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (!isDesktop) {
                setState(() {
                  _dragExtent += details.delta.dx;
                  _dragExtent = math.max(0, math.min(_dragExtent, 250));
                });
              }
            },
            onHorizontalDragEnd: (details) {
              if (!isDesktop && _dragExtent > 100) {
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
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (isDesktop) Sidebar(user: user),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                if (!isDesktop)
                                  IconButton(
                                    icon: Icon(Icons.menu, color: Colors.white),
                                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                                  ),
                                Expanded(
                                  child: Text(
                                    'Educational Content',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                if (!isDesktop)
                                  SizedBox(width: 48), // To balance the menu button
                              ],
                            ),
                          ),
                          Expanded(
                            child: _buildContent(),
                          ),
                        ],
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
                child: Drawer(
                  child: Sidebar(user: user),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_showingQuestionnaire) {
      return _buildQuestionnaire();
    } else {
      return _buildModuleContent();
    }
  }

  Widget _buildModuleContent() {
    final currentTopic = educationalContent[_currentTopicIndex];
    final currentModule = currentTopic['modules'][_currentModuleIndex];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            currentTopic['title'],
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16),
          Text(
            currentModule['title'],
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          SizedBox(height: 16),
          Text(
            currentModule['content'],
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentModuleIndex > 0)
                ElevatedButton(
                  onPressed: _previousModule,
                  child: Text('Previous'),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
                ),
              if (_currentModuleIndex < currentTopic['modules'].length - 1)
                ElevatedButton(
                  onPressed: _nextModule,
                  child: Text('Next'),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF2196F3)),
                ),
              if (_currentModuleIndex == currentTopic['modules'].length - 1)
                ElevatedButton(
                  onPressed: _startQuestionnaire,
                  child: Text('Start Questionnaire'),
                  style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionnaire() {
    final currentTopic = educationalContent[_currentTopicIndex];
    final questionnaire = currentTopic['questionnaire'];

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Self-Evaluation Questionnaire',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16),
          ...questionnaire.asMap().entries.map((entry) {
            final index = entry.key;
            final question = entry.value;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question ${index + 1}: ${question['question']}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white70),
                ),
                SizedBox(height: 8),
                ...question['options'].asMap().entries.map((optionEntry) {
                  final optionIndex = optionEntry.key;
                  final option = optionEntry.value;
                  return RadioListTile<int>(
                    title: Text(option, style: TextStyle(color: Colors.white70)),
                    value: optionIndex,
                    groupValue: null, // You would typically use a state variable here
                    onChanged: (value) {
                      // Handle answer selection
                    },
                    activeColor: Color(0xFF2196F3),
                  );
                }),
                SizedBox(height: 16),
              ],
            );
          }),
          SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _finishQuestionnaire,
              child: Text('Finish Questionnaire'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF4CAF50)),
            ),
          ),
        ],
      ),
    );
  }

  void _previousModule() {
    setState(() {
      if (_currentModuleIndex > 0) {
        _currentModuleIndex--;
      } else if (_currentTopicIndex > 0) {
        _currentTopicIndex--;
        _currentModuleIndex = educationalContent[_currentTopicIndex]['modules'].length - 1;
      }
    });
  }

  void _nextModule() {
    setState(() {
      if (_currentModuleIndex < educationalContent[_currentTopicIndex]['modules'].length - 1) {
        _currentModuleIndex++;
      } else if (_currentTopicIndex < educationalContent.length - 1) {
        _currentTopicIndex++;
        _currentModuleIndex = 0;
      }
    });
  }

  void _startQuestionnaire() {
    setState(() {
      _showingQuestionnaire = true;
    });
  }

  void _finishQuestionnaire() {
    setState(() {
      _showingQuestionnaire = false;
      if (_currentTopicIndex < educationalContent.length - 1) {
        _currentTopicIndex++;
        _currentModuleIndex = 0;
      } else {
        // All topics completed
        // You could show a completion message or navigate to a different screen
      }
    });
  }
}

