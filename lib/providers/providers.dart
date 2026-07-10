import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/storage.dart';
import '../models/models.dart';
import '../theme.dart';

const _uuid = Uuid();

/// Owns the full immutable board tree and persists every mutation to Hive.
class BoardsNotifier extends StateNotifier<List<Board>> {
  BoardsNotifier() : super(VaultStorage.loadBoards());

  void _commit(List<Board> next) {
    state = next;
    VaultStorage.saveBoards(next);
  }

  void _updateBoard(String boardId, Board Function(Board) transform) {
    _commit([
      for (final b in state)
        if (b.id == boardId) transform(b) else b,
    ]);
  }

  void _updateList(
    String boardId,
    String listId,
    KanbanList Function(KanbanList) transform,
  ) {
    _updateBoard(
      boardId,
      (board) => board.copyWith(lists: [
        for (final l in board.lists)
          if (l.id == listId) transform(l) else l,
      ]),
    );
  }

  // ---- Boards -------------------------------------------------------------

  String addBoard(String name, {int? colorValue}) {
    final id = _uuid.v4();
    final board = Board(
      id: id,
      name: name,
      colorValue: colorValue ??
          VaultColors
              .boardPalette[state.length % VaultColors.boardPalette.length]
              .toARGB32(),
      createdAt: DateTime.now(),
      lists: [
        KanbanList(id: _uuid.v4(), title: 'To Do'),
        KanbanList(id: _uuid.v4(), title: 'In Progress'),
        KanbanList(id: _uuid.v4(), title: 'Done'),
      ],
    );
    _commit([...state, board]);
    return id;
  }

  void renameBoard(String boardId, String name) =>
      _updateBoard(boardId, (b) => b.copyWith(name: name));

  void deleteBoard(String boardId) =>
      _commit(state.where((b) => b.id != boardId).toList());

  // ---- Lists --------------------------------------------------------------

  void addList(String boardId, String title) => _updateBoard(
        boardId,
        (b) => b.copyWith(
          lists: [...b.lists, KanbanList(id: _uuid.v4(), title: title)],
        ),
      );

  void renameList(String boardId, String listId, String title) =>
      _updateList(boardId, listId, (l) => l.copyWith(title: title));

  void deleteList(String boardId, String listId) => _updateBoard(
        boardId,
        (b) => b.copyWith(
          lists: b.lists.where((l) => l.id != listId).toList(),
        ),
      );

  /// Moves a list so it ends up before the list currently at [toIndex]
  /// (insert-before semantics; [toIndex] == lists.length drops it at the end).
  void moveList({
    required String boardId,
    required String listId,
    required int toIndex,
  }) {
    _updateBoard(boardId, (board) {
      final fromIndex = board.lists.indexWhere((l) => l.id == listId);
      if (fromIndex == -1) return board;
      final lists = List<KanbanList>.of(board.lists);
      final list = lists.removeAt(fromIndex);
      var insertAt = toIndex;
      if (fromIndex < toIndex) insertAt -= 1;
      lists.insert(insertAt.clamp(0, lists.length), list);
      return board.copyWith(lists: lists);
    });
  }

  /// Shifts a list one step left/right ([delta] of -1 or 1).
  void moveListBy(String boardId, String listId, int delta) {
    _updateBoard(boardId, (board) {
      final fromIndex = board.lists.indexWhere((l) => l.id == listId);
      if (fromIndex == -1) return board;
      final target = (fromIndex + delta).clamp(0, board.lists.length - 1);
      if (target == fromIndex) return board;
      final lists = List<KanbanList>.of(board.lists);
      final list = lists.removeAt(fromIndex);
      lists.insert(target, list);
      return board.copyWith(lists: lists);
    });
  }

  void clearDoneCards(String boardId, String listId) => _updateList(
        boardId,
        listId,
        (l) => l.copyWith(cards: l.cards.where((c) => !c.isDone).toList()),
      );

  // ---- Cards --------------------------------------------------------------

  void addCard(String boardId, String listId, String title) => _updateList(
        boardId,
        listId,
        (l) => l.copyWith(cards: [
          ...l.cards,
          KanbanCard(id: _uuid.v4(), title: title, createdAt: DateTime.now()),
        ]),
      );

  void updateCard(String boardId, String listId, KanbanCard card) =>
      _updateList(
        boardId,
        listId,
        (l) => l.copyWith(cards: [
          for (final c in l.cards)
            if (c.id == card.id) card else c,
        ]),
      );

  void deleteCard(String boardId, String listId, String cardId) => _updateList(
        boardId,
        listId,
        (l) => l.copyWith(cards: l.cards.where((c) => c.id != cardId).toList()),
      );

  /// Moves a card to [toIndex] inside [toListId] (which may be the same
  /// list). Index math accounts for the removal shifting positions.
  void moveCard({
    required String boardId,
    required String cardId,
    required String fromListId,
    required String toListId,
    required int toIndex,
  }) {
    _updateBoard(boardId, (board) {
      KanbanCard? card;
      var fromIndex = -1;
      for (final l in board.lists) {
        if (l.id == fromListId) {
          fromIndex = l.cards.indexWhere((c) => c.id == cardId);
          if (fromIndex != -1) card = l.cards[fromIndex];
        }
      }
      if (card == null) return board;

      final lists = <KanbanList>[];
      for (final l in board.lists) {
        if (l.id == fromListId && l.id == toListId) {
          final cards = List<KanbanCard>.of(l.cards)..removeAt(fromIndex);
          var insertAt = toIndex;
          if (fromIndex < toIndex) insertAt -= 1;
          cards.insert(insertAt.clamp(0, cards.length), card);
          lists.add(l.copyWith(cards: cards));
        } else if (l.id == fromListId) {
          lists.add(
            l.copyWith(cards: List<KanbanCard>.of(l.cards)..removeAt(fromIndex)),
          );
        } else if (l.id == toListId) {
          final cards = List<KanbanCard>.of(l.cards)
            ..insert(toIndex.clamp(0, l.cards.length), card);
          lists.add(l.copyWith(cards: cards));
        } else {
          lists.add(l);
        }
      }
      return board.copyWith(lists: lists);
    });
  }
}

final boardsProvider = StateNotifierProvider<BoardsNotifier, List<Board>>(
  (ref) => BoardsNotifier(),
);

/// Remembers which board is open, restored across restarts.
class SelectedBoardNotifier extends StateNotifier<String?> {
  SelectedBoardNotifier(List<Board> boards) : super(_restore(boards));

  static String? _restore(List<Board> boards) {
    final saved = VaultStorage.loadSelectedBoardId();
    if (saved != null && boards.any((b) => b.id == saved)) return saved;
    return boards.isEmpty ? null : boards.first.id;
  }

  void select(String? id) {
    state = id;
    VaultStorage.saveSelectedBoardId(id);
  }
}

final selectedBoardIdProvider =
    StateNotifierProvider<SelectedBoardNotifier, String?>(
  (ref) => SelectedBoardNotifier(ref.read(boardsProvider)),
);

/// The board currently shown on the canvas; falls back to the first board if
/// the stored selection no longer exists.
final currentBoardProvider = Provider<Board?>((ref) {
  final boards = ref.watch(boardsProvider);
  final id = ref.watch(selectedBoardIdProvider);
  if (boards.isEmpty) return null;
  return boards.firstWhere((b) => b.id == id, orElse: () => boards.first);
});

/// Live text query used to spotlight matching cards across the whole board.
final searchQueryProvider = StateProvider<String>((ref) => '');

final sidebarCollapsedProvider = StateProvider<bool>((ref) => false);

class BoardStats {
  final int total;
  final int done;

  const BoardStats({required this.total, required this.done});

  double get percent => total == 0 ? 0 : done / total;
}

/// Completion stats for the current board, recomputed on every change.
final boardStatsProvider = Provider<BoardStats>((ref) {
  final board = ref.watch(currentBoardProvider);
  if (board == null) return const BoardStats(total: 0, done: 0);
  var total = 0;
  var done = 0;
  for (final list in board.lists) {
    for (final card in list.cards) {
      total++;
      if (card.isDone) done++;
    }
  }
  return BoardStats(total: total, done: done);
});
