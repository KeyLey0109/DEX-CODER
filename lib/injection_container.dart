import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Data Sources
import 'data/datasources/local_database.dart';

// Import Repositories
import 'data/repositories/auth_repository_impl.dart';
import 'data/repositories/board_repository_impl.dart';
import 'data/repositories/task_repository_impl.dart';
import 'data/repositories/notification_repository.dart';
import 'data/repositories/task_interaction_repository.dart';
import 'data/repositories/friend_repository.dart';
import 'data/repositories/chat_repository.dart';

// Import Domain Repositories
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/board_repository.dart';
import 'domain/repositories/task_repository.dart';

// Import Use Cases
import 'domain/usecases/task_usecases.dart';
import 'domain/usecases/board_usecases.dart';

// Import Blocs & Services
import 'presentation/blocs/auth/auth_bloc.dart';
import 'presentation/blocs/task_bloc.dart';
import 'presentation/blocs/board_bloc.dart';
import 'core/services/ai_service.dart';

final sl = GetIt.instance; // Service Locator

Future<void> init() async {
  try {
    // ==========================================
    // 1. CORE SERVICES & DATA SOURCES
    // ==========================================
    
    // Đăng ký Supabase Client trực tiếp từ instance đã init ở main
    if (!sl.isRegistered<SupabaseClient>()) {
      sl.registerLazySingleton<SupabaseClient>(() => Supabase.instance.client);
    }

    // Khởi tạo Local Database (Cần đảm bảo file này không dùng FFI trên iOS)
    sl.registerLazySingleton<LocalDatabase>(() => LocalDatabase());
    
    // Khởi tạo AI Service
    sl.registerLazySingleton<AiService>(() => AiService());

    // ==========================================
    // 2. REPOSITORIES (Đăng ký trước UseCases)
    // ==========================================
    
    sl.registerLazySingleton<NotificationRepository>(
      () => NotificationRepository(client: sl()),
    );

    sl.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(supabaseClient: sl()),
    );

    sl.registerLazySingleton<TaskRepository>(
      () => TaskRepositoryImpl(
        supabaseClient: sl(),
        localDatabase: sl(),
        notificationRepository: sl(),
      ),
    );

    sl.registerLazySingleton<BoardRepository>(
      () => BoardRepositoryImpl(
        supabaseClient: sl(), 
        localDatabase: sl(),
      ),
    );

    sl.registerLazySingleton<TaskInteractionRepository>(
      () => TaskInteractionRepository(
        client: sl(), 
        notificationRepository: sl(),
      ),
    );

    sl.registerLazySingleton<FriendRepository>(
      () => FriendRepository(
        client: sl(), 
        notificationRepository: sl(),
      ),
    );

    sl.registerLazySingleton<ChatRepository>(
      () => ChatRepository(
        client: sl(), 
        notificationRepository: sl(),
      ),
    );

    // ==========================================
    // 3. USE CASES
    // ==========================================
    
    // Task UseCases
    sl.registerLazySingleton(() => GetTasks(sl()));
    sl.registerLazySingleton(() => AddTask(sl()));
    sl.registerLazySingleton(() => UpdateTask(sl()));
    sl.registerLazySingleton(() => DeleteTask(sl()));

    // Board UseCases
    sl.registerLazySingleton(() => GetBoards(sl()));
    sl.registerLazySingleton(() => AddBoard(sl()));
    sl.registerLazySingleton(() => UpdateBoard(sl()));
    sl.registerLazySingleton(() => DeleteBoard(sl()));
    sl.registerLazySingleton(() => WatchBoardsUseCase(sl()));

    // ==========================================
    // 4. BLOCS (Đăng ký Factory để tạo mới mỗi khi cần)
    // ==========================================
    
    sl.registerFactory(() => AuthBloc(authRepository: sl()));
    
    sl.registerFactory(
      () => TaskBloc(
        getTasks: sl(),
        addTask: sl(),
        updateTask: sl(),
        deleteTask: sl(),
      ),
    );
    
    sl.registerFactory(
      () => BoardBloc(
        getBoards: sl(),
        addBoard: sl(),
        updateBoard: sl(),
        deleteBoard: sl(),
        watchBoards: sl(),
      ),
    );

    print("--- [DI] Injection Container: All dependencies registered successfully ---");
  } catch (e, stacktrace) {
    print("--- [DI] ERROR during injection: $e ---");
    print(stacktrace);
    // Không quăng lỗi (rethrow) để tránh treo app ở màn hình trắng
  }
}