//// The shared dependencies threaded through the router and its handlers.

// brioche is Bun's SQL client; aliased to `db` so it doesn't clash with the
// generated `sql` modules elsewhere.
import brioche/sql as db
import glanoid

/// The shared dependencies threaded through every handler: the database
/// connection, plus an id generator so use cases can mint identities without
/// knowing how (here, nanoids via glanoid). Add anything else handlers need
/// (config, HTTP clients, ...) here.
pub type Deps {
  Deps(db: db.Connection, generate_id: fn() -> String)
}

/// Builds the shared dependencies once.
///
/// brioche/Bun connections are pooled, so we want exactly one per process —
/// the entrypoint (`api.main`) calls this a single time and threads the result
/// through every request. The connection is lazy, so this doesn't actually hit
/// the database until a query runs. The nanoid generator is built once and
/// reused; each call produces a fresh 21-character id.
pub fn deps() -> Deps {
  let assert Ok(db) = db.connect(db.default_config())
  let assert Ok(nanoid) = glanoid.make_generator(glanoid.default_alphabet)
  Deps(db:, generate_id: fn() { nanoid(21) })
}
