class Weather {
  final double temperature;
  final String description;
  final String icon;

  Weather({required this.temperature, required this.description, required this.icon});

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: json['current']['temp'],
      description: json['current']['weather'][0]['description'],
      icon: json['current']['weather'][0]['icon'],
    );
  }
}
