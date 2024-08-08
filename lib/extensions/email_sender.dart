import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class EmailSender {
  final String apiUrl = 'https://api.mailersend.com/v1/email';
  final String apiKey = 'mlsn.67f25faffebaf378c008a2930fd87f6d24ecea205afba1b6d8fd62ec98ef0c2e'; // Replace with your MailerSend API key

  Future<void> sendEmail(String subject, String body) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? recipientEmail = prefs.getString('user_email');

    if (recipientEmail == null || recipientEmail.isEmpty) {
      print('Recipient email is not set.');
      return;
    }

    final emailData = {
      'from': {
        'email': 'info@trial-x2p0347jzyk4zdrn.mlsender.net' // Replace with your sender email
      },
      'to': [
        {
          'email': recipientEmail
        }
      ],
      'subject': subject,
      'text': body,
      'html': body, // Assuming body can be in HTML format
    };

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode(emailData),
    );

    if (response.statusCode == 202) {
      print('Email sent successfully!');
    } else {
      print('Failed to send email: ${response.statusCode}');
      print('Response body: ${response.body}');
    }
  }
}
