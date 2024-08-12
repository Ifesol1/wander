import 'dart:math';

import 'package:flutter/material.dart';

class TicTacToeGame extends StatefulWidget {
  @override
  _TicTacToeGameState createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  List<String> _board = List.generate(9, (_) => '');
  String _currentPlayer = 'X';
  String? _winner;
  final Random _random = Random(); // Random number generator for bot moves

  @override
  void initState() {
    super.initState();
    _currentPlayer = _random.nextBool() ? 'X' : 'O'; // Randomly choose starting player
    if (_currentPlayer == 'O') {
      _botMove(); // Bot plays first if you are 'O'
    }
  }

  void _handleTap(int index) {
    if (_board[index] == '' && _winner == null) {
      setState(() {
        _board[index] = _currentPlayer;
        _winner = _checkWinner();
        if (_winner == null && _currentPlayer == 'X') {
          _currentPlayer = 'O';
          _botMove();
        } else if (_winner == null) {
          _currentPlayer = 'X';
        }
      });
    }
  }

  void _botMove() {
    List<int> emptyIndices = [];
    for (int i = 0; i < _board.length; i++) {
      if (_board[i] == '') {
        emptyIndices.add(i);
      }
    }
    if (emptyIndices.isNotEmpty) {
      int move = emptyIndices[_random.nextInt(emptyIndices.length)];
      Future.delayed(Duration(milliseconds: 500), () {
        setState(() {
          _board[move] = 'O';
          _winner = _checkWinner();
          _currentPlayer = 'X';
        });
      });
    }
  }

  String? _checkWinner() {
    const List<List<int>> _winningCombinations = [
      [0, 1, 2],
      [3, 4, 5],
      [6, 7, 8],
      [0, 3, 6],
      [1, 4, 7],
      [2, 5, 8],
      [0, 4, 8],
      [2, 4, 6],
    ];

    for (var combination in _winningCombinations) {
      if (_board[combination[0]] != '' &&
          _board[combination[0]] == _board[combination[1]] &&
          _board[combination[1]] == _board[combination[2]]) {
        return _board[combination[0]];
      }
    }
    return _board.contains('') ? null : 'Draw';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade200, Colors.teal.shade800],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 150,
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                ),
                itemCount: 9,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _handleTap(index),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(),
                      ),
                      child: Center(
                        child: Text(
                          _board[index],
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_winner != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _winner == 'Draw' ? 'It\'s a Draw!' : 'Winner: $_winner',
                  style: TextStyle(fontSize: 24),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _board = List.generate(9, (_) => '');
                  _winner = null;
                  _currentPlayer = _random.nextBool() ? 'X' : 'O'; // Randomly choose starting player
                  if (_currentPlayer == 'O') {
                    _botMove(); // Bot plays first if you are 'O'
                  }
                });
              },
              child: Text('Restart'),
            ),
          ],
        ),
      ),
    );
  }
}
