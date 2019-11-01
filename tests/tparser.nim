import strutils
import tables
import unittest2

import gully
import gully/parser

suite "parser":
  let
    defaultRecipe {.used,compileTime.} = createDefaultRecipe()
    syntax = defaultRecipe.chooseSyntax()

  test "a series of unfortunate parses":
    let
      inputs = {
        "": "⏎",
        "   ": "⏎",
        " return": "Blank,Code⏎",
        "  return": "Blank,Code⏎",
        "return": "Code⏎",
        "return\n": "Code⏎⏎",
        "return \n": "Code⏎⏎",
        "return  \n": "Code⏎⏎",
        "echo 42": "Code⏎",
        "#[]#": "MlCode⏎",
        "##[]##": "MlDocs⏎",
        "#": "Comment⏎",
        "##": "Docs⏎",
        "# a full-line comment": "Comment⏎",
        "## a full-line doc comment": "Docs⏎",
        "#[test]#": "MlCode⏎",
        "# an eol comment ## runs to eol": "Comment⏎",
        "  #": "Blank,Comment⏎",
        "  ##": "Blank,Docs⏎",

        # should we ignore indentation
        # ahead of comments some day?

        "  # indented comment": "Blank,Comment⏎",
        "  ## indented doc": "Blank,Docs⏎",
        "  #[]#  if ##[]## false:": "Blank,MlCode,Blank,Code,MlDocs,Code⏎",
        """
          #[
            simple ml comment
          ]#
        """.unindent.strip: "MlCode⏎",

        """
          #[
          # ml comment with leader
          ]#
        """.unindent.strip: "MlCode⏎",

        "echo 42 # a comment-to-eol": "Code,Comment⏎",
        "if true: ## a doc comment-to-eol": "Code,Docs⏎",
        "if true:\n\t## a doc comment-to-eol": "Code⏎,Blank,Docs⏎",
        "echo false# no space": "Code,Comment⏎",
      }.toOrderedTable
    for text, expected in inputs.pairs:
      let
        parsed = parseDocument(text & "\n", syntax)
      if not parsed.ok or $parsed.asTokenList != expected:
        checkpoint "input: `" & text & "`"
        checkpoint "expected: `" & expected & "`"
        checkpoint "received: `" & $parsed.asTokenList & "`"
        checkpoint "rendered: `" & $parsed.render & "`"
        check parsed.ok
        check expected == $parsed.asTokenList
        break
  test "a series of unfortunate values":
    let
      inputs = {
        "": "⏎",
        "   ": "⏎",
        " return": "` `, `return`, ⏎",
        "  return": "`  `, `return`, ⏎",
        "if false:": "`if false:`, ⏎",
        "#[ thing1]#": "` thing1`, ⏎",
        "##[thing2 ]##": "`thing2 `, ⏎",
        "# goats": "` goats`, ⏎",
        "##pigs": "`pigs`, ⏎",
        "echo 42 # foo bar": "`echo 42 `, ` foo bar`, ⏎",
      }.toOrderedTable
    for text, expected in inputs.pairs:
      let
        parsed = parseDocument(text & "\n", syntax)
      if not parsed.ok or $parsed.render != expected:
        checkpoint "input: `" & text & "`"
        checkpoint "expected: " & expected
        checkpoint "received: `" & $parsed.asTokenList & "`"
        checkpoint "rendered: " & $parsed.render
        check parsed.ok
        check expected == $parsed.render
        break
