import 'package:supabase_flutter/supabase_flutter.dart';

class StatsService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>> getUserStats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final quizAttemptsResponse = await _supabase
          .from('quiz_attempts')
          .select('quiz_id, score')
          .eq('user_id', user.id);

      final completedQuizzes = (quizAttemptsResponse as List).map((attempt) => attempt['quiz_id']).toSet();
      final totalScore = (quizAttemptsResponse as List).fold<int>(0, (sum, attempt) => sum + (attempt['score'] as int? ?? 0));

      final userStatsResponse = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .single();

      return {
        'completed_modules': completedQuizzes.length,
        'total_score': totalScore,
        'streak': userStatsResponse['current_streak'] ?? 0,
        'badges': userStatsResponse['badges'] ?? [],
      };
    } catch (error) {
      print('Error getting user stats: $error');
      rethrow;
    }
  }

  Future<void> saveQuizAttempt(String quizId, Map<String, int> answers, int score) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      await _supabase.from('quiz_attempts').upsert({
        'user_id': user.id,
        'quiz_id': quizId,
        'answers': answers,
        'score': score,
      });

      // Update user_stats to increment completed_modules
      await _supabase.rpc('increment_completed_modules', params: {'input_user_id': user.id});
    } catch (error) {
      print('Error saving quiz attempt: $error');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getQuizAttempt(String quizId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final response = await _supabase
          .from('quiz_attempts')
          .select()
          .eq('quiz_attempts.user_id', user.id)
          .eq('quiz_id', quizId)
          .single();

      return response;
    } catch (error) {
      print('Error getting quiz attempt: $error');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getCompletedQuizzes() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final response = await _supabase
          .from('quiz_attempts')
          .select('quiz_id, score, created_at')
          .eq('user_id', user.id);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (error) {
      print('Error getting completed quizzes: $error');
      return [];
    }
  }

  Future<void> updateLoginStreak() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final now = DateTime.now().toUtc();
  
      // Try to get existing user stats
      final response = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        final lastLogin = DateTime.parse(response['last_login']);
        final difference = now.difference(lastLogin);

        // Only update if the last login was not today
        if (difference.inDays > 0) {
          int currentStreak = response['current_streak'] ?? 0;
          int highestStreak = response['highest_streak'] ?? 0;

          // If last login was yesterday, increment streak
          if (difference.inDays == 1) {
            currentStreak += 1;
            if (currentStreak > highestStreak) {
              highestStreak = currentStreak;
            }
          } else {
            // If last login was more than a day ago, reset streak
            currentStreak = 1;
          }

          // Update user stats
          await _supabase.from('user_stats').upsert({
            'user_id': user.id,
            'last_login': now.toIso8601String(),
            'current_streak': currentStreak,
            'highest_streak': highestStreak,
          });
        }
      } else {
        // First time login, create new entry
        await _supabase.from('user_stats').insert({
          'user_id': user.id,
          'last_login': now.toIso8601String(),
          'current_streak': 1,
          'highest_streak': 1,
          'completed_modules': 0,
          'badges': [],
        });
      }
    } catch (error) {
      print('Error updating login streak: $error');
      // Instead of rethrowing, we'll just log the error
      // This allows the login process to complete even if streak update fails
    }
  }

  Future<void> addBadge(String badge) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    try {
      final currentBadges = await _supabase
          .from('user_stats')
          .select('badges')
          .eq('user_id', user.id)
          .single();

      List badges = currentBadges['badges'] ?? [];
      if (!badges.contains(badge)) {
        badges.add(badge);
        await _supabase.from('user_stats').update({
          'badges': badges,
        }).eq('user_id', user.id);
      }
    } catch (error) {
      print('Error adding badge: $error');
      rethrow;
    }
  }
}

