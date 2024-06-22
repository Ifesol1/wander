// image_generator.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class ImageGenerator {
  final String apiKey;

  ImageGenerator(this.apiKey);

  Future<File> generateImage(String prompt, {String outputFormat = 'jpeg'}) async {
    print('prompt: $prompt');
    final uri = Uri.parse("https://api.stability.ai/v2beta/stable-image/generate/sd3");
    final headers = {
      'authorization': 'Bearer $apiKey',
      'accept': 'image/*',
    };
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(headers)
      ..fields['prompt'] = prompt
      ..fields['aspect_ratio'] = '9:16'
      ..fields['output_format'] = outputFormat;


    final response = await request.send();
    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/generated_image.$outputFormat');
      await response.stream.pipe(file.openWrite());
      return file;
    } else {
      throw Exception('Failed to generate image: ${response.reasonPhrase}');
    }
  }
}
