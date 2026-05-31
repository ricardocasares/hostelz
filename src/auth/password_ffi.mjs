// Delegate password hashing to Bun's built-in argon2id implementation.
// Both return Promises, which map to Gleam `Promise` values.
export function hash(plaintext) {
  return Bun.password.hash(plaintext);
}

export function verify(plaintext, hash) {
  return Bun.password.verify(plaintext, hash);
}
