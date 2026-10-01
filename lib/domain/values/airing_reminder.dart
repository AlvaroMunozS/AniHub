/// A reminder that a series airs at [at], a UTC instant.
class AiringReminder {
  const AiringReminder({
    required this.malId,
    required this.title,
    required this.at,
  });

  final int malId;
  final String title;
  final DateTime at;

  @override
  bool operator ==(Object other) =>
      other is AiringReminder &&
      other.malId == malId &&
      other.title == title &&
      other.at == at;

  @override
  int get hashCode => Object.hash(malId, title, at);

  @override
  String toString() => 'AiringReminder($malId, $title, $at)';
}

/// The texts of the reminders, in the app language.
class ReminderTexts {
  const ReminderTexts({
    required this.channelName,
    required this.channelDescription,
    required this.body,
  });

  final String channelName;
  final String channelDescription;
  final String body;

  @override
  bool operator ==(Object other) =>
      other is ReminderTexts &&
      other.channelName == channelName &&
      other.channelDescription == channelDescription &&
      other.body == body;

  @override
  int get hashCode => Object.hash(channelName, channelDescription, body);

  @override
  String toString() =>
      'ReminderTexts($channelName, $channelDescription, $body)';
}
