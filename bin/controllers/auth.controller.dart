import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

import '../backend.dart';
import '../utils/validators.dart';

/// Handles all user authentication and authorization
class AuthController {
  /// Sign up a new user
  ///
  /// Request data:
  /// {
  ///   "email": "test@gmai.com,
  ///   "password": "password123",
  ///   "accountType": "user"
  /// }
  ///
  /// Response data:
  /// {
  ///  "id": 1,
  ///  "accessToken": "token"
  /// }
  static Future<Response> signup(Request request) async {
    var db = await Database.db;
    var json = request.context['json'] as Map;

    // validate parameters
    var email = json['email'];
    if (email is! String || !Validators.validateEmail(email)) {
      return Response.badRequest(body: 'Invalid email');
    }
    var password = json['password'];
    if (password is! String) {
      return Response.badRequest(body: 'Invalid password');
    }
    if (password.length < 8) {
      return Response.badRequest(body: 'Password must be at least 8 characters');
    }
    if (!Validators.validatePassword(password)) {
      return Response.badRequest(body: 'Password must contain at least one uppercase letter, one lowercase letter, one number, and one special character');
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
    final String hashed = BCrypt.hashpw(password, BCrypt.gensalt());
    final String accessToken = _generateAccessToken();

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

  /// Login a user
  ///
  /// Request data:
  /// {
  ///   "email": "test@gmail.com"
  ///   "password": "password123"
  /// }
  ///
  /// Response data:
  /// {
  ///  "id": 1,
  ///  "role": "user",
  ///  "accessToken": "token"
  /// }
  static Future<Response> login(Request request) async {
    var db = await Database.db;
    var json = request.context['json'] as Map;

    // validate parameters
    var email = json['email'];
    if (email is! String || !Validators.validateEmail(email)) {
      return Response.badRequest(body: 'Invalid email');
    }
    var password = json['password'];
    if (password is! String) {
      return Response.badRequest(body: 'Invalid password');
    }

    // fetch user from database
    final fetchPasswordResponse = await db.execute(
        Sql.named("SELECT id, role, password_hash FROM users WHERE email = @email LIMIT 1;"),
        parameters: {
          'email': email,
        }
    );
    if (fetchPasswordResponse.isEmpty) {
      return Response.notFound('User not found');
    }
    final fetchPasswordResponseMap = fetchPasswordResponse.first.toColumnMap();

    // check password
    final passwordHash = fetchPasswordResponseMap['password_hash'];
    if (!BCrypt.checkpw(password, passwordHash)) {
      return Response.unauthorized('Incorrect password');
    }

    // generate access token and update
    final accessToken = _generateAccessToken();
    await db.execute(
        Sql.named("UPDATE users SET access_token = @access_token WHERE id = @id;"),
        parameters: {
          'access_token': accessToken,
          'id': fetchPasswordResponseMap['id'],
        }
    );

    return Response.ok(jsonEncode({
      'id': fetchPasswordResponseMap['id'],
      'role': fetchPasswordResponseMap['role'].asString,
      'accessToken': accessToken,
    }));
  }

  /// Generate a secure access token 32 chars long
  static String _generateAccessToken() {
    const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    final token = List.generate(32, (index) => chars[random.nextInt(chars.length)]).join();
    return token;
  }
}