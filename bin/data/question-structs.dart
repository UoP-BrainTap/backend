enum QuestionType {
  multipleChoice("Multiple Choice"),
  shortText("Short Text");

  final String name;

  const QuestionType(this.name);

  static QuestionType fromString(String type) {
    switch (type) {
      case "multiple_choice":
        return QuestionType.multipleChoice;
      case "short_text":
        return QuestionType.shortText;
      default:
        throw Exception("Unknown question type: $type");
    }
  }
}

class Question<T extends QuestionData> {
  final int? id;
  final int? ownerId;
  final String question;
  final QuestionType questionType;
  T? questionData;

  Question({
    this.id,
    this.ownerId,
    required this.question,
    required this.questionType,
    this.questionData,
  });

  static Question<QuestionData> fromMap(Map data) {
    return Question(
      id: data['id'],
      ownerId: data['owner_id'],
      question: data['question'],
      questionType: QuestionType.fromString(data['question_type'])
    );
  }
}

abstract class QuestionData {}

class MultipleChoiceQuestionData extends QuestionData {
  final List<MultipleChoiceOptionData> options;

  MultipleChoiceQuestionData({required this.options});

  static MultipleChoiceQuestionData fromMap(List data) {
    var multipleChoiceOptions = data.map((option) => MultipleChoiceOptionData(id: option['id'], text: option['option_text'], isCorrect: option['is_correct'])).toList();
    return MultipleChoiceQuestionData(options: multipleChoiceOptions);
  }
}

class MultipleChoiceOptionData {
  final int id;
  final String text;
  final bool isCorrect;

  MultipleChoiceOptionData({required this.id, required this.text, required this.isCorrect});
}