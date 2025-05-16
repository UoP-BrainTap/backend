import 'package:shelf/shelf.dart';

/// A middleware that checks if the user is authenticated. Denies access if not.
class AuthenticatedMiddleware {
  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        var user = request.context['user'] as Map;
        if (user['authenticated'] == false) {
          return Response.forbidden('Not authenticated');
        }
        return innerHandler(request);
      };
    };
  }
}