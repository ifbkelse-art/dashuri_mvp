# dashuri_storage

`KeyValueStore` (preferences) and `SecureKeyValueStore` (Keystore/Keychain-backed) contracts with implementations.

Never store access tokens (Supabase manages its own session), wallet balances, KYC data, message bodies or anything the server owns.
