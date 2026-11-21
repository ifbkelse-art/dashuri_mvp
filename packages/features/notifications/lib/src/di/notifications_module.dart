import 'package:dashuri_network/dashuri_network.dart';
import 'package:get_it/get_it.dart';

import '../application/inbox_cubit.dart';
import '../data/datasources/notifications_remote_data_source.dart';
import '../data/repositories/notifications_repository_impl.dart';
import '../domain/repositories/notifications_repository.dart';
import '../domain/usecases/list_inbox.dart';
import '../domain/usecases/mark_read.dart';
import '../domain/usecases/register_device.dart';
import '../domain/usecases/unregister_device.dart';

/// Registers the notifications feature. Called once from the app's composition root.
/// Data sources and repositories are lazy singletons; use cases and
/// cubits are factories (a fresh cubit per page).
void registerNotificationsFeature(GetIt sl) {
  sl
    ..registerLazySingleton<NotificationsRemoteDataSource>(
      () => NotificationsRemoteDataSource(sl<ApiClient>()),
    )
    ..registerLazySingleton<NotificationsRepository>(
      () => NotificationsRepositoryImpl(sl<NotificationsRemoteDataSource>()),
    )
    ..registerFactory<RegisterDevice>(
      () => RegisterDevice(sl<NotificationsRepository>()),
    )
    ..registerFactory<UnregisterDevice>(
      () => UnregisterDevice(sl<NotificationsRepository>()),
    )
    ..registerFactory<ListInbox>(() => ListInbox(sl<NotificationsRepository>()))
    ..registerFactory<MarkRead>(() => MarkRead(sl<NotificationsRepository>()))
    ..registerFactory<InboxCubit>(() => InboxCubit(sl<ListInbox>()));
}
