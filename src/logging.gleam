//// The logging backend + env configuration. This is the ONLY module that
//// knows how logs are formatted and written; everything else depends on `log`.
//// A real logging library could replace `logger`/`format` here with no change
//// to call sites. Built-in writer because no Gleam logging lib currently fits
//// the JavaScript/Bun target on gleam_stdlib 1.x (see memory).

import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/string
import log.{type Field, type Level}

pub type Format {
  Text
  Json
}

pub type Config {
  Config(enabled: Bool, level: Level, format: Format)
}

/// Read config from an injected env getter (`envoy.get` in production, a fake in
/// tests). Defaults: enabled, `info`, `json`.
pub fn config(get_env: fn(String) -> Result(String, Nil)) -> Config {
  Config(
    enabled: parse_enabled(get_env("LOG_ENABLED")),
    level: parse_level(get_env("LOG_LEVEL")),
    format: parse_format(get_env("LOG_FORMAT")),
  )
}

/// Build the base logger. Disabled → a no-op sink. Otherwise a sink that filters
/// by level and writes one formatted line per event to stdout.
pub fn logger(config: Config) -> log.Logger {
  case config.enabled {
    False -> log.null()
    True ->
      log.new(fn(level, message, fields) {
        case meets(level, config.level) {
          False -> Nil
          True -> io.println(format(config.format, level, message, fields))
        }
      })
  }
}

/// Render one log line. Public so the formatting is unit-testable without stdout.
pub fn format(
  format: Format,
  level: Level,
  message: String,
  fields: List(Field),
) -> String {
  case format {
    Json -> json_line(level, message, fields)
    Text -> text_line(level, message, fields)
  }
}

fn json_line(level: Level, message: String, fields: List(Field)) -> String {
  [
    #("level", json.string(log.level_to_string(level))),
    #("message", json.string(message)),
    ..list.map(fields, field_to_json)
  ]
  |> json.object
  |> json.to_string
}

fn field_to_json(field: Field) -> #(String, json.Json) {
  case field.value {
    log.S(v) -> #(field.key, json.string(v))
    log.I(v) -> #(field.key, json.int(v))
    log.B(v) -> #(field.key, json.bool(v))
  }
}

fn text_line(level: Level, message: String, fields: List(Field)) -> String {
  let head = string.uppercase(log.level_to_string(level)) <> " " <> message
  case fields {
    [] -> head
    _ -> head <> " " <> string.join(list.map(fields, field_to_text), " ")
  }
}

fn field_to_text(field: Field) -> String {
  field.key <> "=" <> value_to_string(field.value)
}

fn value_to_string(value: log.Value) -> String {
  case value {
    log.S(v) -> v
    log.I(v) -> int.to_string(v)
    log.B(True) -> "true"
    log.B(False) -> "false"
  }
}

fn meets(level: Level, minimum: Level) -> Bool {
  severity(level) >= severity(minimum)
}

fn severity(level: Level) -> Int {
  case level {
    log.Debug -> 0
    log.Info -> 1
    log.Warn -> 2
    log.Error -> 3
  }
}

fn parse_enabled(raw: Result(String, Nil)) -> Bool {
  case raw {
    Ok("false") -> False
    Ok("0") -> False
    _ -> True
  }
}

fn parse_level(raw: Result(String, Nil)) -> Level {
  case raw {
    Ok("debug") -> log.Debug
    Ok("warn") -> log.Warn
    Ok("warning") -> log.Warn
    Ok("error") -> log.Error
    _ -> log.Info
  }
}

fn parse_format(raw: Result(String, Nil)) -> Format {
  case raw {
    Ok("text") -> Text
    _ -> Json
  }
}
