import 'package:equatable/equatable.dart';

class ActorRef extends Equatable {
  final int id;
  final String name;

  const ActorRef({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
