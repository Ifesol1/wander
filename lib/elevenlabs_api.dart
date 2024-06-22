import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';

class ElevenLabsAPI {
  final String apiKey;
  AudioPlayer? _audioPlayer;

  ElevenLabsAPI(this.apiKey);

  Future<List<Map<String, String>>> getVoices() async {
    final url = Uri.parse('https://api.elevenlabs.io/v1/voices');
    final response = await http.get(url, headers: {
      'Accept': 'application/json',
      'xi-api-key': apiKey,
    });

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return (data['voices'] as List).map<Map<String, String>>((voice) {
        return {
          'id': voice['voice_id'] as String,
          'name': voice['name'] as String,
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch voices');
    }
  }

  Future<void> textToSpeech(String voiceId, String text) async {
    final url = Uri.parse('https://api.elevenlabs.io/v1/text-to-speech/$voiceId/stream?optimize_streaming_latency=5');
    final response = await http.post(url,
        headers: {
          'Accept': 'application/json',
          'xi-api-key': apiKey,
          'Content-Type': 'application/json'
        },
        body: json.encode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.8,
            'style': 0.0,
            'use_speaker_boost': true
          }
        }));

    if (response.statusCode == 200) {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/output.mp3';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      // Stop any previous audio playback
      await _audioPlayer?.stop();

      // Play the audio
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.play(DeviceFileSource(filePath));
    } else {
      throw Exception('Failed to convert text to speech');
    }
  }

  Future<void> stopSpeech() async {
    await _audioPlayer?.stop();
  }
}
