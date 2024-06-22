import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  final String apiKey = 'YOUR_API_KEY';
  final String baseUrl = 'https://api.openweathermap.org/data/3.0/onecall';

  Future<Map<String, dynamic>> fetchWeather(double lat, double lon) async {
    final response = await http.get(Uri.parse(
        '$baseUrl?lat=$lat&lon=$lon&exclude=minutely&appid=$apiKey&units=metric'));

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load weather data');
    }
  }
}
