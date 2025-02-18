import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Auth {
  Router get router {
    final router = Router();

    router.post('/signup', (Request request) {
      print(request.context['json']);
      return Response.ok('Signup');
    });

    return router;
  }
}