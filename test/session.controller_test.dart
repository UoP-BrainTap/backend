import 'dart:convert';

import 'package:test/test.dart';
import 'package:shelf/shelf.dart';

import '../bin/controllers/session.controller.dart';

void main() {
  /**
   * URIs may not be accurate (they are not used in controller code)
   */
  group('Sessions', () {
    group('Create session', () {
      test('Create session', () async {
        var response = await SessionController.newSession(
            Request('POST', Uri.parse('http://localhost:8080/sessions'),
                context: {
                  'user': {
                    'authenticated': true,
                    'id': 1,
                    'role': 'lecturer',
                  }
                }));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 200);
        var data = jsonDecode(body);
        expect(data['session_id'], isNotNull);
        expect(data['session_id'], isNotNaN);
        expect(data['session_id'].runtimeType, int);
        expect(data['session_code'], isNotNull);
        expect(data['session_code'], isNotNaN);
        expect(data['session_code'].runtimeType, int);
      });

      test('Create session unauthenticated', () async {
        var response = await SessionController.newSession(
            Request('POST', Uri.parse('http://localhost:8080/sessions'),
                context: {
                  'user': {
                    'authenticated': false,
                  }
                }));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 403);
      });

      test('Create session invalid role', () async {
        var response = await SessionController.newSession(
            Request('POST', Uri.parse('http://localhost:8080/sessions'),
                context: {
                  'user': {
                    'authenticated': true,
                    'role': 'student',
                  }
                }));
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 403);
      });
    });

    group('Join Session', () {
      test('Join session', () async {
        var createRes = await SessionController.newSession(
            Request('POST', Uri.parse('http://localhost:8080/sessions'),
                context: {
                  'user': {
                    'authenticated': true,
                    'id': 1,
                    'role': 'lecturer',
                  }
                }));
        var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
        var response = await SessionController.joinSession(
            Request('POST', Uri.parse('http://localhost:8080/sessions/join/12345'),
                context: {
                  'user': {
                    'authenticated': true,
                    'id': 1,
                    'role': 'student',
                  }
                }), code);
        var body = await response.readAsString();
        printOnFailure(body);
        expect(response.statusCode, 200);
        var data = jsonDecode(body);
        expect(data['session_user_id'], isNotNull);
        expect(data['session_user_id'], isNotNaN);
        expect(data['session_user_id'].runtimeType, int);
      });
    });

    test('Join session (logged out)', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      var response = await SessionController.joinSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions/join/12345'),
              context: {
                'user': {
                  'authenticated': false
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
      var data = jsonDecode(body);
      expect(data['session_user_id'], isNotNull);
      expect(data['session_user_id'], isNotNaN);
      expect(data['session_user_id'].runtimeType, int);
    });

    test('Join session (invalid code)', () async {
      var response = await SessionController.joinSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions/join/12345'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'student',
                }
              }), '9999999');
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 404);
    });
  });

  group('Active Quetsion', () {
    test('Get active question', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      // set question id
      await SessionController.setActiveQuestionId(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                },
                'json': {
                  'question_id': 1,
                }
              }), code);
      var response = await SessionController.getActiveQuestionId(
          Request('GET', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'student',
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
    });

    test('Set active question', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      var response = await SessionController.setActiveQuestionId(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                },
                'json': {
                  'question_id': 1,
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
    });

    test('Set active question (logged out)', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      var response = await SessionController.setActiveQuestionId(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': false,
                },
                'json': {
                  'question_id': 1,
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 403);
    });

    test('Set active question (no permission)', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      var response = await SessionController.setActiveQuestionId(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 2,
                  'role': 'lecturer',
                },
                'json': {
                  'question_id': 1,
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 403);
    });
  });

  group('Submit answer', () {
    test('Submit multiple choice answer', () async {
      var createRes = await SessionController.newSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                }
              }));
      var code = jsonDecode(await createRes.readAsString())['session_code'].toString();
      // set question id
      await SessionController.setActiveQuestionId(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'lecturer',
                },
                'json': {
                  'question_id': 1,
                }
              }), code);
      // join session
      var joinRes = await SessionController.joinSession(
          Request('POST', Uri.parse('http://localhost:8080/sessions/join/12345'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'student',
                }
              }), code);
      var userSessionId = jsonDecode(await joinRes.readAsString())['session_user_id'];
      var response = await SessionController.submitMultiChoiceAnswer(
          Request('POST', Uri.parse('http://localhost:8080/sessions/$code/question/answer'),
              context: {
                'user': {
                  'authenticated': true,
                  'id': 1,
                  'role': 'student',
                },
                'json': {
                  'session_user_id': userSessionId,
                  'selected_options': [1],
                }
              }), code);
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
    });
  });
}