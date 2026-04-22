import '../../domain/entities/actor_ref.dart';

class ActorRefModel extends ActorRef {
  const ActorRefModel({required super.id, required super.name});

  factory ActorRefModel.fromJson(Map<String, dynamic> json) {
    return ActorRefModel(
      id: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
