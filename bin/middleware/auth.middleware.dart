import 'package:postgres/postgres.dart';

import '../backend.dart';

import 'package:shelf/shelf.dart';

class AuthMiddleware {
  static final Map<String, dynamic> _unauthenticated = {
    "user": {
      "authenticated": false,
      "id": null,
      "role": null
    }
  };

  Middleware get middleware {
    return (Handler innerHandler) {
      return (Request request) async {
        var db = await Database.db;
        final authorizationHeader = request.headers['authorization'];
        if (authorizationHeader == null || authorizationHeader.isEmpty || !authorizationHeader.startsWith("Bearer ")) {
          return innerHandler(request.change(context: _unauthenticated));
        }
        final accessToken = authorizationHeader.substring(7);
        var response = await db.execute(
            Sql.named("SELECT id, role FROM users WHERE access_token = @accessToken"),
            parameters: {
              "accessToken": accessToken,
            }
        );
        if (response.isEmpty) {
          return innerHandler(request.change(context: {
            "user": {
              "authenticated": false,
              "id": null,
              "role": null,
            },
          }));
        }
        var user = response.first.toColumnMap();
        return innerHandler(request.change(context: {
          "user": {
            "authenticated": true,
            "id": user["id"],
            "role": user["role"].asString,
          },
        }));
      };
    };
  }
}