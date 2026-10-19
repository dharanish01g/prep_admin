/// A signed-up person (a row in `profiles`).
class Member {
  const Member({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;

  String get firstName {
    final name = fullName.trim();
    return name.isEmpty ? email.split('@').first : name.split(' ').first;
  }

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.first.isEmpty) {
      return email.isEmpty ? '?' : email[0].toUpperCase();
    }
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
