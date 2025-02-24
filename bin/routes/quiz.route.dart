import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';

class QuizRoute {
  Router get router {
    final router = Router();

    // Create a new question
    router.post('/add_question', (Request request) async {
      final db = request.context['db'] as Connection;
      final body = request.context['json'] as Map<String, dynamic>;

      final quizId = body['quiz_id'];
      final questionText = body['question_text'];
      final questionType = body['question_type'];

      if (quizId == null || questionText == null || questionType == null) {
        return Response(400, body: 'Missing required fields');
      }

      await db.execute(
        'INSERT INTO questions (quiz_id, question_text, question_type) VALUES (@quizId, @questionText, @questionType)',
        parameters: {'quizId': quizId, 'questionText': questionText, 'questionType': questionType},
      );

      return Response.ok('Question added successfully');
    });
    return router;
  }
}