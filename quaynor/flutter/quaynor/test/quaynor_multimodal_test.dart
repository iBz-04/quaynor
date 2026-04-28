@Timeout(Duration(seconds: 600))
import 'package:quaynor/quaynor.dart' as quaynor;
import 'package:test/test.dart';
import 'dart:io';

void main() {
  group('Multimodal tests', () {
    final modelPath = Platform.environment["TEST_MULTIMODAL_MODEL"];
    final mmprojPath = Platform.environment["TEST_MULTIMODAL_MMPROJ"];
    final imagePath = '${Directory.current.path}/test/dog.png';

    setUpAll(() async {
      await quaynor.Quaynor.init();
    });

    test('askWithPrompt with text only', () async {
      if (modelPath == null) return;

      final chat = await quaynor.Chat.fromPath(
        modelPath: modelPath,
        projectionModelPath: mmprojPath,
        systemPrompt: "",
        contextSize: 2048,
        templateVariables: {"enable_thinking" : false},
      );

      final prompt = quaynor.Prompt([
        quaynor.TextPart("What is the capital of France?"),
      ]);

      final response = await chat.askWithPrompt(prompt).completed();
      expect(response, contains("Paris"));
    });

    test('askWithPrompt with image and text', () async {
      if (modelPath == null || mmprojPath == null) return;

      final chat = await quaynor.Chat.fromPath(
        modelPath: modelPath,
        projectionModelPath: mmprojPath,
        systemPrompt: "",
        contextSize: 4096,
        templateVariables: {"enable_thinking" : false},
      );

      final prompt = quaynor.Prompt([
        quaynor.TextPart(
          "Describe what animal is in this image in one word. Do not focus on the age of the animal.",
        ),
        quaynor.ImagePart(imagePath),
      ]);

      final response = await chat.askWithPrompt(prompt).completed();
      expect(response.toLowerCase(), contains("dog"));
    });
  });
}
