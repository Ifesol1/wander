import 'dart:convert';
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'extensions/imagegen.dart';
import 'extensions/ebaylink.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
import 'package:validators/validators.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:ui' as ui;
import 'dart:async';
import 'dart:isolate';
import 'images_stitch.dart';  // Assuming this is a package or class available for stitching images.
import 'package:google_generative_ai/google_generative_ai.dart';
import 'elevenlabs_api.dart';
import 'package:image_picker/image_picker.dart';
import 'drawing_painter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'adventureclass.dart';
import 'extension_utils.dart'; // Import the utility functions
import 'package:image_gallery_saver/image_gallery_saver.dart';

class AdventurePage extends StatefulWidget {
  final List<CameraDescription> cameras;
  final Adventure? savedAdventure;

  const AdventurePage({Key? key, required this.cameras, this.savedAdventure}) : super(key: key);

  @override
  _AdventurePageState createState() => _AdventurePageState();
}

class _AdventurePageState extends State<AdventurePage> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  int _currentCameraIndex = 0;
  List<File> _capturedImages = [];
  Timer? _captureTimer;
  bool _isStarted = false;
  bool _longPressActive = false;
  XFile? _currentPhoto = null; // Make _currentPhoto nullable
  bool _isStitching = false;
  bool _istalking = false;
  Adventure? _currentAdventure;

  final _imagesStitch = ImagesStitch();
  List<File> _stitchedImages = [];
  final ElevenLabsAPI _elevenLabsAPI = ElevenLabsAPI(
      '1011ea8be9de4ee94b4a145ef85001a5'); // Replace with your actual API key
  String _selectedVoiceId = ''; // Assuming "adventurer" is the voice ID
  List<Map<String, String>> _availableVoices = [];
  bool _aiRequestHandled = false;
  bool _isCameraOn = false; // Track the camera state
  TextEditingController _adventureTypeController = TextEditingController();
  String role = '';
  String? _selectedVoiceName = 'Rachel';
  late GenerativeModel _model;
  late ChatSession _chatSession;
  bool _isPhotoMode = true; // Track the camera state
  List<Color> paletteColors = [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
    Colors.purple,
  ];
  List<List<Offset>> _drawings = [];
  List<Offset> _points = [];
  bool isDrawing = false; // State variable to track drawing mode

// Add a variable to hold the selected color
  Color selectedColor = Colors.red;


  @override

  void initState() {
    super.initState();

    _initializeCamera(widget.cameras[_currentCameraIndex]);
    initializeModel(savedAdventure: widget.savedAdventure);
    _fetchVoices(); // Fetch voices during initialization
  }

  @override

  void dispose() {
    _controller.dispose();
    _speech.stop();
    _captureTimer?.cancel();
    super.dispose();
  }
  Map<String, dynamic> contentToJson(Content content) {
    return {
      'role': content.role,
      'parts': content.parts.map((part) => partToJson(part)).toList(),
    };
  }

  Content contentFromJson(Map<String, dynamic> json) {
    return Content(
      json['role'] as String?,
      (json['parts'] as List<dynamic>).map((part) => partFromJson(part as Map<String, dynamic>)).toList(),
    );
  }

  Map<String, dynamic> partToJson(Part part) {
    if (part is TextPart) {
      return {
        'type': 'text',
        'text': part.text,
      };
    }
    if (part is DataPart) {
      return {
        'type': 'data',
        'mimeType': part.mimeType,
        'bytes': part.bytes, // Assuming Uint8List is serializable directly, if not, you may need base64 encoding
      };
    }
    if (part is FilePart) {
      return {
        'type': 'file',
        'uri': part.uri.toString(), // Convert Uri to String
      };
    }
    if (part is FunctionCall) {
      return {
        'type': 'functionCall',
        'name': part.name,
        'args': part.args,
      };
    }
    if (part is FunctionResponse) {
      return {
        'type': 'functionResponse',
        'name': part.name,
        'response': part.response,
      };
    }
    throw UnimplementedError('Part type not supported');
  }

  Part partFromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'text':
        return TextPart(json['text'] as String);
      case 'data':
        return DataPart(
          json['mimeType'] as String,
          Uint8List.fromList((json['bytes'] as List<dynamic>).cast<int>()), // Convert back to Uint8List
        );
      case 'file':
        return FilePart(Uri.parse(json['uri'] as String));
      case 'functionCall':
        return FunctionCall(
          json['name'] as String,
          (json['args'] as Map<String, dynamic>).cast<String, Object?>(),
        );
      case 'functionResponse':
        return FunctionResponse(
          json['name'] as String,
          (json['response'] as Map<String, dynamic>?)?.cast<String, Object?>(),
        );
      default:
        throw UnimplementedError('Part type not supported');
    }
  }


  Future<void> initializeModel({Adventure? savedAdventure}) async {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyDm6zkJpMgkVJu54_Gqxu_fvkDAsjPO-ns',
      generationConfig: GenerationConfig(maxOutputTokens: 325),
    );

    if (savedAdventure != null) {
      _currentAdventure = savedAdventure;
      // Deserialize chat history from savedAdventure
      final chatHistory = savedAdventure.chatHistory.map((json) => contentFromJson(json)).toList();
      _chatSession = await _model.startChat(history: chatHistory);
    } else {
      _chatSession = await _model.startChat(history: [
        Content.text(
          'You are $_selectedVoiceName, an AI adventure partner. You help the user answer questions and discover new things. Your current adventure is related to $role.',
        ),
      ]);
      _currentAdventure = Adventure(
        timestamp: DateTime.now().toString(),
        details: 'Initial adventure details',
        chatHistory: [],
      );
    }
  }

  void _initializeCamera(CameraDescription cameraDescription) {
    _controller = CameraController(cameraDescription, ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize();
    setState(() {});
  }

  void _switchCamera() {
    _currentCameraIndex = (_currentCameraIndex + 1) % widget.cameras.length;
    _initializeCamera(widget.cameras[_currentCameraIndex]);
  }

  void _startListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) => _onSpeechStatus(val),
        onError: (val) => print('onError: $val'),
      );
      if (available) {
        setState(() {
          _isListening = true;
          stopSpeaking();
          _istalking = true;

          _text = 'Listening...';
          _aiRequestHandled = false; // Reset the flag when starting to listen
        });
        _speech.listen(
          onResult: (val) {
            setState(() {
              _text = val.recognizedWords;
            });
            if (val.finalResult) {
              _handleFinalResult();
            }
          },
        );
        _startCapturing();
      }
    } else {
      _stopListening();
      _istalking = false;

    }
  }

  void _stopListening() {
    _speech.stop();
    _captureTimer?.cancel();
    setState(() {
      _isListening = false;
    });
  }

  void _startCapturing() {
    _captureTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
      if (!_isStitching && _isCameraOn &&   !_istalking) {
        await _captureFrame();
      }
    });
  }



  Future<DataPart> _combineImageWithDrawing(DataPart imageFile) async {
    final imageBytes = imageFile.bytes;
    final ui.Image baseImage = await decodeImageFromList(imageBytes);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = selectedColor
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle
          .stroke // Set the style to stroke to draw only the outline
      ..strokeWidth = 5.0; // Set a default stroke width or any value you prefer

    final Size size = Size(
        baseImage.width.toDouble(), baseImage.height.toDouble());

    // Draw the base image
    canvas.drawImage(baseImage, Offset.zero, Paint());

    // Define the offset for y-axis adjustment
    final double yOffset = -275; // Adjust this value as needed
    final double xOffset = 135; // Adjust this value as needed

    // Draw the drawings
    for (final points in _drawings) {
      if (points.isEmpty) continue;
      final path = Path()..moveTo(points.first.dx + xOffset, points.first.dy - yOffset);
      for (final point in points) {
        // Debug print statements

        path.lineTo(point.dx + xOffset, point.dy - yOffset);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final combinedImage = await picture.toImage(
        baseImage.width, baseImage.height);
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = path.join(directory.path, '${DateTime
        .now()
        .millisecondsSinceEpoch}_combined.jpg');
    final combinedImageFile = File(imagePath);

    final byteData = await combinedImage.toByteData(
        format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();

    await combinedImageFile.writeAsBytes(buffer);

    setState(() {
      _currentPhoto = XFile(combinedImageFile.path);
      if (_capturedImages.length > 16) {
        final oldImage = _capturedImages.removeAt(0);
        oldImage.delete();
      }
      _capturedImages.add(combinedImageFile);

      _drawings = [];
    });

    return DataPart('image/jpeg', buffer);
  }

  void _onSpeechStatus(String status) async {
    if ((status == 'done' || status == 'notListening') && !_aiRequestHandled) {
      _aiRequestHandled = true; // Ensure this block is only entered once
      if (_text == 'Listening...' ||
          _text == 'Sorry, I did not hear you clearly') {
        setState(() {
          _text = 'Sorry, I did not hear you clearly';
          speak('Sorry, I did not hear you clearly');
        });
        _stopListening();
      } else {
        _stopListening();
      }
    }
  }

  Future<void> _handleFinalResult() async {
    if (_text == 'Listening...' ||
        _text == 'Sorry, I did not hear you clearly') {
      setState(() {
        _text = 'Sorry, I did not hear you clearly';
        speak('Sorry, I did not hear you clearly');
      });
    } else {
      await _handleAiRequest();
    }
    _stopListening();
  }



  Future<void> _saveNewAdventure(Adventure adventure) async {
    final prefs = await SharedPreferences.getInstance();
    final adventuresJson = prefs.getStringList('savedAdventures') ?? [];
    final index = adventuresJson.indexWhere((jsonStr) {
      final savedAdventure = Adventure.fromJson(jsonDecode(jsonStr));
      return savedAdventure.timestamp == adventure.timestamp;
    });

    if (index != -1) {
      adventuresJson[index] = jsonEncode(adventure.toJson());
    } else {
      adventuresJson.add(jsonEncode(adventure.toJson()));
    }

    await prefs.setStringList('savedAdventures', adventuresJson);
  }

  Future<void> _saveModelState() async {
    final chatHistory = _chatSession.history.map((content) => contentToJson(content)).toList();
    if (_currentAdventure != null) {
      _currentAdventure!.chatHistory = chatHistory;
      await _saveNewAdventure(_currentAdventure!);
    }
  }
  bool _isValidURL(String url) {
    return isURL(url);
  }

  Future<void> createNewAdventure() async {
    _currentAdventure = Adventure(
      timestamp: DateTime.now().toString(),
      details: 'Adventure started at ${DateTime.now()}',
      chatHistory: [],
    );
    await _saveNewAdventure(_currentAdventure!);
  }
  Future<void> _fetchVoices() async {
    try {
      final voices = await _elevenLabsAPI.getVoices();
      setState(() {
        _availableVoices = voices;
        if (voices.isNotEmpty) {
          _selectedVoiceId = voices.first['id']!;
        }
      });
    } catch (e) {
      print("Error fetching voices: $e");
    }
  }

  Future<String> analyzeImage(String imagePath, String prompt) async {
    try {
      if (_isCameraOn || (_isPhotoMode && _currentPhoto != null)) {
        DataPart imagePart;

        final imageBytes = await File(imagePath).readAsBytes();
        if (_drawings.isNotEmpty) {
          imagePart =
          await _combineImageWithDrawing(DataPart('image/jpeg', imageBytes));
        } else {
          imagePart = DataPart('image/jpeg', imageBytes);
        }

        final promptPart = TextPart(prompt);
        var content = Content.multi([promptPart, imagePart]);
        final response = await _chatSession.sendMessage(content);

        await _saveModelState();

        return response.text ?? "No response from the model.";

      } else {
        var content = Content.text(prompt);

        final response = await _chatSession.sendMessage(content);
        await _saveModelState();

        return response.text ?? "No response from the model.";
      }
    } catch (e) {
      print("Error analyzing prompt: $e");
      return 'Error analyzing prompt';
    }
  }
  Future<void> _launchURL(String url) async {
    var uri = Uri.parse(url);

      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication, // Use this mode to open URLs in an external browser
      );

  }


  Future<void> _handleAiRequest() async {
    if (_text != 'Press the button and start speaking') {
      final prompt = _buildPrompt();
      final prevPrompt = _buildPrevPrompt();

      try {
        final decision = await analyzePrompt(_text);
        print('AI Decision: $decision');

        if (decision.contains('No')) {
          String imagePath;
          if (_capturedImages.isNotEmpty) {
            final latestImage = _capturedImages.last;
            imagePath = latestImage.path;
          } else {
            // Handle the case when _capturedImages is empty
            imagePath = ''; // or provide a default image path
          }

          if (imagePath.isNotEmpty) {
            final analysis = await analyzeImage(imagePath, prompt);
            setState(() {
              _text = analysis;
              speak(analysis);
            });
          } else {
            if (_isPhotoMode || _isCameraOn) {
              setState(() {
                String warning = 'I cannot see anything, try holding the camera button to snap or click on the livestream button. You can turn off the camera if you want to chat normally';
                _text = warning;
                speak(warning);
              });
            } else {
              final analysis = await analyzeImage(imagePath, prompt);
              setState(() {
                _text = analysis;
                speak(analysis);
              });
            }
          }

        } else if (decision.contains('On')) {
          _turnCameraOn();
          setState(() {
            _text = 'Camera turned on.';
            speak('Camera turned on.');
          });
        }else if (decision.contains('Link')) {
          bool isEnabled = await ExtensionUtils.isExtensionEnabled('ebaylink.dart');
          if (isEnabled) {
            String imagePath;
            String response = '';
            if (_capturedImages.isNotEmpty) {
              final latestImage = _capturedImages.last;
              imagePath = latestImage.path;
            } else {
              // Handle the case when _capturedImages is empty
              imagePath = ''; // or provide a default image path
            }

            if (imagePath.isNotEmpty) {
              final analysis = await analyzeImage(
                  imagePath, _buildLinkPrompt());
              setState(() {
                response = analysis;
                speak(analysis);
              });
            } else {
              if (_isPhotoMode || _isCameraOn) {
                setState(() {
                  String warning = 'I cannot see anything, try holding the camera button to snap or click on the livestream button. You can turn off the camera if you want to chat normally';
                  _text = warning;
                  speak(warning);
                });
              } else {
                final analysis = await analyzeImage(
                    imagePath, _buildLinkPrompt());
                setState(() {
                  response = analysis;
                  speak(analysis);
                });
              }
            }
            final ebayLinkGenerator = EbayLinkGenerator('IfeSolar-wander-PRD-807721e0a-1f819107');
            final link = await ebayLinkGenerator.generateLink(response);
            print('Generated eBay link: $link');
            setState(() {
              _text = link;
              speak('Camera turned on.');
            });
          } else{
            setState(() {
              _text = 'eBay Link extension is not enabled.';
              speak('eBay Link extension is not enabled.');
            });
          }
        } else if (decision.contains('Off')) {
          _turnCameraOff();
          setState(() {
            _text = 'Camera turned off.';
            speak('Camera turned off.');
          });
        } else  if (decision.contains('Imagegen')) {
          bool isEnabled = await ExtensionUtils.isExtensionEnabled('imagegen.dart');
          if (isEnabled) {
            String imageprompt = _text;
            setState(() {
              _text = 'Generating image.';
              speak('Generating image.');
            });
             await _generateImage(imageprompt);
            setState(() {
              _text = 'Image successfully generated.';
              speak('Image successfully generated.');
            });
          } else {
            setState(() {
              _text = 'Image generation extension is not enabled.';
              speak('Image generation extension is not enabled.');
            });
          }

        } else {
          setState(() {
            _text = decision;
            speak(decision);
          });
          if (decision.contains('Yes')) {
            await _stitchImagesAndAnalyze(prevPrompt);
          }
        }
      } catch (e) {
        print("Error analyzing prompt or image: $e");
      } finally {
        _isStitching = false;
      }
    }
  }

  // Initial color

// Add a method to handle color selection
  void selectColor(Color color) {
    setState(() {
      selectedColor = color;
    });
  }

  void _turnCameraOn() {
    if (!_isCameraOn) {
      _initializeCamera(widget.cameras[_currentCameraIndex]);
      _isCameraOn = true;
      _isPhotoMode = false;
      _drawings = [];
    }
  }

  void _turnCameraOff() {
    if (_isCameraOn) {
      _controller.dispose();
      _isCameraOn = false;
    }
  }

  void _onPhotoMode() {
    print( _chatSession.history.map((content) => content.toJson()).toList());
    if (!_isPhotoMode) {
      _initializeCamera(widget.cameras[_currentCameraIndex]);
      _currentPhoto = null;
      _isCameraOn = false;
      _isPhotoMode = true;
      _drawings = [];
    }
  }

  void _offPhotoMode() {
    if (_isPhotoMode) {
      _controller.dispose();
      _isPhotoMode = false;
    }
  }

  String _buildPrompt() {
    print(_text);
    return ' $_text';
  }


  String _buildPrevPrompt() {
    return ' $_text. Say "yes" if the image meets the prompt and "no" if it does not. "No" should be a single-word answer, while "yes" should contain the reason. Have over a 65 percent certainty.';
  }

  String _buildLinkPrompt() {
    return ' $_text. Say just the keyword or the product the user is requesting for';
  }
  Future<String> analyzePrompt(String prompt) async {
    try {
      final updatedPrompt = '''
Analyse this prompt: $prompt
Don't respond with any other thing apart from the options given!. 
Reply with:
- "End" if it involves ending an adventure,
- "Off" if it involves turning off the camera,
- "On" if it involves turning on the camera,
- "Imagegen" if it relates to generating an image.
- "Link" if it involves producing a link to a product.
- If previous images or frames are required, reply "Yes" and inform the user that previous images will be checked and analyzed, and this process may take some time. For example: "Yes, previous images will be checked and analyzed. This process may take some time."
- If a single image is sufficient and no other options apply, respond with "No."
- If you aren't certain, check again and if you feel like there's no other matching option then respond with "No."
Hint: The words "remember" or "looking for" usually require previous images.
Examples to consider:
1. "Turn off the camera" -> "Off"
2. "End the adventure" -> "end"
3. "Turn on the camera" -> "On"
4. "Remember the scene from before" -> "Yes"
5. "Look for a pattern in previous frames" -> "Yes"
6. "Capture the current view" -> "No"
7. "What is this" -> "No"
8. "Generate an image of the sunset" -> "Imagegen"
9. "Find a link to a product" -> "Link"


Don't respond with any other thing apart from the options given!. 

''';

      final content = [Content.text(updatedPrompt)];
      final response = await _model.generateContent(content);
      print('Response: ${response.text}');
      return response.text ?? '';
    } catch (e) {
      print("Error analyzing prompt: $e");
      return 'No'; // Default to 'No' if there's an error
    }
  }

  Future<void> _stitchImagesAndAnalyze(String prevPoint) async {
    if (_capturedImages.length >= 2) {
      try {
        setState(() {
          _isStitching = true;
        });
        print('Stitching images...');

        final List<String> imagePaths = _capturedImages.map((e) => e.path).toList();
        final dirPath = (await getApplicationDocumentsDirectory()).path;

        List<Future<void>> stitchAndAnalyzeFutures = [];

        for (int i = 0; i < imagePaths.length - 1; i += 2) {
          final pairPaths = imagePaths.sublist(i, i + 2);
          final pairDirPath = path.join(dirPath, '${DateTime.now().millisecondsSinceEpoch}_stitched_${i}.jpg');

          stitchAndAnalyzeFutures.add(_stitchAndAnalyzePair(pairPaths, pairDirPath, prevPoint, i ~/ 2));
        }

        await Future.wait(stitchAndAnalyzeFutures);
        print('All stitching and analysis done.');

        // Gathering all analyses results
        List<String> analyses = _stitchingAnalyses.where((analysis) => analysis.toLowerCase().contains('yes')).toList();

        // Analyze the final prompt
        print('Analyzing final prompt...');
        final answer = await analyzefinalPrompt(analyses.join('\n'), prevPoint);

        setState(() {
          _text = answer;
          speak(answer);
          _isStitching = false;
        });
        print('Final prompt analysis done.');

      } catch (e) {
        print("Error stitching images: $e");
        setState(() {
          _isStitching = false;
          _text = 'Error stitching images.';
        });
      }
    } else {
      setState(() {
        _text = 'Not enough images to stitch.';
      });
    }
  }

  Future<void> _stitchAndAnalyzePair(List<String> imagePaths, String dirPath, String prevPoint, int index) async {
    try {
      // Stitch pair of images
      final stitchedPath = await _runStitchInIsolate(imagePaths, dirPath);
      print('Stitched path: $stitchedPath');

      if (stitchedPath.isNotEmpty) {
        // Analyze the stitched image
        print('Analyzing stitched image...');
        final analysis = await analyzeImage(stitchedPath, prevPoint);

        // Add the analysis to the shared state
        if (analysis.toLowerCase().contains('yes')) {
          _stitchingAnalyses.add(analysis);
        }

        // Add the stitched image to the display list
        setState(() {
          _stitchedImages.add(File(stitchedPath));
        });

        // Print when analysis is done
        print('Analysis of pair $index done.');
      } else {
        print('Skipping analysis due to stitching error.');
      }
    } catch (e) {
      print("Error in stitching and analyzing pair: $e");
    }
  }

  Future<String> _runStitchInIsolate(List<String> imagePaths, String dirPath) async {
    final p = ReceivePort();
    await Isolate.spawn(_stitchInIsolate, p.sendPort);

    final sendPort = await p.first as SendPort;
    final response = ReceivePort();
    sendPort.send([imagePaths, dirPath, response.sendPort]);

    return await response.first as String;
  }

  static void _stitchInIsolate(SendPort sendPort) async {
    final p = ReceivePort();
    sendPort.send(p.sendPort);

    await for (final message in p) {
      final imagePaths = message[0] as List<String>;
      final dirPath = message[1] as String;
      final responseSendPort = message[2] as SendPort;

      try {
        final imagesStitch = ImagesStitch();
        await imagesStitch.stitchImages(imagePaths, dirPath, false, (stitchedImagePath) async {
          responseSendPort.send(stitchedImagePath);
        });
      } catch (e) {
        print("Error stitching image: $e");
        responseSendPort.send('');
      }
    }
  }

  final List<String> _stitchingAnalyses = [];



  Future<String> analyzefinalPrompt(String prompt, String mainprompt) async {
    try {
      final updatedPrompt = 'Restructure to provide a single sentence that provides a better meaning and information to answer the original prompt. $prompt. The original question or prompt by the user is $mainprompt';

      var content = Content.text(updatedPrompt);

      final response = await _chatSession.sendMessage(content);
      await _saveModelState();

      print('Response: ${response.text}');
      return response.text ?? '';
    } catch (e) {
      print("Error analyzing prompt: $e");
      return prompt; // Default to 'No' if there's an error
    }
  }

  Future<void> _clearSavedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final directoryPath = directory.path;
      final dir = Directory(directoryPath);
      if (dir.existsSync()) {
        dir.listSync().forEach((file) {
          if (file is File) {
            file.deleteSync();
          }
        });
      }
      setState(() {
        _capturedImages.clear();
      });
    } catch (e) {
      print(e);
    }
  }
  Future<void> _generateImage(String prompt) async {
    if (_isCameraOn) {
      _turnCameraOff();
      _offPhotoMode();
    }

    const String apiKey = 'sk-U5E1M0ducQce9nTnsOtQvVX6S2qj7ne5hrMDudx7dh4PV3hL';
    final imageGenerator = ImageGenerator(apiKey);

    try {
      final file = await imageGenerator.generateImage(prompt);
      final xFile = XFile(file.path);

      // Assuming _currentPhoto and savedImage are variables to store current and saved photos respectively
      setState(() {
        _currentPhoto = xFile; // Update current photo
        if (_capturedImages.length > 16) {
          final oldImage = _capturedImages.removeAt(0);
          oldImage.delete(); // Assuming oldImage has a delete method
        }
        _capturedImages.add(file); // Add the newly generated image to captured images
      });
      await _saveImageToGallery(file);

    } catch (e) {
      print('Error generating image: $e');
    }
  }
  Future<void> _saveImageToGallery(File file) async {
    try {
      final result = await ImageGallerySaver.saveFile(file.path);
      if (result['isSuccess']) {
        print('Image saved to gallery successfully.');
      } else {
        print('Error saving image to gallery.');
      }
    } catch (e) {
      print('Error saving image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    final pickedFile = await ImagePicker().pickImage(
        source: ImageSource.gallery);

    if (pickedFile != null) {
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg');
      final savedImage = await File(pickedFile.path).copy(imagePath);
      setState(() {
        _currentPhoto = pickedFile;
        if (_capturedImages.length > 16) {
          final oldImage = _capturedImages.removeAt(0);
          oldImage.delete();
        }
        _capturedImages.add(savedImage);
      });
    }
  }

  Future<void> _captureFrame() async {
    if (_isStitching) return;

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg');
      final savedImage = await File(image.path).copy(imagePath);

      setState(() {
        if (_capturedImages.length > 16) {
          final oldImage = _capturedImages.removeAt(0);
          oldImage.delete();
        }
        _capturedImages.add(savedImage);
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _savePicture() async {
    try {
      await _initializeControllerFuture;
      final XFile image = await _controller
          .takePicture(); // Use XFile for camera
      final directory = await getApplicationDocumentsDirectory();
      final imagePath = path.join(directory.path, '${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg');
      final savedImage = await File(image.path).copy(imagePath);

      setState(() {
        _currentPhoto = image;
        if (_capturedImages.length > 16) {
          final oldImage = _capturedImages.removeAt(0);
          oldImage.delete();
        }
        _capturedImages.add(savedImage); // Update _currentPhoto withf XFile
      });
    } catch (e) {
      print(e);
    }
  }

  void _startProcess() async {
    setState(() {
      _isStarted = true;
      _text = 'Press the button and start speaking';
    });
    _startCapturing();
  }

  Future<void> speak(String text) async {
    try {
      await _elevenLabsAPI.textToSpeech(_selectedVoiceId, text);
    } catch (e) {
      print("Error in speak: $e");
    }
  }
  Future<void> stopSpeaking() async {
    try {
      await _elevenLabsAPI.stopSpeech();
    } catch (e) {
      print("Error in stopSpeaking: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade200, Colors.teal.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _isStarted || widget.savedAdventure!= null? buildAdventureContent() : buildSetupContent(),
          ),
          if (_isStarted || widget.savedAdventure!= null)
          Positioned(
            top: 50, // Adjust the top position as needed
            left: 20, // Adjust the left position as needed
            right: 20, // Adjust the right position as needed
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 45,
                maxHeight: 100,
              ),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:  SingleChildScrollView(
    scrollDirection: Axis.vertical,
    child: GestureDetector(
    onTap: () {
    if (_isValidURL(_text)) {
    _launchURL(_text);
    } else {
    // Handle invalid URL case here
    print('Invalid URL');
    }
    },
    child: Text(
    _text,
    style: TextStyle(
    color: _isValidURL(_text) ? Colors.blue : Colors.white,
    fontSize: 16,
    ),
    ),
    ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdventureContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Stack(
            children: [
              _isCameraOn || _isPhotoMode
                  ? FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return buildCameraPreview();
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              )
                  : Center(
                child: !isDrawing
                    ? Text(
                  'Camera is off',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                )
                    : null, // Displaying null when isDrawing is true
              ),
              if (isDrawing) buildDrawingOverlay(),
            ],
          ),
        ),
        buildControls(),
      ],
    );
  }

  Widget buildCameraPreview() {
    return _isPhotoMode && _currentPhoto != null
        ? Image.file(
      File(_currentPhoto!.path),
      width: MediaQuery.of(context).size.width,
      fit: BoxFit.cover,
    )
        : Container(
      width: double.infinity,
      child: CameraPreview(_controller),
    );
  }

  Widget buildDrawingOverlay() {
    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _points = [];
          _drawings.add(_points);
        });
      },
      onPanUpdate: (details) {
        RenderBox renderBox = context.findRenderObject() as RenderBox;
        Offset localPosition = renderBox.globalToLocal(details.globalPosition);
        setState(() {
          _points.add(localPosition);
        });
      },
      child: CustomPaint(
        painter: DrawingPainter(_drawings, selectedColor),
        child: Container(),
      ),
    );
  }

  Widget buildControls() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          buildControlButtons(),
          SizedBox(height: 16),
          buildActionButtons(),
        ],
      ),
    );
  }
  Widget buildControlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.palette, color: Colors.white),
          onPressed: () {
            setState(() {
              isDrawing = !isDrawing;
            });
            if (isDrawing) {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return Container(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: paletteColors.length,
                      itemBuilder: (BuildContext context, int index) {
                        return GestureDetector(
                          onTap: () {
                            selectColor(paletteColors[index]);
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            color: paletteColors[index],
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          },
        ),
        if (isDrawing)
          IconButton(
            icon: Icon(Icons.close, color: Colors.white),
            onPressed: () {
              setState(() {
                isDrawing = false;
                _points.clear();
              });
            },
          ),
        Spacer(),
        if (_isPhotoMode || _isCameraOn)
// This pushes the following buttons to the right
          IconButton(
            icon: Icon(Icons.switch_camera),
            color:  Colors.white ,
            onPressed:  _switchCamera,
          ),
        if (_isPhotoMode)
          IconButton(
            icon: Icon(Icons.photo_library),
            color: Colors.white,
            onPressed: _pickImageFromGallery,
          ),
      ],
    );
  }

  Widget buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        buildMicButton(),
        SizedBox(width: 16),
        buildPhotoButton(),
        SizedBox(width: 16),
        buildCameraButton(),
      ],
    );
  }

  Widget buildMicButton() {
    return ElevatedButton(
      onPressed: () => _startListening(),
      child: Icon(_isListening ? Icons.stop : Icons.mic, color: Colors.white),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget buildPhotoButton() {
    return ElevatedButton(
      onPressed: () {
        if (_isPhotoMode) {
          _offPhotoMode();
        } else {
          _onPhotoMode();
        }
        _longPressActive = false;
        setState(() {});
      },
      onLongPress: () async {
        if (_isPhotoMode) {
          Timer(const Duration(seconds: 2), () async {
            if (_longPressActive) {
              await _savePicture();
            }
          });
          _longPressActive = true;
        }
      },
      child: Icon(_isPhotoMode ? Icons.photo_camera : Icons.photo_camera_outlined, color: Colors.white),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget buildCameraButton() {
    return ElevatedButton(
      onPressed: () {
        if (_isCameraOn) {
          _turnCameraOff();
        } else {
          _turnCameraOn();
        }
        setState(() {});
      },
      child: Icon(_isCameraOn ? Icons.video_call : Icons.video_call_outlined, color: Colors.white),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.teal,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }



  Widget buildSetupContent() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Select your adventure buddy',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16),
          DropdownButton<String>(
            value: _selectedVoiceId,
            dropdownColor: Colors.teal,
            onChanged: (String? newValue) {
              setState(() {
                _selectedVoiceId = newValue!;
                _selectedVoiceName = _availableVoices.firstWhere((voice) => voice['id'] == newValue)['name'];
              });
            },
            items: _availableVoices.map<DropdownMenuItem<String>>((voice) {
              return DropdownMenuItem<String>(
                value: voice['id'],
                child: Text(voice['name'] ?? 'Unknown', style: TextStyle(color: Colors.white)),
              );
            }).toList(),
          ),
          SizedBox(height: 16),
          Text(
            'What type of adventure?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16),
          Container(
            width: 325,
            child: TextField(
              controller: _adventureTypeController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                labelText: 'Adventure Type',
                labelStyle: TextStyle(color: Colors.white70),
                filled: true,
                fillColor: Colors.white10,
              ),
              onChanged: (text) {
                setState(() {
                  role = text;
                });
              },
              style: TextStyle(color: Colors.white),
            ),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () async {
              createNewAdventure();
              _clearSavedImages();
              _startProcess();
            },
            child: Text('Start Adventure', style: TextStyle(color: Colors.white),),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}