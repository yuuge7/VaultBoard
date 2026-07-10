import 'package:flutter_test/flutter_test.dart';
import 'package:vaultboard/models/models.dart';

void main() {
  test('KanbanCard JSON round-trip preserves all fields', () {
    final card = KanbanCard(
      id: 'c1',
      title: 'Ship v1',
      description: 'Final polish pass',
      createdAt: DateTime(2026, 7, 9, 12, 30),
      priority: CardPriority.high,
      isDone: true,
    );

    final restored = KanbanCard.fromJson(card.toJson());

    expect(restored.id, card.id);
    expect(restored.title, card.title);
    expect(restored.description, card.description);
    expect(restored.createdAt, card.createdAt);
    expect(restored.priority, card.priority);
    expect(restored.isDone, card.isDone);
  });

  test('Board JSON round-trip preserves nested lists and cards', () {
    final board = Board(
      id: 'b1',
      name: 'Launch',
      colorValue: 0xFF7C9AFF,
      createdAt: DateTime(2026, 7, 9),
      lists: [
        KanbanList(
          id: 'l1',
          title: 'To Do',
          cards: [
            KanbanCard(id: 'c1', title: 'Task', createdAt: DateTime(2026, 7, 9)),
          ],
        ),
      ],
    );

    final restored = Board.fromJson(board.toJson());

    expect(restored.lists.length, 1);
    expect(restored.lists.first.cards.first.title, 'Task');
    expect(restored.colorValue, 0xFF7C9AFF);
  });
}
