import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/connectivity_provider.dart';
import 'providers/queue_provider.dart';
import 'repositories/queue_repository.dart';
import 'screens/config_error_screen.dart';
import 'screens/queue_screen.dart';
import 'services/connectivity_service.dart';
import 'services/geolocation_service.dart';
import 'services/sync_service.dart';
import 'storage/local_queue_storage.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  if (_supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: _supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: _supabaseAnonKey,
    );
  }

  runApp(const Tp6App());
}

class Tp6App extends StatelessWidget {
  const Tp6App({super.key});

  static bool get isConfigured =>
      _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!Tp6App.isConfigured) {
      return const MaterialApp(home: ConfigErrorScreen());
    }

    final supabase = Supabase.instance.client;

    return MultiProvider(
      providers: [
        Provider<ConnectivityService>(
          create: (_) => ConnectivityService(supabase),
        ),
        Provider<LocalQueueStorage>(create: (_) => LocalQueueStorage()),
        Provider<GeolocationService>(create: (_) => GeolocationService()),
        Provider<QueueRemoteDataSource>(
          create: (_) => SupabaseQueueRemoteDataSource(supabase),
        ),
        Provider<QueueRepository>(
          create: (context) => QueueRepository(
            context.read<QueueRemoteDataSource>(),
          ),
        ),
        Provider<SyncService>(
          create: (context) => SyncService(
            context.read<LocalQueueStorage>(),
            context.read<QueueRepository>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (context) => ConnectivityProvider(
            context.read<ConnectivityService>(),
          )..initialize(),
        ),
        ChangeNotifierProvider(
          create: (context) => QueueProvider(
            context.read<QueueRepository>(),
            context.read<GeolocationService>(),
            context.read<LocalQueueStorage>(),
            context.read<SyncService>(),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Waiting Room',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        home: const QueueScreen(),
      ),
    );
  }
}
