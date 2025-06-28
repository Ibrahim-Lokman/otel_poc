class User {
  final String id;
  final String email;
  final String name;
  final String demographics;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.demographics = 'unknown',
  });
}
