import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../app_preferences.dart';

import '../../domain/entities/board.dart';
import '../blocs/auth/auth_bloc.dart';
import '../blocs/auth/auth_state.dart';
import '../blocs/board_bloc.dart';
import '../blocs/board_event.dart';
import '../blocs/board_state.dart';

class WorkspaceMenuScreen extends StatelessWidget {
  final String? selectedBoardId;

  const WorkspaceMenuScreen({super.key, required this.selectedBoardId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppPreferences.tr('Không gian làm việc', 'Workspace'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showAddBoardDialog(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E66FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        AppPreferences.tr('Tạo bảng mới', 'Create new board'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.pop(context); // Đóng menu
                  Navigator.pushNamed(context, '/my-tasks');
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2125) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          AppPreferences.tr('Công việc của tôi', 'My Tasks'),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(indent: 16, endIndent: 16),
            Expanded(
              child: BlocBuilder<BoardBloc, BoardState>(
                builder: (context, state) {
                  if (state is BoardLoading) {
                    return const Center(child: CircularProgressIndicator.adaptive());
                  }
                  if (state is BoardError) {
                    return Center(
                      child: Text(
                        '${AppPreferences.tr('Lỗi', 'Error')}: ${state.message}',
                      ),
                    );
                  }
                  if (state is! BoardLoaded) {
                    return const SizedBox.shrink();
                  }

                  final boards = state.boards;
                  if (boards.isEmpty) {
                    return Center(
                      child: Text(
                        AppPreferences.tr(
                          'Chưa có bảng nào.',
                          'No boards yet.',
                        ),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: boards.length,
                    // SỬA LỖI TẠI ĐÂY: Đổi (_, _) thành (context, index)
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final board = boards[index];
                      final selected = board.id == selectedBoardId;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, board.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? Colors.blueAccent.withValues(alpha: 0.12)
                                : (isDark ? const Color(0xFF1E2125) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? Colors.blueAccent.withValues(alpha: 0.45)
                                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  board.title,
                                  style: TextStyle(
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 15,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: AppPreferences.tr('Xóa', 'Delete'),
                                onPressed: () => _showDeleteBoardDialog(context, board),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddBoardDialog(BuildContext context) {
    final titleController = TextEditingController();
    const accentColor = Colors.blueAccent;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(AppPreferences.tr('Tạo bảng mới', 'Create board')),
        content: TextField(
          controller: titleController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: AppPreferences.tr('Nhập tên bảng...', 'Enter title...'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              final authState = context.read<AuthBloc>().state;
              final userId = authState is Authenticated ? authState.user.id : '';
              context.read<BoardBloc>().add(
                    AddBoardEvent(
                      Board(
                        id: const Uuid().v4(),
                        title: title,
                        ownerId: userId,
                        createdAt: DateTime.now().toIso8601String(),
                      ),
                    ),
                  );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: accentColor, foregroundColor: Colors.white),
            child: Text(AppPreferences.tr('Tạo', 'Create')),
          ),
        ],
      ),
    );
  }

  void _showDeleteBoardDialog(BuildContext context, Board board) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppPreferences.tr('Xác nhận xóa', 'Confirm delete')),
        content: Text(
          AppPreferences.tr(
            'Bạn có chắc muốn xóa bảng "${board.title}"?',
            'Are you sure you want to delete board "${board.title}"?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppPreferences.tr('Hủy', 'Cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<BoardBloc>().add(DeleteBoardEvent(board.id));
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(AppPreferences.tr('Xóa', 'Delete')),
          ),
        ],
      ),
    );
  }
}
