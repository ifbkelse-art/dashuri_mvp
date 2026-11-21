/// Push-token registration and the in-app notification inbox.
///
/// Public API: entities, repository contract, use cases, cubits, DI
/// registration and routes. `src/data` stays private to this package.
library;

export 'src/application/inbox_cubit.dart';
export 'src/di/notifications_module.dart';
export 'src/domain/entities/inbox_item.dart';
export 'src/domain/repositories/notifications_repository.dart';
export 'src/domain/usecases/list_inbox.dart';
export 'src/domain/usecases/mark_read.dart';
export 'src/domain/usecases/register_device.dart';
export 'src/domain/usecases/unregister_device.dart';
export 'src/domain/usecases/watch_new_notifications.dart';
export 'src/presentation/pages/notifications_page.dart';
export 'src/routes/notifications_routes.dart';
