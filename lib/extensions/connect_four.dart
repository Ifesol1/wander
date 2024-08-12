import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() => runApp(ConnectFourApp());

class ConnectFourApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Connect Four',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ConnectFourGame(),
    );
  }
}

class ConnectFourGame extends StatefulWidget {
  @override
  _ConnectFourGameState createState() => _ConnectFourGameState();
}

class _ConnectFourGameState extends State<ConnectFourGame> {
  static const int rows = 6;
  static const int columns = 7;
  List<List<String>> board = List.generate(
      rows, (_) => List.filled(columns, ''));
  String currentPlayer = 'Red';
  bool gameOver = false;
  String winner = '';
  final String aiPlayer = 'Yellow';

  @override
  void initState() {
    super.initState();
  }

  Future<void> dropDisc(int column) async {
    if (gameOver || board[0][column] != '') return;

    for (int row = rows - 1; row >= 0; row--) {
      if (board[row][column] == '') {
        setState(() {
          board[row][column] = currentPlayer;
          if (checkWinner(row, column)) {
            gameOver = true;
            winner = '$currentPlayer wins!';
          } else if (board.every((row) => row.every((cell) => cell != ''))) {
            gameOver = true;
            winner = 'It\'s a draw!';
          } else {
            currentPlayer = currentPlayer == 'Red' ? 'Yellow' : 'Red';
          }
        });
        break;
      }
    }

    if (!gameOver && currentPlayer == aiPlayer) {
      await aiMove();
    }
  }

  bool checkWinner(int row, int column) {
    String player = board[row][column];
    return (checkDirection(row, column, 1, 0, player) || // Horizontal
        checkDirection(row, column, 0, 1, player) || // Vertical
        checkDirection(row, column, 1, 1, player) || // Diagonal /
        checkDirection(row, column, 1, -1, player)); // Diagonal \
  }

  bool checkDirection(int row, int column, int rowDelta, int colDelta,
      String player) {
    int count = 1;

    // Check one direction
    for (int i = 1; i < 4; i++) {
      int newRow = row + i * rowDelta;
      int newCol = column + i * colDelta;
      if (newRow >= 0 && newRow < rows && newCol >= 0 && newCol < columns &&
          board[newRow][newCol] == player) {
        count++;
      } else {
        break;
      }
    }

    // Check the opposite direction
    for (int i = 1; i < 4; i++) {
      int newRow = row - i * rowDelta;
      int newCol = column - i * colDelta;
      if (newRow >= 0 && newRow < rows && newCol >= 0 && newCol < columns &&
          board[newRow][newCol] == player) {
        count++;
      } else {
        break;
      }
    }

    return count >= 4;
  }

  Future<void> aiMove() async {
    final apiKey = 'AIzaSyDm6zkJpMgkVJu54_Gqxu_fvkDAsjPO-ns';
    if (apiKey == null) {
      print('No \$API_KEY environment variable');
      return;
    }

    // Initialize the Google Generative AI model
    final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

    // Generate the Connect Four game state prompt
    final prompt = StringBuffer();
    prompt.writeln('You are playing Connect Four as the Yellow player.');
    prompt.writeln(
        'The board has 6 rows and 7 columns. Here is the current state of the board:');
    for (var row in board) {
      prompt.writeln(
          '| ${row.map((cell) => cell.isEmpty ? '_' : cell.substring(0, 1))
              .join(' | ')} |');
    }
    prompt.writeln(
        'It\'s your turn. Provide the column number (0 to 6) where you want to drop your disc. Only the number');

    // Send the prompt to the model
    final content = [Content.text(prompt.toString())];
    final response = await model.generateContent(content);

    // Parse the AI's response and make the move
    final aiResponse = response.text;
    final aiColumn = int.tryParse(aiResponse!.trim()) ?? (columns ~/ 2);
    await dropDisc(aiColumn);
  }

  void resetGame() {
    setState(() {
      board = List.generate(rows, (_) => List.filled(columns, ''));
      currentPlayer = 'Red';
      gameOver = false;
      winner = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Other widgets go here if needed
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              // Define a fixed height or calculate based on your needs
              width: double.infinity,
              // Ensures full width
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade200, Colors.teal.shade800],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    height: 150,
                  ),
                  Text(
                    gameOver ? winner : 'Current Player: $currentPlayer',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  Expanded(
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: rows * columns,
                      itemBuilder: (context, index) {
                        int row = index ~/ columns;
                        int col = index % columns;
                        return GestureDetector(
                          onTap: () => dropDisc(col),
                          child: Container(
                            margin: EdgeInsets.all(2.0),
                            color: board[row][col] == ''
                                ? Colors.grey
                                : (board[row][col] == 'Red'
                                ? Colors.red
                                : Colors.yellow),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: resetGame,
                    child: Text('Restart'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}