/// Supplies the bearer token for API calls. Implemented by the Supabase
/// adapter; kept as an interface so the network layer has no Supabase import.
abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}
