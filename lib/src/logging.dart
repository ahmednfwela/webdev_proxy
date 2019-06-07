// TODO: credit build_runner_core/build_runner for these utils

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io' as io;

import 'package:io/ansi.dart';
import 'package:logging/logging.dart';
import 'package:stack_trace/stack_trace.dart';

// Ensures this message does not get overwritten by later logs.
const _logSuffix = '\n';

final Logger log = Logger('Proxy');

StringBuffer colorLog(LogRecord record, {bool verbose}) {
  verbose ??= false;

  AnsiCode color;
  if (record.level < Level.WARNING) {
    color = cyan;
  } else if (record.level < Level.SEVERE) {
    color = yellow;
  } else {
    color = red;
  }
  final level = color.wrap('[${record.level}]');
  final eraseLine = ansiOutputEnabled && !verbose ? '\x1b[2K\r' : '';
  final lines = <Object>[
    '$eraseLine$level ${_loggerName(record, verbose)}${record.message}'
  ];

  if (record.error != null) {
    lines.add(record.error);
  }

  if (record.stackTrace != null && verbose) {
    final trace = new Trace.from(record.stackTrace).terse;
    lines.add(trace);
  }

  final message = StringBuffer(lines.join('\n'));

  // We always add an extra newline at the end of each message, so it
  // isn't multiline unless we see > 2 lines.
  final multiLine = convert.LineSplitter.split(message.toString()).length > 2;

  if (record.level > Level.INFO || !ansiOutputEnabled || multiLine || verbose) {
    if (!lines.last.toString().endsWith('\n')) {
      // Add a newline to the output so the last line isn't written over.
      message.writeln('');
    }
  }
  return message;
}

/// Returns a human readable string for a duration.
///
/// Handles durations that span up to hours - this will not be a good fit for
/// durations that are longer than days.
///
/// Always attempts 2 'levels' of precision. Will show hours/minutes,
/// minutes/seconds, seconds/tenths of a second, or milliseconds depending on
/// the largest level that needs to be displayed.
String humanReadable(Duration duration) {
  if (duration < const Duration(seconds: 1)) {
    return '${duration.inMilliseconds}ms';
  }
  if (duration < const Duration(minutes: 1)) {
    return '${(duration.inMilliseconds / 1000.0).toStringAsFixed(1)}s';
  }
  if (duration < const Duration(hours: 1)) {
    final minutes = duration.inMinutes;
    final remaining = duration - Duration(minutes: minutes);
    return '${minutes}m ${remaining.inSeconds}s';
  }
  final hours = duration.inHours;
  final remaining = duration - Duration(hours: hours);
  return '${hours}h ${remaining.inMinutes}m';
}

/// Logs an asynchronous [action] with [description] before and after.
///
/// Returns a future that completes after the action and logging finishes.
Future<T> logTimedAsync<T>(
  Logger logger,
  String description,
  Future<T> action(), {
  Level level = Level.INFO,
}) async {
  final watch = Stopwatch()..start();
  logger.log(level, '$description...');
  final result = await action();
  watch.stop();
  final time = '${humanReadable(watch.elapsed)}$_logSuffix';
  logger.log(level, '$description completed, took $time');
  return result;
}

/// Logs a synchronous [action] with [description] before and after.
///
/// Returns a future that completes after the action and logging finishes.
T logTimedSync<T>(
  Logger logger,
  String description,
  T action(), {
  Level level = Level.INFO,
}) {
  final watch = Stopwatch()..start();
  logger.log(level, '$description...');
  final result = action();
  watch.stop();
  final time = '${humanReadable(watch.elapsed)}$_logSuffix';
  logger.log(level, '$description completed, took $time');
  return result;
}

Function(LogRecord) stdIOLogListener({bool verbose}) =>
    (record) => io.stdout.write(colorLog(record, verbose: verbose));

String _loggerName(LogRecord record, bool verbose) {
  final knownNames = const [
    'Proxy',
  ];
  final maybeSplit = record.level >= Level.WARNING ? '\n' : '';
  return verbose || !knownNames.contains(record.loggerName)
      ? '${record.loggerName}:$maybeSplit'
      : '';
}
