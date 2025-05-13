import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';

import '../controllers/session.controller.dart';

class Sessions {
  Router get router {
    final router = Router();

    router.post('/new', (Request request) {
      return SessionController.newSession(request);
    });

    router.post('/join/<code>', (Request request, String code) {
      return SessionController.joinSession(request, code);
    });

    router.get('/<code>/question', (Request request, String code) {
      return SessionController.getActiveQuestionId(request, code);
    });

    router.post('/<code>/question', (Request request, String code) {
      return SessionController.setActiveQuestionId(request, code);
    });

    router.post('/<code>/question/answer', (Request request, String code) {
      return SessionController.submitMultiChoiceAnswer(request, code);
    });

    router.get('/<code>', (Request request, String code) {
      for (var session in SessionController.sessions.values) {
        if (session.sessionCode == int.parse(code)) {
          return Response.ok("");
        }
      }
      return Response.notFound('Session not found');
    });

    return router;
  }

  Handler get socket {
    return SessionController.socket;
  }
}