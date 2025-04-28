import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/questions.controller.dart';

class Questions {
  Router get router {
    final router = Router();

    router.get('/user/<id>', (Request request, String id) {
      return QuestionController.getUserQuestions(request, id);
    });

    // multiple choice question options
    router.post('/multiple-choice/',(Request request) {
      return QuestionController.createMultipleChoiceQuestion(request);
    });

    // (unauthenticated) route
    router.get('/multiple-choice/<id>/options', (Request request, String id) {
      return QuestionController.getMultipleChoiceQuestionOptions(request, id);
    });

    return router;
  }
}