import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'injection_container.dart' as di;
import 'presentation/blocs/task_bloc.dart';
import 'presentation/blocs/task_event.dart';
import 'presentation/blocs/board_bloc.dart';
import 'presentation/blocs/board_event.dart';
import 'presentation/screens/board_screen.dart'; // Thay bằng đường dẫn file màn hình của bạn

void main() async {
  // 1. Đảm bảo các dịch vụ của Flutter đã sẵn sàng
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Cấu hình SQLite cho Desktop (Windows/macOS/Linux)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // 3. Khởi tạo Dependency Injection (Service Locator)
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // 4. Cung cấp TaskBloc cho toàn bộ ứng dụng
        // sl() sẽ tự động tìm kiếm TaskBloc đã đăng ký trong injection_container
        BlocProvider<TaskBloc>(
          create: (_) => di.sl<TaskBloc>()..add(LoadTasks()),
        ),
        BlocProvider<BoardBloc>(
          create: (_) => di.sl<BoardBloc>()..add(LoadBoards()),
        ),
      ],
      child: MaterialApp(
        title: 'KanbanFlow Nhóm 4',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
          scaffoldBackgroundColor: const Color(0xFFF4F7FC),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black87),
          ),
        ),
        // 5. Màn hình chính hiển thị bảng Kanban
        home: const BoardScreen(),
      ),
    );
  }
}
