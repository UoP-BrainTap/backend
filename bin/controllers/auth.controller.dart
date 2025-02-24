import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../backend.dart';
import '../utils/validators.dart';

class AuthController {
  static Future<Response> signup(Request request) async {
    var db = Database.db;
    var json = request.context['json'] as Map;
    var email = json['email'];

    // validate parameters
    if (email is! String || !Validators.validateEmail(email)) {
      return Response.badRequest(body: 'Invalid email');
    }
    var password = json['password'];
    if (password is! String) {
      return Response.badRequest(body: 'Invalid password');
    }
    var accountType = json['accountType'];
    if (accountType is! String ||
        !Validators.validateAccountType(accountType)) {
      return Response.badRequest(body: 'Invalid account type');
    }

    // check if user already exists
    var initialCheckResponse = await db.execute(
        Sql.named(
            "SELECT EXISTS(SELECT 1 FROM users WHERE email = @email) AS exists;"),
        parameters: {
          'email': json['email'],
        }
    );
    final initialCheckResponseMap = initialCheckResponse.first.toColumnMap();
    if (initialCheckResponseMap['exists']) {
      return Response(409, body: 'User already exists');
    }

    // hash password and generate access token
    final String hashed = BCrypt.hashpw('password', BCrypt.gensalt());
    final String accessToken = _generateAccessToken();
    print(accessToken.length);

    // insert user
    var insertUserResponse = await db.execute(
        Sql.named(
            "WITH existing_user AS ("
                "   SELECT id, email FROM users WHERE email = @email"
                ")"
                "INSERT INTO users (email, password_hash, role, access_token)"
                "SELECT @email, @hash, @role, @access_token "
                "WHERE NOT EXISTS (SELECT 1 FROM existing_user)"
                "RETURNING id;"
        ),
        parameters: {
          'email': email,
          'hash': hashed,
          'role': accountType,
          'access_token': accessToken,
        }
    );
    final insertUserResponseMap = insertUserResponse.first.toColumnMap();
    if (insertUserResponseMap['id'] == null) {
      return Response.internalServerError(body: 'Failed to insert user');
    }
    return Response.ok(jsonEncode({
      'id': insertUserResponseMap['id'],
      'accessToken': accessToken,
    }));
  }

  /// Generate a secure access token
  static String _generateAccessToken() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final token = List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
    return token;
  }
}