import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:io';
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


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));

}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: SpeechCameraScreen(cameras: cameras),
    );
  }
}

class SpeechCameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const SpeechCameraScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _SpeechCameraScreenState createState() => _SpeechCameraScreenState();
}
class ColorOption extends StatelessWidget {
  final Color color;
  final Function(Color) onColorSelected;

  ColorOption({required this.color, required this.onColorSelected});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onColorSelected(color);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
class _SpeechCameraScreenState extends State<SpeechCameraScreen> {
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
    _fetchVoices(); // Fetch voices during initialization
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    _captureTimer?.cancel();
    super.dispose();
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

  Future<void> initializeModel() async {
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyDm6zkJpMgkVJu54_Gqxu_fvkDAsjPO-ns',
      generationConfig: GenerationConfig(maxOutputTokens: 175),
    );
    _chatSession = await _model.startChat(history: [
      Content.text(
          'You are $_selectedVoiceName, an AI adventure partner. You help the user answer questions and discover new things. Your current adventure is related to $role.')
    ]);
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

        return response.text ?? "No response from the model.";
      } else {
        var content = Content.text(prompt);

        final response = await _chatSession.sendMessage(content);
        return response.text ?? "No response from the model.";
      }
    } catch (e) {
      print("Error analyzing prompt: $e");
      return 'Error analyzing prompt';
    }
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
        } else if (decision.contains('Off')) {
          _turnCameraOff();
          setState(() {
            _text = 'Camera turned off.';
            speak('Camera turned off.');
          });
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
    print('hello');
    print('chat:$_chatSession');
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

  Future<String> analyzePrompt(String prompt) async {
    try {
      final updatedPrompt = '''
Analyse this prompt: $prompt
Don't respond with any other thing apart from the options given!. 
Reply with:
- "End" if it involves ending an adventure,
- "Off" if it involves turning off the camera,
- "On" if it involves turning on the camera,
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
5. "What is this" -> "No"
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
    initializeModel();
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
      body: _isStarted
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _isCameraOn || _isPhotoMode
                ? FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return Stack(
                    children: [
                      _isPhotoMode && _currentPhoto != null
                          ? Image.file(
                        File(_currentPhoto!.path),
                        width: MediaQuery
                            .of(context)
                            .size
                            .width,
                        fit: BoxFit.cover,
                      )
                          : Container(
                        width: double.infinity,
                        child: CameraPreview(_controller),
                      ),
                      if (isDrawing)
                        GestureDetector(
                          onPanStart: (details) {
                            setState(() {
                              _points = [];
                              _drawings.add(_points);
                            });
                          },
                          onPanUpdate: (details) {
                            RenderBox renderBox = context
                                .findRenderObject() as RenderBox;
                            Offset localPosition = renderBox.globalToLocal(
                                details.globalPosition);
                            setState(() {
                              _points.add(localPosition);
                            });
                          },
                          child: CustomPaint(
                            painter: DrawingPainter(_drawings, selectedColor),
                            child: Container(),
                          ),
                        ),
                    ],
                  );
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            )
                : Center(
              child: Text(
                'Camera is off',
                style: TextStyle(color: Colors.white, fontSize: 24),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        height: 100,
                        child: SingleChildScrollView(
                          child: Text(
                            _text,
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isListening ? Icons.stop : Icons.mic),
                      color: _isListening ? Colors.red : Colors.grey,
                      onPressed: _isListening
                          ? _stopListening
                          : _startListening,
                    ),
                    IconButton(
                      icon: Icon(Icons.switch_camera),
                      color: _isCameraOn ? Colors.teal : Colors.grey,
                      onPressed: _isCameraOn ? _switchCamera : null,
                    ),
                    if (_isPhotoMode)
                      IconButton(
                        icon: Icon(Icons.video_call),
                        color: Colors.grey,
                        onPressed: _pickImageFromGallery,
                      ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_isCameraOn || _isPhotoMode)
                      IconButton(
                        icon: Icon(Icons.palette),
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
                                    itemBuilder: (BuildContext context,
                                        int index) {
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
                        icon: Icon(Icons.close),
                        onPressed: () {
                          setState(() {
                            isDrawing = false;
                            _points.clear(); // Optional: Clear current points
                          });
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () => _startListening(),
                  child: Icon(_isListening ? Icons.stop : Icons.mic),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
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
                  child: Icon(_isPhotoMode ? Icons.photo_camera : Icons
                      .photo_camera_outlined),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_isCameraOn) {
                      _turnCameraOff();
                    } else {
                      _turnCameraOn();
                    }
                    setState(() {});
                  },
                  child: Icon(_isCameraOn ? Icons.camera_alt : Icons.camera),
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
          ),
        ],
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Select your adventure buddy',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            DropdownButton<String>(
              value: _selectedVoiceId,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedVoiceId = newValue!;
                  _selectedVoiceName = _availableVoices
                      .firstWhere((voice) => voice['id'] == newValue)['name'];
                });
              },
              items: _availableVoices
                  .map<DropdownMenuItem<String>>((voice) {
                return DropdownMenuItem<String>(
                  value: voice['id'],
                  child: Text(voice['name'] ?? 'Unknown'),
                );
              }).toList(),
            ),
            SizedBox(height: 16),
            Text(
              'What type of adventure?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              width: 325,
              child: TextField(
                controller: _adventureTypeController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Adventure Type',
                ),
                onChanged: (text) {
                  setState(() {
                    role = text;
                  });
                },
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _clearSavedImages();
                _startProcess();
              },
              child: Text('Start Adventure'),
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
      ),
    );
  }
}