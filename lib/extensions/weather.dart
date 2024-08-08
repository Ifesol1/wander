// weather_fetcher.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherFetcher {
  final String apiKey;

  WeatherFetcher(this.apiKey);

  Future<Map<String, dynamic>> fetchCurrentWeather(String location) async {
    final uri = Uri.parse("https://api.weatherapi.com/v1/current.json?key=$apiKey&q=$location");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch current weather: ${response.reasonPhrase}');
    }
  }

  Future<Map<String, dynamic>> fetchWeatherForecast(String location, int days) async {
    final uri = Uri.parse("https://api.weatherapi.com/v1/forecast.json?key=$apiKey&q=$location&days=$days&aqi=no&alerts=no");
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch weather forecast: ${response.reasonPhrase}');
    }
  }
}
