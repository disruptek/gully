import strutils
import streams
import unittest2

import gully

var
  defaultRecipe = createDefaultRecipe()

suite "documents":
  let
    sampleDoc {.used.} = """
    echo "hello world"
    """.unindent.strip
    doc = defaultRecipe.newDocument(newStringStream(sampleDoc & "\n"))

  test "assumptions":
    check doc.len == 1
    check $doc == "echo \"hello world\"\n"
    for line in doc.items:
      check line.len == "echo \"hello world\"\n".len
    check defaultRecipe[Language].lang == Lang.Nim
