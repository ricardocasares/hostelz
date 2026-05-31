//// Tests for the `log` abstraction, using an injected `emit` that asserts what
//// it receives — proving level routing and field accumulation without a backend.

import gleam/list
import log

pub fn info_routes_level_and_message_test() {
  let logger =
    log.new(fn(level, message, fields) {
      assert level == log.Info
      assert message == "hello"
      assert fields == []
      Nil
    })
  log.info(logger, "hello")
}

pub fn each_level_routes_test() {
  let capture = fn(expected: log.Level) {
    log.new(fn(level, _message, _fields) {
      assert level == expected
      Nil
    })
  }
  log.debug(capture(log.Debug), "m")
  log.info(capture(log.Info), "m")
  log.warn(capture(log.Warn), "m")
  log.error(capture(log.Error), "m")
}

pub fn with_accumulates_fields_in_order_test() {
  let logger =
    log.new(fn(_level, _message, fields) {
      assert fields
        == [log.string("a", "1"), log.int("b", 2), log.bool("c", True)]
      Nil
    })
  logger
  |> log.with([log.string("a", "1")])
  |> log.with([log.int("b", 2), log.bool("c", True)])
  |> log.info("hello")
}

pub fn null_logger_is_a_no_op_test() {
  // Must not crash and must return Nil.
  assert log.info(log.null(), "ignored") == Nil
}

pub fn level_to_string_test() {
  assert list.map(
      [log.Debug, log.Info, log.Warn, log.Error],
      log.level_to_string,
    )
    == ["debug", "info", "warn", "error"]
}
