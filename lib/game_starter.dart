// game_starter.dart
import 'package:flutter/material.dart';
import 'extensions/tic_tac_toe.dart';
 import 'extensions/connect_four.dart';
import 'extensions/hangman_game.dart';

Widget getGameScreen(String gameName) {
  switch (gameName) {
    case 'Tic Tac Toe':
      return TicTacToeGame();
    case 'Connect Four':
      return ConnectFourGame();
    case 'Hangman':
      return HangmanGame();
    default:
      throw Exception('Game not found');
  }
}
