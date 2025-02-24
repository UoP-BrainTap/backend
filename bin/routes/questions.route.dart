import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

class Questions {
  Router get router {
    final router = Router();

    router.get('/user/<id>', (Request request, String id) {
      var user = request.context['user'] as Map;
      if (user['authenticated'] == false) {
        return Response.forbidden('Not authenticated');
      }
      return Response.ok('User ID: $id');
    });

    return router;
  }
}