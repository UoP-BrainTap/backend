import 'dart:convert';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import '../backend.dart';

/// Handles question-related requests
class QuestionController {

  /// Returns a list of questions for the requested user. Must be authenticated
  /// and can only get their own questions. Must be authenticated
  ///
  /// [id] is the user ID that you want to get questions for
  ///
  /// response data:
  /// [
  ///  {
  ///   "id": 1,
  ///   "question": "What is your name?",
  ///   "question_type": "multiple_choice"
  ///   },
  ///   ...
  /// ]
  static Future<Response> getUserQuestions(Request request, String id) async {
    var user = request.context['user'] as Map;
    // Check if user is authenticated
    var userId = user['id'];
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    } else if (userId != int.parse(id)) {
      return Response.forbidden('User not authorized');
    }
    var db = await Database.db;

    // Get questions for the user
    var questions = await db.execute(Sql.named(
        "SELECT id, question, question_type "
        "FROM questions "
        "WHERE owner_id = @id "
        "AND deleted = FALSE;"
    ),
    parameters: {
      'id': userId
    });

    // map questions to json for response
    var questionsMapped = questions.map((row) {
      var columns = row.toColumnMap();
      return {
        'id': columns['id'],
        'question': columns['question'],
        'question_type': columns['question_type'].asString,
      };
    }).toList();

    return Response.ok(jsonEncode(questionsMapped));
  }

  /// Get question meta data by [id]
  /// This does not include the questions option data
  ///
  /// Response data:
  /// {
  ///  "id": 1,
  ///  "question": "What is your name?",
  ///  "question_type": "multiple_choice"
  ///  }
  static Future<Response> getQuestionData(Request request, String id) async {
    var questionId = int.parse(id);
    var db = await Database.db;
    // fetch question data from db
    var question = await db.execute(Sql.named(
        "SELECT id, question, question_type "
        "FROM questions "
        "WHERE id = @id;"
    ),
    parameters: {
      'id': questionId
    });
    if (question.isEmpty) {
      return Response.notFound('Question not found');
    }
    // map data for response
    var questionMapped = question.first.toColumnMap();
    questionMapped['question_type'] = questionMapped['question_type'].asString;
    return Response.ok(jsonEncode(questionMapped));
  }

  /// Deletes a question by [id]. Must be authenticated
  static Future<Response> deleteQuestion(Request request, String id) async {
    var user = request.context['user'] as Map;
    var userId = user['id'];
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    // check if if the user is the owner of the question
    var db = await Database.db;
    var authResponse = await db.execute(Sql.named(
        "SELECT id FROM questions "
        "WHERE id = @id "
        "AND owner_id = @owner_id "
        "AND deleted = FALSE;",
    ), parameters: {
      'id': id,
      'owner_id': userId
    });
    if (authResponse.isEmpty) {
      return Response.forbidden('User not authorized');
    }
    // delete the question
    await db.execute(Sql.named(
        "UPDATE questions "
        "SET deleted = TRUE "
        "WHERE id = @id;",
    ), parameters: {
      'id': id
    });
    return Response.ok(jsonEncode({
      'message': 'Question deleted successfully'
    }));
  }

  /// Creates a multiple choice question
  ///
  /// Request body:
  /// {
  /// "question-title": "What is your name?",
  /// "options": [
  ///   {
  ///   "option-text": "Option 1",
  ///   "is-correct": true
  ///   },
  ///   {
  ///   "option-text": "Option 2",
  ///   "is-correct": false
  ///   }
  ///  ]
  /// }
  ///
  /// Response data:
  /// {
  ///   "question_id": 1,
  /// }
  static Future<Response> createMultipleChoiceQuestion(Request request) async {
    var json = request.context['json'] as Map;
    var user = request.context['user'] as Map;

    // authentication check
    if (!user['authenticated']) {
      return Response.forbidden('User not authenticated');
    }
    if (user['role'] != 'lecturer') {
      return Response.forbidden('User not authorized');
    }
    // validate request body and sanitize
    String? title = json['question-title'];
    if (title == null || title.isEmpty) {
      return Response.badRequest(body: 'Question title is required');
    }
    if (title.length > 120) {
      return Response.badRequest(body: 'Question title is too long');
    }
    List<dynamic>? options = json['options'];
    if (options == null || options.length < 2) {
      return Response.badRequest(body: 'At least two option is required');
    }
    if (options.length > 6) {
      return Response.badRequest(body: 'Too many options');
    }
    for (var option in options) {
      String? optionText = option['option-text'];
      if (optionText == null || optionText.isEmpty) {
        return Response.badRequest(body: 'Option text is required');
      }
      if (optionText.length > 60) {
        return Response.badRequest(body: 'Option text is too long');
      }
      bool? isCorrect = option['is-correct'];
      if (isCorrect == null) {
        return Response.badRequest(body: 'Option is-correct is required');
      }
    }
    var db = await Database.db;
    var userId = user['id'];

    // add base question
    var questionIdResponse = await db.execute(Sql.named(
        "INSERT INTO questions (owner_id, question, question_type) "
        "VALUES (@owner_id, @question, 'multiple_choice') "
        "RETURNING id;",
    ), parameters: {
      'owner_id': userId,
      'question': title
    });
    var questionId = questionIdResponse.first.toColumnMap()['id'];

    // add multiple choice options
    for (var option in options) {
      String? optionText = option['option-text'];
      bool? isCorrect = option['is-correct'];
      await db.execute(Sql.named(
          "INSERT INTO multiple_choice_options (question_id, option_text, is_correct) "
          "VALUES (@question_id, @option_text, @is_correct);",
      ), parameters: {
        'question_id': questionId,
        'option_text': optionText,
        'is_correct': isCorrect
      });
    }

    return Response.ok(jsonEncode({
      'message': 'Question created successfully',
      'question_id': questionId
    }));
  }

  /// Get multiple choice question options by [id]
  ///
  /// Response data:
  /// [
  ///  {
  ///  "id": 1,
  ///  "option_text": "Option 1",
  ///  "is_correct": true
  ///  },
  ///  {
  ///  "id": 2,
  ///  "option_text": "Option 2",
  ///  "is_correct": false
  ///  }
  /// ]
  static Future<Response> getMultipleChoiceQuestionOptions(Request request, String id) async {
    var questionID = int.parse(id);
    var db = await Database.db;

    var options = await db.execute(Sql.named(
        "SELECT id, option_text, is_correct "
        "FROM multiple_choice_options "
        "WHERE question_id = @id;"
    ),
    parameters: {
      'id': questionID
    });

    if (options.isEmpty) {
      return Response.notFound('Question not found or not multiple choice');
    }

    var optionsMapped = options.map((row) {
      return row.toColumnMap();
    }).toList();

    return Response.ok(jsonEncode(optionsMapped));
  }
}