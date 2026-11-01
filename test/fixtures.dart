import 'package:vaultboard/models/models.dart';

Board exampleBoard({int listCount = 3, int cardCount = 2}) => Board(
  id: 'board-1',
  name: 'Release board',
  colorValue: 0xFF4DD0B1,
  createdAt: DateTime.utc(2026, 1, 2),
  lists: [
    for (var i = 0; i < listCount; i++)
      KanbanList(
        id: 'list-$i',
        title: i < 3 ? ['To Do', 'In Progress', 'Done'][i] : 'Review $i',
        cards: [
          if (i == 0)
            for (var j = 0; j < cardCount; j++)
              KanbanCard(
                id: 'card-$j',
                title: j == 0 ? 'Ship save files 🔒' : 'Task $j',
                description: j == 0 ? 'Păstrează tot\nSecond line' : '',
                createdAt: DateTime.utc(2026, 1, j + 1, 12, 30),
                priority: CardPriority.values[j % 4],
                isDone: j == 0,
              ),
        ],
      ),
  ],
);
