//// The shared storage error every repository port returns. Storage concerns —
//// a missing row, a unique-constraint conflict, a stored row that fails
//// re-validation on load, or a backend failure — are the same across
//// aggregates, so one type lets a use case that spans several repositories wrap
//// any of their failures uniformly (`RepoFailed(RepoError)`).

pub type RepoError {
  /// No row exists for the given key.
  NotFound
  /// A unique constraint was violated (e.g. a duplicate slug/email/name).
  Conflict(String)
  /// A stored row could not be turned back into a valid domain value.
  Corrupt(String)
  /// The storage backend itself failed (connection, query, constraint, ...).
  StorageError(String)
}
