import 'package:equatable/equatable.dart';

/// Generic page envelope mirroring the backend `paginatedResponse` shape:
/// `{ data, meta: { current_page, per_page, total, last_page } }`.
class Paginated<T> extends Equatable {
  final List<T> items;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  const Paginated({
    required this.items,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  bool get hasMore => currentPage < lastPage;

  Paginated<T> appending(Paginated<T> next) {
    return Paginated<T>(
      items: [...items, ...next.items],
      currentPage: next.currentPage,
      perPage: next.perPage,
      total: next.total,
      lastPage: next.lastPage,
    );
  }

  static Paginated<T> empty<T>() => Paginated<T>(
    items: const [],
    currentPage: 1,
    perPage: 0,
    total: 0,
    lastPage: 1,
  );

  @override
  List<Object?> get props => [items, currentPage, perPage, total, lastPage];
}
