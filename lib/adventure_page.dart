import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'extensions/weather.dart';

import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'extensions/imagegen.dart';
import 'extensions/ebaylink.dart';
import 'extensions/email_sender.dart';
import 'extensions/clipboard_copier.dart';
import 'extensions/tic_tac_toe.dart';
import 'extensions/connect_four.dart';
import 'extensions/hangman_game.dart';
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
  String? _selectedGame;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _text = 'Press the button and start speaking';
  String _aitext = '';
  String _title = '';
  List<Map<String, dynamic>> _items = [];
  final List<Map<String, dynamic>> _queue = [];

  int _currentCameraIndex = 0;
  List<File> _capturedImages = [];
  Timer? _captureTimer;
  bool _isStarted = false;
  bool _longPressActive = false;
  XFile? _currentPhoto = null; // Make _currentPhoto nullable
  bool _isStitching = false;
  bool _istalking = false;
  Adventure? _currentAdventure;
  bool _isExpanded = false;

  final _imagesStitch = ImagesStitch();
  List<File> _stitchedImages = [];
  final ElevenLabsAPI _elevenLabsAPI = ElevenLabsAPI(
      'f9c629b2ae0dcb148dc75dfa01b9ea8b'); // Replace with your actual API key
  String _selectedVoiceId = ''; // Assuming "adventurer" is the voice ID
  List<Map<String, String>> _availableVoices = [];
  bool _aiRequestHandled = false;
  bool _isCameraOn = false; // Track the camera state
  TextEditingController _adventureTypeController = TextEditingController();
  String role = '';
  bool _isProcessing = false;
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
  void _loadDataFromJson(jsonString) {

    final Map<String, dynamic> parsedJson = json.decode(jsonString);
    setState(() {
      _title = parsedJson['title'];
      _items = List<Map<String, dynamic>>.from(parsedJson['items']);
    });
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
    );

    if (savedAdventure != null) {
      _currentAdventure = savedAdventure;
      // Deserialize chat history from savedAdventure
      final chatHistory = savedAdventure.chatHistory.map((json) => contentFromJson(json)).toList();
      _chatSession = await _model.startChat(history: chatHistory);
    } else {
      _chatSession = await _model.startChat(history: [
        Content.text(
          'You are wander or wonder, an AI conversation partner. You help the user answer questions and discover new things. Your current conversation is related to $role.',
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
      // Check if camera is on or photo mode is active
      if (_isCameraOn || (_isPhotoMode && _currentPhoto != null)) {
        // Process image data
        final imageBytes = await File(imagePath).readAsBytes();
        DataPart imagePart;

        if (_drawings.isNotEmpty) {
          imagePart = await _combineImageWithDrawing(DataPart('image/jpeg', imageBytes));
        } else {
          imagePart = DataPart('image/jpeg', imageBytes);
        }

        final promptPart = TextPart(prompt);
        var content = Content.multi([promptPart, imagePart]);
        final response = await _chatSession.sendMessage(content);

        await _saveModelState();
        final aiResponse = response.text ?? "";
        if (aiResponse.startsWith('List')) {
          final extractedBlock = extractCodeBlock(aiResponse, '{', '}');
          _loadDataFromJson(extractedBlock);
          final additionalInfo = aiResponse.split('}').last.trim();  // Extract after JSON
          return additionalInfo;
        } else if (aiResponse.startsWith('Games')) {
          final gameType = aiResponse.split('\n').first.trim();
          String game = gameType.split(', ')[1]; // Extracting the game name

          final additionalInfo = aiResponse.split(gameType).last.trim();
          startGame(game);
          print('game:$gameType');
          print('info: $additionalInfo');
          return additionalInfo;
        } else if (aiResponse.startsWith('Remove')) {
          final listInfo = aiResponse.split('\n').first.trim();
          String item = listInfo.split(', ')[1]; // Extracting the game name

          final additionalInfo = aiResponse.split(listInfo).last.trim();
          print('item:$item');
          print('info: $additionalInfo');
          _toggleItem(item);
          return additionalInfo;
        } else {
          return aiResponse.isNotEmpty ? aiResponse : "No response from the model.";
        }
      } else {
        // Process prompt without image
        final String newPrompt = '''
User's prompt: $prompt
If it involves playing a game (Connect Four, TicTacToe, or Hangman). If the specific game is not mentioned, respond with a list of available games. If the game is mentioned, respond with "Games, specific game".
If the prompt involves tasks like grocery shopping or a treasure hunt, respond with:
List,
{
  "title": "My Tasks",
  "items": [
    {"title": "Buy groceries", "completed": false},
    {"title": "Walk the dog", "completed": false},
    {"title": "Read a book", "completed": false}
  ]
}
If a user says they've found an item or wants an item crossed out or removed, return "Remove, specific item being removed" and, on a separate line, provide a normal response to the prompt.
Ignore games and lists if they don't relate and just do what the user asks.
Additionally, provide relevant information about the list or game, similar to a voiceover, after the JSON. These should start on a separate line.
''';

        var content = Content.text(newPrompt);
        await _saveModelState();

        final response = await _chatSession.sendMessage(content);
        final aiResponse = response.text ?? "";
        print(aiResponse);
        if (aiResponse.startsWith('List')) {
          final extractedBlock = extractCodeBlock(aiResponse, '{', '}');
          _loadDataFromJson(extractedBlock);
          final additionalInfo = aiResponse.split('}').last.trim();  // Extract after JSON
          return additionalInfo;
        } else if (aiResponse.startsWith('Games')) {
          final gameType = aiResponse.split('\n').first.trim();
          String game = gameType.split(', ')[1];  // Extracting the game name

          String additionalInfo = '';
          if (aiResponse.contains('}')) {
            additionalInfo = aiResponse.split('}').last.trim();  // Extract after the closing curly brace
          } else {
            additionalInfo = aiResponse.split(gameType).last.trim();  // Extract after the gameType
          }

          startGame(game);
          print('game: $gameType');
          print('info: $additionalInfo');
          return additionalInfo;

        } else if (aiResponse.startsWith('Remove')) {
          final listInfo = aiResponse.split('\n').first.trim();
          String item = listInfo.split(', ')[1];
          final additionalInfo = aiResponse.split(listInfo).last.trim();
          print('item:$item');
          print('info: $additionalInfo');
          _toggleItem(item);
          return additionalInfo;
        } else {
          return aiResponse.isNotEmpty ? aiResponse : "No response from the model.";
        }
      }
    } catch (e) {
      print("Error analyzing prompt: $e");
      return 'Error analyzing prompt';
    }
  }

  void startGame(String gameType) {
    setState(() {
      _selectedGame = gameType; // Set the selected game
    });

    // Additional logic can go here if needed
  }
  bool _isGameSelected() {
    return _selectedGame != null;
  }
  Future<void> _launchURL(String url) async {
    var uri = Uri.parse(url);

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication, // Use this mode to open URLs in an external browser
    );

  }
  Future<void> _requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {

        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {

      return;
    }

  }
  Future<Map<String, double>?> fetchLocation() async {
    try {
      await _requestLocationPermission();
      Position _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return {
        'latitude': _currentPosition.latitude,
        'longitude': _currentPosition.longitude,
      };
    } catch (e) {
      print('Error fetching location: $e');
      return null; // Return null if an error occurs
    }
  }
  String extractCodeBlock(String code, String startPattern, String endPattern) {
    final startIndex = code.indexOf(startPattern);
    final endIndex = code.lastIndexOf(endPattern);

    if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
      return '';
    }

    return code.substring(startIndex, endIndex + endPattern.length);
  }
  Future<void> _handleAiRequest() async {
    if (_text != 'Press the button and start speaking') {
      final prompt = _buildPrompt();
      final prevPrompt = _buildPrevPrompt();

      try {
        final decision = await analyzePrompt(_text);
        print('AI Decision: $decision');

        if (decision.contains('No')) {
          await _handleNoDecision(prompt);
        } else if (decision.contains('On')) {
          _turnCameraOn();
          _setTextAndSpeak('Camera turned on.');
        } else if (decision.contains('Weather')) {
          await _handleWeatherDecision(prompt);
        } else if (decision.contains('Link')) {
          await _handleLinkDecision(prompt);
        } else if (decision.contains('Off')) {
          _turnCameraOff();
          _setTextAndSpeak('Camera turned off.');
        } else if (decision.contains('Imagegen')) {
          await _handleImageGenDecision();
        } else if (decision.contains('Retrieve (Copying)')) {
          await _handleRetrieveForCopying();
        } else if (decision.contains('Retrieve (Email)')) {
          await _handleRetrieveForEmail();
        } else {
          _setTextAndSpeak(decision);
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

// Function to handle 'Retrieve (Email)' prompt
  Future<void> _handleRetrieveForEmail() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? recipientEmail = prefs.getString('user_email');

      if (recipientEmail == null || recipientEmail.isEmpty) {
        print('Recipient email not set.');
        _text = 'Recipient email not set. Please set it up in settings.';
        return;
      }

      // Assuming _text contains the content to send via email
      EmailSender emailSender = EmailSender();
      await emailSender.sendEmail('Shared Text from App', _aitext);
      _text = 'Email sent successfully.';
    } catch (e) {
      print('Error sending email: $e');
      _text = ('Failed to send email.');
    }
  }
  Future<void> _handleRetrieveForCopying() async {
    try {
      final Clipboard = ClipboardCopier();
      // Assuming _text contains the text to copy
      await Clipboard.copyToClipboard( _aitext);
      print('Text copied to clipboard: $_aitext');
      _text = 'Text copied to clipboard.';
    } catch (e) {
      print('Error copying text to clipboard: $e');
      _text = 'Failed to copy text to clipboard.';
    }
  }
  void _toggleItem(String itemTitle) {
    setState(() {
      // Find the item in the list by title
      final item = _items.firstWhere(
            (element) => element['title'] == itemTitle,
        orElse: () => <String, dynamic>{}, // Return an empty map
      );

      // If the item is found, toggle its 'completed' status
      if (item.isNotEmpty) {
        item['completed'] = !item['completed'];
      }

      // Check if all items are completed, if so, clear the list
      if (_items.every((element) => element['completed'])) {
        _items.clear();
      }
    });
  }



  Future<void> _handleNoDecision(String prompt) async {
    String imagePath;
    print(prompt);
    if (_capturedImages.isNotEmpty) {
      imagePath = _capturedImages.last.path;
    } else {
      imagePath = ''; // Handle the case when _capturedImages is empty
    }

    if (imagePath.isNotEmpty) {
      final analysis = await analyzeImage(imagePath, prompt);
      _setTextAndSpeak(analysis);
    } else {
      if (_isPhotoMode || _isCameraOn) {
        String warning = 'I cannot see anything, try holding the camera button to snap or click on the livestream button. You can turn off the camera if you want to chat normally';
        _setTextAndSpeak(warning);
      } else {
        final analysis = await analyzeImage(imagePath, prompt);
        _setTextAndSpeak(analysis);
      }
    }
  }
  Future<String> parseAndDisplayErrors(String test) async {
    // Split the test string by commas
    List<String> parts = test.split(',').map((part) => part.trim()).toList();

    String days = parts.length > 1 ? parts[1] : '';
    String time = parts.length > 2 ? parts[2] : '';
    String location = parts.length > 3 ? parts[3] : '';

    // Check for errors and display messages
    if (days.isEmpty || days.contains('error')) {
      return 'Error: Number of days not specified.';
    } else if (time.isEmpty || time.contains('error')) {
      if (location.isEmpty || location.contains('error')) {
        return 'Error: Time and location not specified.';
      } else {
        return 'Error: Time not specified.';
      }
    } else if (location.isEmpty || location.contains('error')) {
      Map<String, double>? locations = await fetchLocation();
      location = '${locations?['latitude']}, ${locations?['longitude']}';
    }

    return 'Future: $days, Time: $time, Location: $location';
  }



  Future<void> _handleWeatherDecision(String prompt) async {
    String returnvalue = '';
    String res = _buildWeatherPrompt();
    final tests = await analyzePrompts(res);
    var location = '';
    final weatherFetcher = WeatherFetcher('1d26e3779c9b4ab5880155318242506');

    if (tests.contains('alsocurrent')) {
      final locationIndex = tests.indexOf('alsocurrent') + 'alsocurrent'.length + 1;
      final locationEndIndex = tests.indexOf(',', locationIndex);
      if (locationEndIndex == -1) {
        location = tests.substring(locationIndex);
      } else {
        location = tests.substring(locationIndex, locationEndIndex);
      }
      print('location: $location');
      final currentWeather = await weatherFetcher.fetchCurrentWeather(location);
      returnvalue = await analyzePrompts('provide an answer to the question: $_text based on this data $currentWeather');
    } else if (tests.contains('current')) {
      try {
        Map<String, double>? locations = await fetchLocation();
        location = '${locations?['latitude']}, ${locations?['longitude']}';
        print('location: $location');
        final currentWeather = await weatherFetcher.fetchCurrentWeather(location);
        returnvalue = await analyzePrompts('provide an answer to the question: $_text based on this data $currentWeather');
      } catch (e) {
        returnvalue = 'Failed to fetch current weather for $location: $e';
      }
    } else if (tests.contains('Future')) {
      final parse = await parseAndDisplayErrors(tests);
      if (parse.contains('Error')) {
        returnvalue = parse;
      } else {
        try {
          List<String> parts = tests.split(',').map((part) => part.trim()).toList();
          String days = parts.length > 1 ? parts[1] : '';
          location = parts.length > 3 ? parts[3] : '';
          String cleanedString = days.replaceAll(RegExp(r'\s*day[s]?\s*'), '');
          DateTime now = DateTime.now();
          String formattedDate = "${now.year}-${now.month}-${now.day + int.tryParse(cleanedString)!}";
          // Convert cleaned string to integer
          int? numberOfDays = int.tryParse(cleanedString)! + 1;
          final weatherForecast = await weatherFetcher.fetchWeatherForecast(location, numberOfDays!);
          final forecastDay = weatherForecast['forecast']['forecastday'];
          Map<String, dynamic> forecastForDay = forecastDay.firstWhere((day) => day['date'] == formattedDate);

          // Print the target hour segment

          returnvalue = await analyzePrompts('provide an answer to the question: $_text based on this data $forecastForDay');
        } catch (e) {
          returnvalue = 'Failed to fetch weather forecast for $location: $e';
        }
      }
    } else {
      returnvalue = 'No action for the given test string.';
    }

    _setTextAndSpeak(returnvalue);
  }



  Future<void> _handleLinkDecision(String prompt) async {
    bool isEnabled = await ExtensionUtils.isExtensionEnabled('ebaylink.dart');
    if (isEnabled) {
      String imagePath;
      if (_capturedImages.isNotEmpty) {
        imagePath = _capturedImages.last.path;
      } else {
        imagePath = ''; // Handle the case when _capturedImages is empty
      }

      if (imagePath.isNotEmpty) {
        final analysis = await analyzeImage(imagePath, _buildLinkPrompt());
        _setTextAndSpeak(analysis);
      } else {
        if (_isPhotoMode || _isCameraOn) {
          String warning = 'I cannot see anything, try holding the camera button to snap or click on the livestream button. You can turn off the camera if you want to chat normally';
          _setTextAndSpeak(warning);
        } else {
          final analysis = await analyzeImage(imagePath, _buildLinkPrompt());
          _setTextAndSpeak(analysis);
        }
      }

      final ebayLinkGenerator = EbayLinkGenerator('IfeSolar-wander-PRD-807721e0a-1f819107');
      final link = await ebayLinkGenerator.generateLink(_text);
      print('Generated eBay link: $link');
      _setTextAndSpeak(link);
    } else {
      _setTextAndSpeak('eBay Link extension is not enabled.');
    }
  }

  Future<void> _handleImageGenDecision() async {
    bool isEnabled = await ExtensionUtils.isExtensionEnabled('imagegen.dart');
    if (isEnabled) {
      String imageprompt = _text;
      _setTextAndSpeak('Generating image.');
      await _generateImage(imageprompt);
      _setTextAndSpeak('Image successfully generated.');
    } else {
      _setTextAndSpeak('Image generation extension is not enabled.');
    }
  }

  void _setTextAndSpeak(String text) {
    setState(() {
      _text = text;
      _aitext = text;
      speak(text);
    });
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
      _selectedGame = null;

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
      _selectedGame = null;

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
  String _buildWeatherPrompt() {
    return ' $_text. Say "current" if it requires the current location and its not stated, and "alsocurrent, the certain location" if it requires current location and its given. say "Future" if it requires a forecast and specify the amount of days , what time it is and the location. If it is a forecast and both days, time and location arent specified, reply"error" with what isnt specified should contain the reason. ';
  }
  String _buildLinkPrompt() {
    return ' $_text. Say just the keyword or the product the user is requesting for';
  }
  Future<String> analyzePrompt(String prompt) async {
    try {
      final updatedPrompt = '''
Analyse this prompt: $prompt
Don't respond with anything other than the options provided below:
- "End" if the prompt involves ending an adventure.
- "Off" if it involves turning off the camera.
- "On" if it involves turning on the camera.
- "Imagegen" if it relates to generating an image.
- "Link" if it involves producing a link to a product.
- "Retrieve (Copying)" if it involves retrieving something for copying.
- "Retrieve (Email)" if it involves retrieving something for sending via email.
- "Weather" if it involves checking or discussing weather conditions.
- "Yes" if previous images or frames are required. Inform the user that previous images will be checked and analyzed, and this process may take some time. Example: "Yes, previous images will be checked and analyzed. This process may take some time."
- "No" if a single image is sufficient and no other options apply. If uncertain, double-check, and if no other option matches, respond with "No."

Hint: The words "remember" or "looking for" usually indicate that previous images are needed.

Examples to consider:
1. "Turn off the camera" -> "Off"
2. "End the adventure" -> "End"
3. "Turn on the camera" -> "On"
4. "What's the weather like today?" -> "Weather"
5. "Is it going to rain tomorrow?" -> "Weather"
6. "Generate an image of the sunset" -> "Imagegen"
7. "Find a link to a product" -> "Link"
8. "Remember the scene from before" -> "Yes, previous images will be checked and analyzed."
9. "Look for a pattern in previous frames" -> "Yes"
10. "Capture the current view" -> "No"
11. "What is this?" -> "No"


Don't respond with anything other than the options provided!
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
  Future<String> analyzePrompts(String prompt) async {
    try {

      var content = Content.text(prompt);

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
          // Background with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade200, Colors.teal.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _isStarted || widget.savedAdventure != null
                ? _isGameSelected()
                ? _buildGameScreen()
                : buildAdventureContent()
                : buildSetupContent(),
          ),

          // Game screen positioned within the camera area
          if (_isStarted || widget.savedAdventure != null)
            Positioned(
              top: 50,
              left: 20,
              right: 20,
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
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: GestureDetector(
                      onTap: () {
                        if (_isValidURL(_text)) {
                          _launchURL(_text);
                        } else {
                          print('Invalid URL');
                        }
                      },
                      child: Text(
                        _text,
                        style: TextStyle(
                          color: _isValidURL(_text)
                              ? Colors.blue
                              : Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),



              // Draggable to-do list with Material ancestor
              if (_items.isNotEmpty)
    Align(
    alignment: _isExpanded
    ? Alignment.centerRight
        : Alignment.bottomRight,
    child: Padding(
    padding: EdgeInsets.only(
    bottom: _isExpanded ? 0.0 : 115.0, // Adjust this value as needed
    ),
    child: _buildTaskContainer(),
    ),
    )


    // 'X' Button for closing the to-do list

        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    return Column(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade200, Colors.teal.shade800],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _selectedGame == 'TicTacToe'
                ? TicTacToeGame()
                : _selectedGame == 'Connect Four'
                ? ConnectFourGame()
                : _selectedGame == 'Hangman'
                ? HangmanGame()
                : Center(child: Text('No game selected.')),
          ),
        ),
        buildControls(),
      ],
    );
  }

  Widget _buildTaskContainer() {
    int completedCount = _items.where((item) => item['completed']).length;
    int totalCount = _items.length;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      width: 250,
      height: _isExpanded ? 400 : 100, // Adjust height when minimized
      margin: EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8), // Semi-transparent
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(2, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 24,
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          if (_isExpanded)
            Expanded(
              child: Scrollbar(
                child: ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return ListTile(
                      title: Text(
                        item['title'],
                        style: TextStyle(
                          fontSize: 16,
                          decoration: item['completed']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      trailing: Icon(
                        item['completed']
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        color: item['completed'] ? Colors.green : Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            )
          else
            Text(
              "$completedCount/$totalCount completed",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
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
            'Select the voice of your chat buddy',
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
            'Main topic of the conversation?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 16),
          Container(
            width: 325,
            child: TextField(
              controller: _adventureTypeController,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                labelText: 'Conversation Topic',
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