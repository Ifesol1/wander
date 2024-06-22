

  class Adventure {
    String timestamp;
    String details;
    List<Map<String, dynamic>> chatHistory;

    Adventure({
      required this.timestamp,
      required this.details,
      required this.chatHistory,
    });

    factory Adventure.fromJson(Map<String, dynamic> json) {
      return Adventure(
        timestamp: json['timestamp'],
        details: json['details'],
        chatHistory: List<Map<String, dynamic>>.from(json['chatHistory']),
      );
    }

    Map<String, dynamic> toJson() {
      return {
        'timestamp': timestamp,
        'details': details,
        'chatHistory': chatHistory,
      };
    }
  }
