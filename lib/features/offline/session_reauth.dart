import 'package:liblanis/liblanis.dart';

/// Runs [action] and, if it fails with a non-transport, non-configuration
/// error (such as an expired SPH session cookie), re-authenticates [session]
/// once via [LanisSession.reauthenticateIfStale] and retries [action].
Future<T> runWithSessionReauth<T>(
  LanisSession? session,
  Future<T> Function() action,
) async {
  if (session == null) return action();
  final observedGeneration = session.authGeneration;
  try {
    return await action();
  } catch (error) {
    if (error is CacheUnavailableException ||
        error is ConfigurationException ||
        error is NotSupportedException ||
        CacheService.isTransportFailure(error)) {
      rethrow;
    }
    await session.reauthenticateIfStale(observedGeneration);
    return action();
  }
}
