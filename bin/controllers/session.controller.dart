import 'dart:convert';
import 'dart:math';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../backend.dart';
import '../data/question-api.dart';
import '../data/question-structs.dart';

/// Represents a user in a session.
class SessionUser {
  int id;
  int? userId;
  String? anonymousId;
  WebSocketChannel? socket;

  /// [id] is the session user id of this user
  /// [userId] is the account id of this user if they have one
  /// [anonymousId] is the anonymous id of this user if they don't have an account
  /// Only one of [userId] or [anonymousId] will be used
  SessionUser({required this.id, this.userId, this.anonymousId});

  /// Adds a socket to this user and adds a listener to the socket
  void addSocket(WebSocketChannel socket) {
    this.socket = socket;
    socket.sink.add(jsonEncode({
      'type': 'joined',
    }));
    socket.stream.listen((message) {
      var data = jsonDecode(message);
      // stuff
    });
  }
}

/// Represents a session.
///
/// [ownerId] is the id of the user who created this session.
/// [sessionCode] is the code of the session.
/// [questionId] is the id of the question that is currently active.
/// [active] is a boolean that indicates if the session is active.
/// [users] is a set of users that are in this session.
/// [sessionId] is the id of the session in the database.
/// [lectSocket] is the socket of the lecturer.
class Session {
  int ownerId;
  int sessionCode;
  int? questionId;
  bool active = true;
  Set<SessionUser> users = {};
  late int sessionId;
  late WebSocketChannel lectSocket;

  /// [ownerId] is the id of the user who created this session
  Session(this.ownerId) : sessionCode = Random().nextInt(900000) + 100000;

  /// Adds the lecturers socket to this session and adds a listener
  void addSocket(WebSocketChannel socket) {
    lectSocket = socket;
    lectSocket.sink.add(jsonEncode({
      'type': 'joined',
    }));
    lectSocket.stream.listen((message) {
      var data = jsonDecode(message);
      // stuff
    });
  }

  /// Initializes the session in the database
  Future<void> init() async {
    var db = await Database.db;
    await db.execute(
        Sql.named("UPDATE sessions "
            "SET active = FALSE "
            "WHERE session_code = @code;"),
        parameters: {'code': sessionCode});

    await db.execute(
        Sql.named("INSERT INTO sessions (owner_id, session_code) "
            "VALUES (@ownerId, @code) "
            "RETURNING id;"),
        parameters: {'ownerId': ownerId, 'code': sessionCode}).then((value) {
      sessionId = value.first.toColumnMap()['id'];
    });
  }

  /// Joins a user to the session
  ///
  /// [userId] is the id of the user who is joining the session if they have one
  /// [anonymousId] is the anonymous id of the user who is joining the session
  /// if they don't have an account
  Future<SessionUser> join({int? userId, String? anonymousId}) async {
    if (userId == null && anonymousId == null) {
      throw Exception('User ID or Anonymous ID must be provided');
    }
    // check to see if the user is already in the session
    for (var user in users) {
      if (user.userId == userId && userId != null ||
          user.anonymousId == anonymousId && anonymousId != null) {
        throw Exception('User already joined the session');
      }
    }
    var db = await Database.db;

    // add user to the session
    var userData = await db.execute(
        Sql.named(
            "INSERT INTO session_members (session_id, user_id, anonymous_id) "
            "VALUES (@sessionId, @userId, @anonymousId) "
            "RETURNING id;"),
        parameters: {
          'sessionId': sessionId,
          'userId': userId,
          'anonymousId': anonymousId
        });
    var sessionUserId = userData.first.toColumnMap()['id'];
    var sessionUser = SessionUser(
        id: sessionUserId, userId: userId, anonymousId: anonymousId);
    users.add(sessionUser);
    return sessionUser;
  }

  /// Sets the active session in the session. Updates all connected students
  /// with new question [id]
  void setQuestionId(int id) async {
    questionId = id;
    var db = await Database.db;
    db.execute(
        Sql.named("INSERT INTO session_question (session_id, question_id) "
            "VALUES (@sessionId, @questionId);"),
        parameters: {'sessionId': sessionId, 'questionId': questionId});
    broadcastMessage(
        jsonEncode({'type': 'newquestion', 'question_id': questionId}));
  }

  /// Answers a multiple choice question
  /// [user] is the [SessionUser] who is answering the question
  /// [optionIds] is a collection of option ids that the user selected
  void answerMultipleChoiceQuestion(
      SessionUser user, Set<int> optionIds) async {
    if (questionId == null) {
      throw Exception('Question not set');
    }
    // get question info from the database
    Question question = await QuestionAPI.getQuestion(questionId!);
    if (question.questionType != QuestionType.multipleChoice) {
      throw Exception('Question is not a multiple choice question');
    }
    // check if the options are valid
    var availableOptions = (question.questionData as MultipleChoiceQuestionData)
        .options
        .map((option) => option.id);
    for (var value in optionIds) {
      if (!availableOptions.contains(value)) {
        throw Exception('Option $value is not available for this question');
      }
    }

    var db = await Database.db;
    var answerData = await db.execute(
        Sql.named(
            "INSERT INTO session_answers (session_id, session_member_id, question_id) "
            "VALUES (@sessionId, @sessionMemberId, @questionId) "
            "RETURNING id;"),
        parameters: {
          'sessionId': sessionId,
          'sessionMemberId': user.id,
          'questionId': questionId
        });
    var answerId = answerData.first.toColumnMap()['id'];

    for (var optionId in optionIds) {
      await db.execute(
          Sql.named(
              "INSERT INTO session_multiple_choice_answers (session_answer_id, option_id) "
              "VALUES (@sessionAnswerId, @optionId);"),
          parameters: {'sessionAnswerId': answerId, 'optionId': optionId});
    }

    lectSocket.sink.add(jsonEncode({
      'type': 'newanswer',
      'option_id': optionIds.toList()[0]
    }));
  }

  /// Closes the session and sets the active flag to false
  void closeSession() async {
    var db = await Database.db;
    db.execute(
        Sql.named("UPDATE sessions "
            "SET active = FALSE "
            "WHERE id = @sessionId;"),
        parameters: {'sessionId': sessionId});
    active = false;
  }

  /// Broadcasts a message to all users in the session
  /// [message] is the message to be sent
  void broadcastMessage(String message) {
    for (var user in users) {
      if (user.socket != null) {
        user.socket!.sink.add(message);
      }
    }
  }

  /// Gets a user from the session by their [id]
  SessionUser getUser(int id) {
    for (var user in users) {
      if (user.id == id) {
        return user;
      }
    }
    throw Exception('User not found');
  }
}

/// Handles all session endpoints
/// [sessions] a collection of all sessions
class SessionController {
  static Map<int, Session> sessions = {};

  /// The websocket handler listening for socket connections
  static var socket = webSocketHandler((socket, _) {
    socket.stream.listen((message) {
      var data = jsonDecode(message);
      // check for the type of message
      if (data['type'] == 'join') {
        // retrieve join information from the message
        var code = data['session_code'];
        var sessionUserId = data['session_user_id'];
        var session = _getSession(code);
        if (session == null) {
          socket.sink.add(
              jsonEncode({'type': 'error', 'message': 'Session not found'}));
          socket.sink.close();
          return;
        }
        // add the users socket to the session
        for (var user in session.users) {
          if (user.id == sessionUserId) {
            user.addSocket(socket);
            return;
          }
        }
      } else if (data['type'] == 'lect_join') {
        // lecturer joining the session
        var code = data['session_code'];
        var session = _getSession(code);
        if (session == null) {
          socket.sink.add(
              jsonEncode({'type': 'error', 'message': 'Session not found'}));
          socket.sink.close();
          return;
        }
        session.addSocket(socket);
      } else if (data['type'] == 'close') {
        // close the session
        var code = data['session_code'];
        var session = _getSession(code);
        session?.lectSocket = socket;
      }
    });
  });

  /// Gets a session by its [code]
  static Session? _getSession(int code) {
    for (var value in sessions.values) {
      if (value.sessionCode == code) {
        return value;
      }
    }
  }

  /// Gets a session by its id. Must be authenticated
  ///
  /// Response data:
  /// {
  ///  "session_code": 123456,
  ///  "session_id": 1
  /// }
  static Future<Response> newSession(Request request) async {
    var user = request.context['user'] as Map;
    // authentication check
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    if (user['role'] != 'lecturer') {
      return Response.forbidden('User not authorized');
    }
    // register the session
    var session = Session(user['id']);
    await session.init();
    sessions[session.sessionId] = session;
    return Response.ok(jsonEncode({
      'session_code': session.sessionCode,
      'session_id': session.sessionId
    }));
  }

  /// Joins a session by its [code]. Authentication is optional, an anonymous id
  /// will be generated if the user is not authenticated.
  ///
  /// Response data:
  /// {
  ///  "session_user_id": 1,
  ///  "anonymous_id": "12345678-1234-1234-1234-123456789012" (optional)
  /// }
  static Future<Response> joinSession(Request request, String code) async {
    var user = request.context['user'] as Map;
    int? userId = user['id'];
    String? anonymousId;
    if (!user['authenticated']) {
      anonymousId = Uuid().v4();
    }
    int sessionCode = int.parse(code);
    var session = _getSession(sessionCode);
    if (session == null) {
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
    try {
      var sessionUser =
          await session.join(userId: userId, anonymousId: anonymousId);
      return Response.ok(jsonEncode(
          {'session_user_id': sessionUser.id, 'anonymous_id': anonymousId}));
    } catch (e) {
      return Response.forbidden(e.toString());
    }
  }

  /// Get the active question id of the session [code]
  ///
  /// Response data:
  /// {
  /// "question_id": 1
  /// }
  static Future<Response> getActiveQuestionId(
      Request request, String code) async {
    var session = _getSession(int.parse(code));
    if (session == null) {
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
    if (session.questionId == null) {
      return Response.notFound('No active question');
    }
    return Response.ok(jsonEncode({'question_id': session.questionId}));
  }

  /// Sets the active question id of the session [code]. Must be authenticated
  ///
  /// Request data:
  /// {
  /// "question_id": 1
  /// }
  static Future<Response> setActiveQuestionId(
      Request request, String code) async {
    // authentication check
    var user = request.context['user'] as Map;
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    if (user['role'] != 'lecturer') {
      return Response.forbidden('User not authorized');
    }
    // check if the session is active and owned by the user
    var session = _getSession(int.parse(code));
    if (session == null) {
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
    if (session.ownerId != user['id']) {
      return Response.forbidden('User is not the owner of the session');
    }
    // check if the question id is valid
    var json = request.context['json'];
    if (json == null) {
      return Response.badRequest(body: 'No question ID provided');
    }
    json as Map;
    var questionId = json['question_id'];
    if (questionId == null) {
      return Response.badRequest(body: 'No question ID provided');
    }
    if (questionId is! int) {
      return Response.badRequest(body: 'Question ID must be an integer');
    }
    // set the question id
    session.setQuestionId(questionId);
    return Response.ok(jsonEncode({'message': 'Question set successfully'}));
  }

  /// Submits a multiple choice answer for the session [code]. Must provide
  /// session user id
  ///
  /// Request data:
  /// {
  /// "session_user_id": 1,
  /// "selected_options": [1, 2]
  /// }
  static Future<Response> submitMultiChoiceAnswer(
      Request request, String code) async {
    // check if the session is active
    var data = request.context['json'] as Map;
    var session = _getSession(int.parse(code));
    if (session == null) {
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
    // get session user id and selected options
    var userSessionId = data['session_user_id'];
    var selectedOptions = data['selected_options'];
    if (userSessionId == null || selectedOptions == null) {
      return Response.badRequest(
          body: 'No session user ID or selected options provided');
    }
    if (userSessionId is! int || selectedOptions is! List) {
      return Response.badRequest(
          body:
              'Session user ID must be an integer and selected options must be a list');
    }
    // answer the question
    session.answerMultipleChoiceQuestion(
        session.getUser(userSessionId), selectedOptions.toSet().cast<int>());
    return Response.ok(
        jsonEncode({'message': 'Answer submitted successfully'}));
  }
}
