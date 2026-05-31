//// Session token hashing. We never store a raw session token — only its
//// SHA-256 (base64). Hashing is deterministic, so the token a client presents
//// can be hashed and looked up. Raw tokens are minted elsewhere with the
//// injected id generator (glanoid, crypto-random).

import gleam/bit_array
import gleam/crypto

pub fn hash(raw: String) -> String {
  raw
  |> bit_array.from_string
  |> crypto.hash(crypto.Sha256, _)
  |> bit_array.base64_encode(True)
}
