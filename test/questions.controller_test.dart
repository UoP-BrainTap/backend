import 'dart:convert';

import 'package:test/test.dart';
import 'package:shelf/shelf.dart';

import '../bin/controllers/questions.controller.dart';

void main() {
  group('Question Controller', () {
    test('Get User Questions', () async {
      var response = await QuestionController.getUserQuestions(
          Request('GET', Uri.parse('http://localhost:8080/question/user/1'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true
            }
          }), '1');
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
      var data = jsonDecode(body);
      expect(data, isNotNull);
      expect(data.runtimeType, List);
    });

    test('Get invalid user ID', () async {
      var response = await QuestionController.getUserQuestions(
          Request('GET', Uri.parse('http://localhost:8080/question/user/999'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true
            }
          }), '999');
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 403);
    });

    test('Get Question Data', () async {
      var response = await QuestionController.getQuestionData(
          Request('GET', Uri.parse('http://localhost:8080/question/1'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true
            }
          }), '1');
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
      var data = jsonDecode(body);
      expect(data, isNotNull);
      expect(data['id'], 1);
    });

    test('Get invalid question ID', () async {
      var response = await QuestionController.getQuestionData(
          Request('GET', Uri.parse('http://localhost:8080/question/999'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true
            }
          }), '999');
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 404);
    });

    test('Create multiple choice question', () async {
      var response = await QuestionController.createMultipleChoiceQuestion(
          Request('POST', Uri.parse('http://localhost:8080/question/multiple-choice'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true,
              'role': 'lecturer'
            },
            'json': {
              'question-title': 'Sample Question',
              'options': [
                {'option-text': 'Option 1', 'is-correct': true},
                {'option-text': 'Option 2', 'is-correct': false}
              ]
            }
          }));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 200);
    });

    test('Create question with invalid data', () async {
      var response = await QuestionController.createMultipleChoiceQuestion(
          Request('POST', Uri.parse('http://localhost:8080/question/multiple-choice'),
          context: {
            'user': {
              'id': 1,
              'authenticated': true,
              'role': 'lecturer'
            },
            'json': {
              'question-title': '',
              'options': [
                {'option-text': '', 'is-correct': true}
              ]
            }
          }));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 400);
    });

    test('Create question without authentication', () async {
      var response = await QuestionController.createMultipleChoiceQuestion(
          Request('POST', Uri.parse('http://localhost:8080/question/multiple-choice'),
          context: {
            'user': {
              'authenticated': false
            },
            'json': {
              'question-title': 'Sample Question',
              'options': [
                {'option-text': 'Option 1', 'is-correct': true},
                {'option-text': 'Option 2', 'is-correct': false}
              ]
            }
          }));
      var body = await response.readAsString();
      printOnFailure(body);
      expect(response.statusCode, 403);
    });
  });
}