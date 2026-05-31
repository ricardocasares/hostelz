//// The logging abstraction the rest of the app depends on — handlers,
//// middleware and the router context use only this, never a concrete backend.
//// A `Logger` is a sink (an `emit` closure) plus the fields bound so far;
//// `with` layers on more fields, and the level/format/output are entirely the
//// backend's concern (see `logging`). This keeps the backend swappable.

import gleam/list

pub type Level {
  Debug
  Info
  Warn
  Error
}

pub type Value {
  S(String)
  I(Int)
  B(Bool)
}

pub type Field {
  Field(key: String, value: Value)
}

pub fn string(key: String, value: String) -> Field {
  Field(key, S(value))
}

pub fn int(key: String, value: Int) -> Field {
  Field(key, I(value))
}

pub fn bool(key: String, value: Bool) -> Field {
  Field(key, B(value))
}

pub opaque type Logger {
  Logger(emit: fn(Level, String, List(Field)) -> Nil, fields: List(Field))
}

/// Build a logger from a sink. The backend supplies `emit` (level filtering +
/// formatting + output live there).
pub fn new(emit: fn(Level, String, List(Field)) -> Nil) -> Logger {
  Logger(emit:, fields: [])
}

/// A logger that discards everything (logging disabled / tests).
pub fn null() -> Logger {
  Logger(fn(_, _, _) { Nil }, [])
}

/// Derive a logger with extra fields bound (appended, preserving order).
pub fn with(logger: Logger, fields: List(Field)) -> Logger {
  Logger(..logger, fields: list.append(logger.fields, fields))
}

pub fn debug(logger: Logger, message: String) -> Nil {
  logger.emit(Debug, message, logger.fields)
}

pub fn info(logger: Logger, message: String) -> Nil {
  logger.emit(Info, message, logger.fields)
}

pub fn warn(logger: Logger, message: String) -> Nil {
  logger.emit(Warn, message, logger.fields)
}

pub fn error(logger: Logger, message: String) -> Nil {
  logger.emit(Error, message, logger.fields)
}

pub fn level_to_string(level: Level) -> String {
  case level {
    Debug -> "debug"
    Info -> "info"
    Warn -> "warn"
    Error -> "error"
  }
}
