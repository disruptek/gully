import strutils
import tables
import streams
import unittest2

import gully
import gully/parser

var
  defaultRecipe = createDefaultRecipe()

suite "parser":
  let
    defaultRecipe {.used,compileTime.} = createDefaultRecipe()

  when not defined(npegTrace):
    test "simple code":
      let
        inputs = {
          "": "⏎",
          "   ": "⏎",
          "return": "Code⏎",
          "return\n": "Code⏎⏎",
          "return \n": "Code⏎⏎",
          "return  \n": "Code⏎⏎",
          "echo 42": "Code⏎",
        }.toOrderedTable
      for text, expected in inputs.pairs:
        let
          parsed = parseDocument(text)
        if not parsed.ok or $parsed.asTokenList != expected:
          checkpoint "input: `" & text & "`"
          checkpoint "expected: `" & expected & "`"
          checkpoint "received: `" & $parsed.asTokenList & "`"
          check parsed.ok
          check expected == $parsed.asTokenList
          break

  test "multiline tokens":
    let
      inputs = {
        "#[test]#": "MlCode⏎",
        "#[]#": "MlCode⏎",
#        "##[]##": "MlDocs⏎",
#        "#[": "Comment⏎",
#        "##[": "Docs⏎",
      }.toOrderedTable
    for text, expected in inputs.pairs:
      let
        parsed = parseDocument(text)
      if not parsed.ok or $parsed.asTokenList != expected:
        checkpoint "input: `" & text & "`"
        checkpoint "expected: `" & expected & "`"
        checkpoint "received: `" & $parsed.asTokenList & "`"
        checkpoint "rendered: " & $parsed.render
        check parsed.ok
        check expected == $parsed.asTokenList
        break

  when not defined(npegTrace):
    test "simple comment lines":
      let
        inputs = {
          "#": "Comment⏎",
          "##": "Docs⏎",
          "# a full-line comment": "Comment⏎",
          "## a full-line doc comment": "Docs⏎",
          "  #": "Blank,Comment⏎",
          "  ##": "Blank,Docs⏎",

          # should we ignore indentation
          # ahead of comments some day?

          "  # indented comment": "Blank,Comment⏎",
          "  ## indented doc": "Blank,Docs⏎",
        }.toOrderedTable
      for text, expected in inputs.pairs:
        let
          parsed = parseDocument(text)
        if not parsed.ok or $parsed.asTokenList != expected:
          checkpoint "input: `" & text & "`"
          checkpoint "expected: `" & expected & "`"
          checkpoint "received: `" & $parsed.asTokenList & "`"
          checkpoint "rendered: " & $parsed.render
          check parsed.ok
          check expected == $parsed.asTokenList
          break

  when not defined(npegTrace):
    test "orphans, bastards, and brawlers":
      let
        inputs = {
          "echo 42 # a comment-to-eol": "Code,Comment⏎",

          """
            if true: ## a doc comment-to-eol
              # indented comment
              echo true # indented code
              echo false# indented code, no space
          """.unindent.strip:
            "Code,Docs⏎" &
            "Code,Comment⏎" &
            "Code,Comment⏎",

          """
            #[
              simple doc comment
            ]#
          """.unindent.strip: "MlCode⏎",

          """
            #[
            # ml comment with leader
            ]#
          """.unindent.strip: "MlCode⏎",

          """
            #[ ml comment on fewer lines
            ]#
          """.unindent.strip: "MlCode⏎",

          """
            #[ ml comment on one line ]#
          """.unindent.strip: "MlCode⏎",

        }.toOrderedTable
      for text, expected in inputs.pairs:
        let
          parsed = parseDocument(text)
        if not parsed.ok or $parsed.asTokenList != expected:
          checkpoint "input: `" & text & "`"
          checkpoint "expected: `" & expected & "`"
          checkpoint "received: `" & $parsed.asTokenList & "`"
          check parsed.ok
          check expected == $parsed.asTokenList
          break
