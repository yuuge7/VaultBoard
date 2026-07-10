import 'package:flutter/material.dart';

/// Priority levels available for a card, each with a distinct accent color.
enum CardPriority { none, low, medium, high }

extension CardPriorityX on CardPriority {
  String get label => switch (this) {
        CardPriority.none => 'None',
        CardPriority.low => 'Low',
        CardPriority.medium => 'Medium',
        CardPriority.high => 'High',
      };

  Color get color => switch (this) {
        CardPriority.none => const Color(0xFF546E7A),
        CardPriority.low => const Color(0xFF66BB6A),
        CardPriority.medium => const Color(0xFFFFB74D),
        CardPriority.high => const Color(0xFFEF5350),
      };
}

/// A single task card living inside a [KanbanList].
class KanbanCard {
  final String id;
  final String title;
  final String description;
  final DateTime createdAt;
  final CardPriority priority;
  final bool isDone;

  const KanbanCard({
    required this.id,
    required this.title,
    this.description = '',
    required this.createdAt,
    this.priority = CardPriority.none,
    this.isDone = false,
  });

  KanbanCard copyWith({
    String? title,
    String? description,
    CardPriority? priority,
    bool? isDone,
  }) {
    return KanbanCard(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
      priority: priority ?? this.priority,
      isDone: isDone ?? this.isDone,
    );
  }

  bool matches(String query) =>
      title.toLowerCase().contains(query) ||
      description.toLowerCase().contains(query);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'createdAt': createdAt.toIso8601String(),
        'priority': priority.name,
        'isDone': isDone,
      };

  factory KanbanCard.fromJson(Map<String, dynamic> json) => KanbanCard(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        priority: CardPriority.values.firstWhere(
          (p) => p.name == json['priority'],
          orElse: () => CardPriority.none,
        ),
        isDone: json['isDone'] as bool? ?? false,
      );
}

/// A vertical column of cards ("To Do", "In Progress", ...).
class KanbanList {
  final String id;
  final String title;
  final List<KanbanCard> cards;

  const KanbanList({
    required this.id,
    required this.title,
    this.cards = const [],
  });

  KanbanList copyWith({String? title, List<KanbanCard>? cards}) => KanbanList(
        id: id,
        title: title ?? this.title,
        cards: cards ?? this.cards,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'cards': cards.map((c) => c.toJson()).toList(),
      };

  factory KanbanList.fromJson(Map<String, dynamic> json) => KanbanList(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        cards: (json['cards'] as List<dynamic>? ?? [])
            .map((c) => KanbanCard.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

/// A whole board: a named collection of lists with an accent color.
class Board {
  final String id;
  final String name;
  final int colorValue;
  final DateTime createdAt;
  final List<KanbanList> lists;

  const Board({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.createdAt,
    this.lists = const [],
  });

  Color get color => Color(colorValue);

  Board copyWith({String? name, int? colorValue, List<KanbanList>? lists}) =>
      Board(
        id: id,
        name: name ?? this.name,
        colorValue: colorValue ?? this.colorValue,
        createdAt: createdAt,
        lists: lists ?? this.lists,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colorValue': colorValue,
        'createdAt': createdAt.toIso8601String(),
        'lists': lists.map((l) => l.toJson()).toList(),
      };

  factory Board.fromJson(Map<String, dynamic> json) => Board(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'Untitled',
        colorValue: json['colorValue'] as int? ?? 0xFF7C9AFF,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lists: (json['lists'] as List<dynamic>? ?? [])
            .map((l) => KanbanList.fromJson(l as Map<String, dynamic>))
            .toList(),
      );
}

/// Payload carried by a card while it is being dragged between lists.
class CardDragData {
  final KanbanCard card;
  final String fromListId;

  const CardDragData({required this.card, required this.fromListId});
}

/// Payload carried by a list while it is being dragged across the board.
class ListDragData {
  final String listId;
  final String title;
  final int cardCount;

  const ListDragData({
    required this.listId,
    required this.title,
    required this.cardCount,
  });
}
