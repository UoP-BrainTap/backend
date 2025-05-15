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

class SessionUser {
  int id;
  int? userId;
  String? anonymousId;
  WebSocketChannel? socket;

  SessionUser({required this.id, this.userId, this.anonymousId});

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

class Session {
  int ownerId;
  int sessionCode;
  int? questionId;
  bool active = true;
  Set<SessionUser> users = {};
  late int sessionId;
  late WebSocketChannel lectSocket;

  Session(this.ownerId) : sessionCode = Random().nextInt(900000) + 100000;

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

  Future<SessionUser> join({int? userId, String? anonymousId}) async {
    if (userId == null && anonymousId == null) {
      throw Exception('User ID or Anonymous ID must be provided');
    }
    for (var user in users) {
      if (user.userId == userId && userId != null ||
          user.anonymousId == anonymousId && anonymousId != null) {
        throw Exception('User already joined the session');
      }
    }
    var db = await Database.db;
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

  void answerMultipleChoiceQuestion(
      SessionUser user, Set<int> optionIds) async {
    if (questionId == null) {
      throw Exception('Question not set');
    }
    Question question = await QuestionAPI.getQuestion(questionId!);
    if (question.questionType != QuestionType.multipleChoice) {
      throw Exception('Question is not a multiple choice question');
    }
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

  void closeSession() async {
    var db = await Database.db;
    db.execute(
        Sql.named("UPDATE sessions "
            "SET active = FALSE "
            "WHERE id = @sessionId;"),
        parameters: {'sessionId': sessionId});
    active = false;
  }

  void broadcastMessage(String message) {
    for (var user in users) {
      if (user.socket != null) {
        print("SENDING TO USER");
        user.socket!.sink.add(message);
      }
    }
  }

  SessionUser getUser(int id) {
    for (var user in users) {
      if (user.id == id) {
        return user;
      }
    }
    throw Exception('User not found');
  }
}

class SessionController {
  static Map<int, Session> sessions = {};

  static var socket = webSocketHandler((socket, _) {
    socket.stream.listen((message) {
      var data = jsonDecode(message);
      print(data);
      if (data['type'] == 'join') {
        var code = data['session_code'];
        var sessionUserId = data['session_user_id'];
        var session = _getSession(code);
        if (session == null) {
          socket.sink.add(
              jsonEncode({'type': 'error', 'message': 'Session not found'}));
          socket.sink.close();
          return;
        }
        for (var user in session.users) {
          if (user.id == sessionUserId) {
            user.addSocket(socket);
            return;
          }
        }
      } else if (data['type'] == 'lect_join') {
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
        var code = data['session_code'];
        var session = _getSession(code);
        session?.lectSocket = socket;
      }
    });
  });

  static Session? _getSession(int code) {
    for (var value in sessions.values) {
      if (value.sessionCode == code) {
        return value;
      }
    }
  }

  static Future<Response> newSession(Request request) async {
    var user = request.context['user'] as Map;
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    if (user['role'] != 'lecturer') {
      return Response.forbidden('User not authorized');
    }
    var session = Session(user['id']);
    await session.init();
    sessions[session.sessionId] = session;
    return Response.ok(jsonEncode({
      'session_code': session.sessionCode,
      'session_id': session.sessionId
    }));
  }

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

  static Future<Response> setActiveQuestionId(
      Request request, String code) async {
    var user = request.context['user'] as Map;
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    if (user['role'] != 'lecturer') {
      return Response.forbidden('User not authorized');
    }
    var session = _getSession(int.parse(code));
    if (session == null) {
      print('session is null');
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
    if (session.ownerId != user['id']) {
      return Response.forbidden('User is not the owner of the session');
    }
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
    session.setQuestionId(questionId);
    return Response.ok(jsonEncode({'message': 'Question set successfully'}));
  }

  static Future<Response> submitMultiChoiceAnswer(
      Request request, String code) async {
    var data = request.context['json'] as Map;
    var session = _getSession(int.parse(code));
    if (session == null) {
      return Response.notFound('Session not found');
    }
    if (!session.active) {
      return Response.forbidden('Session is not active');
    }
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
    session.answerMultipleChoiceQuestion(
        session.getUser(userSessionId), selectedOptions.toSet().cast<int>());
    return Response.ok(
        jsonEncode({'message': 'Answer submitted successfully'}));
  }
}
