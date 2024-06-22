import 'dart:isolate';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'images_stitch.dart';  // Assuming this is a package or class available for stitching images.

void isolateEntry(SendPort sendPort) async {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  await for (final message in receivePort) {
    if (message is IsolateData) {
      final List<String> imagePaths = message.imagePaths;
      final String dirPath = message.dirPath;
      final String prompt = message.prompt;
      final SendPort replyPort = message.replyPort;

      final _imagesStitch = ImagesStitch();
      final List<String> yesAnswers = [];

      try {
        await _imagesStitch.stitchImages(
            imagePaths, dirPath, false, (stitchedImagesPath) async {
          final analysis = await analyzeImage(stitchedImagesPath, prompt);
          if (analysis.contains('yes') || analysis.contains('Yes')) {
            yesAnswers.add('yes: $analysis');
          }
        });

        replyPort.send(yesAnswers);
      } catch (e) {
        replyPort.send([]);
      }
    }
  }
}

class IsolateData {
  final List<String> imagePaths;
  final String dirPath;
  final String prompt;
  final SendPort replyPort;

  IsolateData(this.imagePaths, this.dirPath, this.prompt, this.replyPort);
}

Future<String> analyzeImage(String imagePath, String prompt) async {
  try {
    final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: 'AIzaSyDm6zkJpMgkVJu54_Gqxu_fvkDAsjPO-ns'
    );
    final imageBytes = await File(imagePath).readAsBytes();
    final imagePart = DataPart('image/jpeg', imageBytes);
    final promptPart = TextPart(prompt);
    final response = await model.generateContent(
        [Content.multi([promptPart, imagePart])]
    );
    return response.text ?? "No response from the model.";
  } catch (e) {
    print("Error analyzing image: $e");
    return 'Error analyzing image';
  }
}
