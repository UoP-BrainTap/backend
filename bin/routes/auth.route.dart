import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../controllers/auth.controller.dart';

class Auth {
  Router get router {
    final router = Router();

    router.post('/signup', (Request request) {
      return AuthController.signup(request);
    });

    router.post('/login', (Request request) {
      return AuthController.login(request);
    });

    return router;
  }
}