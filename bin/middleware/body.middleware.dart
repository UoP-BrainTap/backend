import 'dart:convert';

import 'package:shelf/shelf.dart';

class BodyMiddleware {
  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        final body = await request.readAsString();
        final json = jsonDecode(body);
        return innerHandler(request.change(
          context: {
            'json': json,
          }
        ));
      };
    };
  }
}