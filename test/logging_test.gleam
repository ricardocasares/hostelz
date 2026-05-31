//// Tests for the logging backend: env → Config mapping (injected getter) and
//// the text/json line rendering (the `format` function — no stdout needed).

import gleam/dict
import log
import logging

fn from(pairs: List(#(String, String))) -> fn(String) -> Result(String, Nil) {
  let env = dict.from_list(pairs)
  fn(key) { dict.get(env, key) }
}

pub fn config_defaults_test() {
  assert logging.config(from([]))
    == logging.Config(enabled: True, level: log.Info, format: logging.Json)
}

pub fn config_disabled_test() {
  let config = logging.config(from([#("LOG_ENABLED", "false")]))
  assert config.enabled == False
}

pub fn config_level_test() {
  assert logging.config(from([#("LOG_LEVEL", "debug")])).level == log.Debug
  assert logging.config(from([#("LOG_LEVEL", "error")])).level == log.Error
  // unknown → default info
  assert logging.config(from([#("LOG_LEVEL", "bogus")])).level == log.Info
}

pub fn config_format_test() {
  assert logging.config(from([#("LOG_FORMAT", "text")])).format == logging.Text
  // unknown → default json
  assert logging.config(from([#("LOG_FORMAT", "bogus")])).format == logging.Json
}

pub fn format_json_test() {
  assert logging.format(logging.Json, log.Info, "hi", [
      log.string("a", "1"),
      log.int("n", 2),
      log.bool("ok", True),
    ])
    == "{\"level\":\"info\",\"message\":\"hi\",\"a\":\"1\",\"n\":2,\"ok\":true}"
}

pub fn format_text_test() {
  assert logging.format(logging.Text, log.Warn, "hi", [log.string("a", "1")])
    == "WARN hi a=1"
}

pub fn format_text_no_fields_test() {
  assert logging.format(logging.Text, log.Info, "hi", []) == "INFO hi"
}
