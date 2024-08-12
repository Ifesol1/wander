import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart'; // Import the AI package

class HangmanGame extends StatefulWidget {
  @override
  _HangmanGameState createState() => _HangmanGameState();
}

class _HangmanGameState extends State<HangmanGame> {
  String _word = ''; // The word to guess
  Set<String> _guessedLetters = {};
  int _wrongGuesses = 0;

  @override
  void initState() {
    super.initState();
    _initializeGame();
  }

  Future<void> _initializeGame() async {
    // Initialize the AI model
    final apiKey = 'AIzaSyDm6zkJpMgkVJu54_Gqxu_fvkDAsjPO-ns';
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    // Generate a word using the AI model
    final prompt = "Generate a random six letter word for a Hangman game. Only give me the word";
    final content = [Content.text(prompt.toString())];

    final word = await model.generateContent(content);

    // Update the state with the generated word
    setState(() {
      _word = word.text?.toUpperCase().trim() ?? ""; // Ensure the word is in uppercase
    });
  }

  void _handleGuess(String letter) {
    if (!_guessedLetters.contains(letter) && _word.isNotEmpty) {
      setState(() {
        _guessedLetters.add(letter);
        if (!_word.contains(letter)) {
          _wrongGuesses++;
        }
      });
    }
  }

  String _getDisplayedWord() {
    return _word.split('').map((letter) => _guessedLetters.contains(letter) ? letter : '_').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    bool isGameOver = _wrongGuesses >= 10;
    bool isWordGuessed = _word.split('').every((letter) => _guessedLetters.contains(letter));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade200, Colors.teal.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: _word.isEmpty
              ? CircularProgressIndicator() // Show loading indicator until the word is generated
              : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Wrong Guesses: $_wrongGuesses/10',
                style: TextStyle(fontSize: 20),
              ),
              SizedBox(height: 20),
              Text(
                _getDisplayedWord(),
                style: TextStyle(fontSize: 40, letterSpacing: 2),
              ),
              SizedBox(height: 20),
              if (isGameOver)
                Text(
                  'Game Over! The word was $_word',
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              if (isWordGuessed)
                Text(
                  'You Won!',
                  style: TextStyle(fontSize: 30, color: Colors.green),
                ),
              if (!isGameOver && !isWordGuessed)
                Wrap(
                  children: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('').map((letter) {
                    return GestureDetector(
                      onTap: () => _handleGuess(letter),
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Chip(
                          label: Text(letter),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _guessedLetters.clear();
                    _wrongGuesses = 0;
                    _initializeGame(); // Generate a new word
                  });
                },
                child: Text('Restart'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
