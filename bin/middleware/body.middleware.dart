import 'dart:convert';

import 'package:shelf/shelf.dart';

/// A middleware to parse the body of incoming requests as JSON to a [Map]
class BodyMiddleware {
  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        final body = await request.readAsString();
        // if a string is present in the body, parse it as JSON
        if (body.isEmpty) {
          return innerHandler(request.change(
            context: {
              'json': {},
            }
          ));
        }
        late final Map json;
        try {
          json = jsonDecode(body);
        } catch (e) {
          return Response.badRequest(body: 'Invalid JSON');
        }
        return innerHandler(request.change(
          context: {
            'json': json,
          }
        ));
      };
    };
  }
}