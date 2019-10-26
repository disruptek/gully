import strutils
import logging

export logging

type
  CuteLogger* = ref object of Logger
    forward: Logger

method log*(logger: CuteLogger; level: Level; args: varargs[string, `$`])
  {.locks: "unknown", raises: [].} =
  ## anything that isn't fatal gets a cute emoji
  var
    prefix: string
    arguments: seq[string]
  for a in args:
    arguments.add a
  case level:
  of lvlFatal:   # use this level for our most critical outputs
    prefix = ""  # and don't prefix them with a glyph
  of lvlError:
    prefix = "💥"
  of lvlWarn:
    prefix = "⚠️"
  of lvlNotice:
    prefix = "❌"
  of lvlInfo:
    prefix = "✔️"
  of lvlDebug:
    prefix = "🐛"
  of lvlAll, lvlNone:  # fwiw, this method is never called with these
    discard
  try:
    # separate logging arguments with spaces for convenience
    logger.forward.log(level, prefix & arguments.join(" "))
  except:
    discard

proc newCuteLogger*(console: ConsoleLogger): CuteLogger =
  ## create a new logger instance which forwards to the given console logger
  result = CuteLogger(forward: console)
