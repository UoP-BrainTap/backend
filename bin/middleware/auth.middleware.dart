import 'package:postgres/postgres.dart';

import '../backend.dart';

import 'package:shelf/shelf.dart';

/// Checks all requests for authentication. If a bearer token is present in the
/// authorization header, it checks if the token is valid and if so, adds the
/// user information to the requests context.
class AuthMiddleware {
  /// Static value for all unauthenticated requests.
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
        // check to see if the authorization header is present
        final authorizationHeader = request.headers['authorization'];
        if (authorizationHeader == null || authorizationHeader.isEmpty || !authorizationHeader.startsWith("Bearer ")) {
          return innerHandler(request.change(context: _unauthenticated));
        }
        // check to see if the token is valid
        final accessToken = authorizationHeader.substring(7);
        var response = await db.execute(
            Sql.named("SELECT id, role FROM users WHERE access_token = @accessToken"),
            parameters: {
              "accessToken": accessToken,
            }
        );
        // if the token is not valid, return unauthenticated
        if (response.isEmpty) {
          return innerHandler(request.change(context: {
            "user": {
              "authenticated": false,
              "id": null,
              "role": null,
            },
          }));
        }
        // if the token is valid, get the user information
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