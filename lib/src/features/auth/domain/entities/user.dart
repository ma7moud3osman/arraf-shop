import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String id;
  final String email;
  final String? name;
  final String? photoUrl;

  /// True for backend users with `role=admin` (or the legacy `is_admin=true`
  /// flag). Drives admin-only UI affordances such as the gold price editor.
  final bool isAdmin;

  const AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photoUrl,
    this.isAdmin = false,
  });

  factory AppUser.empty() => const AppUser(id: '', email: '');

  bool get isEmpty => id.isEmpty;
  bool get isNotEmpty => id.isNotEmpty;

  @override
  List<Object?> get props => [id, email, name, photoUrl, isAdmin];
}
