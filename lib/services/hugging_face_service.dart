import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class HuggingFaceService {
  final String apiKey = dotenv.get('HUGGING_FACE_TOKEN', fallback: "");
  final String baseUrl = "https://api-inference.huggingface.co/models";

  Map<String, String> get headers => {
    "Authorization": "Bearer $apiKey",
    "Content-Type": "application/json",
  };

  /// Summarization
  Future<String> summarizeText(String text) async {
    final url = Uri.parse("$baseUrl/facebook/bart-large-cnn");
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"inputs": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty && data[0]['summary_text'] != null) {
        return data[0]['summary_text'];
      } else {
        throw Exception("Unexpected response format for summarization");
      }
    } else {
      throw Exception("Failed to summarize text: ${response.body}");
    }
  }

  /// Keyword Extraction using NER
  Future<List<String>> extractKeywords(String text) async {
    final url = Uri.parse(
      "$baseUrl/dbmdz/bert-large-cased-finetuned-conll03-english",
    );
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"inputs": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        Set<String> keywords = {};
        for (var entity in data) {
          if (entity['entity_group'] != null && entity['word'] != null) {
            String word = entity['word'].toString().replaceAll('##', '').trim();
            if (word.isNotEmpty && word.length > 2) {
              keywords.add(word);
            }
          }
        }
        return keywords.toList();
      }
      return [];
    } else {
      return _extractKeywordsLocally(text);
    }
  }

  /// Fallback local keyword extraction
  List<String> _extractKeywordsLocally(String text) {
    final words = text.toLowerCase().split(RegExp(r'\W+'));
    final stopWords = {
      'the',
      'is',
      'at',
      'which',
      'on',
      'and',
      'a',
      'to',
      'are',
      'as',
      'was',
      'were',
      'been',
      'be',
      'have',
      'has',
      'had',
      'do',
      'does',
      'did',
      'will',
      'would',
      'should',
      'could',
      'can',
      'may',
      'might',
      'must',
      'shall',
      'of',
      'in',
      'for',
      'with',
      'by',
    };

    final keywords =
        words
            .where((word) => word.length > 3 && !stopWords.contains(word))
            .toSet()
            .take(10)
            .toList();

    return keywords;
  }

  /// Action Item Extraction
  Future<List<String>> extractActionItems(String text) async {
    final actionPatterns = [
      RegExp(r'need to\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'must\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'should\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'have to\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'will\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'going to\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'plan to\s+([^.!?]*)', caseSensitive: false),
      RegExp(r'remind.*to\s+([^.!?]*)', caseSensitive: false),
    ];

    List<String> actionItems = [];

    for (var pattern in actionPatterns) {
      final matches = pattern.allMatches(text);
      for (var match in matches) {
        if (match.group(1) != null) {
          String action = match.group(1)!.trim();
          if (action.isNotEmpty && action.length > 3) {
            actionItems.add(action);
          }
        }
      }
    }

    return actionItems.isEmpty
        ? ["No specific action items found"]
        : actionItems;
  }

  /// Question Answering
  Future<String> answerQuestion(String context, String question) async {
    final url = Uri.parse("$baseUrl/deepset/roberta-base-squad2");
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        "inputs": {"question": question, "context": context},
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['answer'] ?? "No answer found in the provided context.";
    } else {
      throw Exception("Failed to answer question: ${response.body}");
    }
  }

  /// Sentiment Analysis
  Future<String> analyzeSentiment(String text) async {
    final url = Uri.parse(
      "$baseUrl/cardiffnlp/twitter-roberta-base-sentiment-latest",
    );
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"inputs": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List &&
          data.isNotEmpty &&
          data[0] is List &&
          data[0].isNotEmpty) {
        String label = data[0][0]['label'];
        switch (label.toLowerCase()) {
          case 'label_0':
          case 'negative':
            return 'negative';
          case 'label_1':
          case 'neutral':
            return 'neutral';
          case 'label_2':
          case 'positive':
            return 'positive';
          default:
            return label.toLowerCase();
        }
      }
    }

    return _analyzeSentimentLocally(text);
  }

  /// Simple local sentiment analysis as fallback
  String _analyzeSentimentLocally(String text) {
    final positiveWords = [
      'good',
      'great',
      'excellent',
      'amazing',
      'wonderful',
      'fantastic',
      'love',
      'like',
      'happy',
      'excited',
      'awesome',
      'perfect',
    ];
    final negativeWords = [
      'bad',
      'terrible',
      'awful',
      'hate',
      'dislike',
      'horrible',
      'disgusting',
      'angry',
      'frustrated',
      'disappointed',
      'worst',
    ];

    final words = text.toLowerCase().split(RegExp(r'\W+'));
    int positiveCount = 0;
    int negativeCount = 0;

    for (String word in words) {
      if (positiveWords.contains(word)) positiveCount++;
      if (negativeWords.contains(word)) negativeCount++;
    }

    if (positiveCount > negativeCount) return 'positive';
    if (negativeCount > positiveCount) return 'negative';
    return 'neutral';
  }

  Future<String> translateText(
    String text, {
    String model = "Helsinki-NLP/opus-mt-en-fr",
  }) async {
    // Special handling for mBART model
    if (model == 'facebook/mbart-large-50-many-to-many-mmt') {
      return await _translateWithMBART(text);
    }

    final url = Uri.parse("$baseUrl/$model");
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({"inputs": text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List &&
          data.isNotEmpty &&
          data[0]['translation_text'] != null) {
        return data[0]['translation_text'];
      } else {
        throw Exception("Unexpected translation response format");
      }
    } else if (response.statusCode == 503) {
      throw Exception(
        "Translation model is loading. Please try again in a moment.",
      );
    } else if (response.statusCode == 400) {
      throw Exception(
        "Translation request failed. Please check your text length.",
      );
    } else {
      print("Translation error response: ${response.body}");
      throw Exception("Failed to translate text: ${response.statusCode}");
    }
  }

  /// Translation using mBART model for German and Italian
  Future<String> _translateWithMBART(String text) async {
    final url = Uri.parse("$baseUrl/facebook/mbart-large-50-many-to-many-mmt");

    // mBART uses different input format
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        "inputs": text,
        "parameters": {
          "src_lang": "en_XX", // English source
          "tgt_lang": "de_DE", // Will be dynamically set
        },
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List && data.isNotEmpty) {
        if (data[0]['translation_text'] != null) {
          return data[0]['translation_text'];
        } else if (data[0]['generated_text'] != null) {
          return data[0]['generated_text'];
        }
      }
      throw Exception("Unexpected mBART response format");
    } else if (response.statusCode == 503) {
      throw Exception("mBART model is loading. Please try again in a moment.");
    } else {
      print("mBART translation error: ${response.body}");
      throw Exception("Failed to translate with mBART: ${response.statusCode}");
    }
  }

  Map<String, String> getAvailableTranslations() {
    return {
      'french': 'Helsinki-NLP/opus-mt-en-fr',
      'spanish': 'Helsinki-NLP/opus-mt-en-es',
      'german': 'facebook/mbart-large-50-many-to-many-mmt',
    };
  }
}
