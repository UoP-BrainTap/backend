import 'package:postgres/postgres.dart';

import '../backend.dart';
import './question-structs.dart';

class QuestionAPI {
  static Future<Question> getQuestion(int id) async {
    var db = Database.db;
    var questionData = await db.execute(
        Sql.named(
            "SELECT id, question, question_type, owner_id "
            "FROM questions "
            "WHERE id = @id;"
        ),
        parameters: {'id': id});
    if (questionData.isEmpty) {
      throw Exception('Question not found');
    }
    var questionMapped = questionData.first.toColumnMap();
    questionMapped['question_type'] = questionMapped['question_type'].asString;
    var question = Question.fromMap(questionMapped);
    question = await getQuestionData(question);
    return question;
  }

  static Future<Question<QuestionData>> getQuestionData(Question question) async {
    var db = Database.db;
    if (question.questionType == QuestionType.multipleChoice) {
      var questionData = await db.execute(
          Sql.named(
              "SELECT id, question_id, option_text, is_correct "
              "FROM multiple_choice_options "
              "WHERE question_id = @id;"
          ),
          parameters: {'id': question.id});
      if (questionData.isEmpty) {
        throw Exception('Question data not found');
      }
      question.questionData = MultipleChoiceQuestionData.fromMap(questionData.map((row) {
        return row.toColumnMap();
      }).toList());
    }
    return question;
  }
}
