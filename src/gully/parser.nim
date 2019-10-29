import strutils
import npeg

const
  EndOfLine* = Whitespace - {' ', '\t', '\v'}

type
  ParsedDocument* = ref object
    ok*: bool
    syntax*: Syntax
    series*: seq[TokenText]

  Syntax* = ref object
    docs*: string
    eolc*: string
    tabsize*: int
    header*: string
    footer*: string
    leader*: string

  Token {.pure.} = enum
    Blank
    Code
    Comment
    Docs
    MlCode
    MlDocs
    Newline = "⏎"

  TokenText = tuple
    kind: Token
    text: string

proc `$`*(tokens: seq[Token]): string =
  for t in tokens:
    if result.len != 0:
      if t != Newline:
        result &= ","
    result &= $t

proc asTokenList*(parsed: ParsedDocument): seq[Token] =
  for tt in parsed.series:
    result.add tt.kind

proc render*(parsed: ParsedDocument): string =
  for tt in parsed.series:
    if result.len > 0:
      result &= ", "
    if tt.text == "\n":
      result.add $Newline
    else:
      result.add "`" & tt.text & "`"

proc parseDocument*(input: string; syntax: Syntax = nil): ParsedDocument =
  var
    syn: Syntax

  if syntax == nil:
    syn = Syntax(docs: "##", eolc: "#", tabsize: 2,
                 header: "#[", footer: "]#", leader: "# ")
  else:
    syn = syntax

  var
    record = ParsedDocument(ok: false, syntax: syn)
  # FIXME: cleanup, cache peg
  let
    peggy = peg "document":
      # one pound
      lb <- '#'
      # two pounds
      lblb <- lb * lb
      #[ multi-line opener, closer ]#
      mlo <- '['
      mlc <- ']'

      #[ multi-line code comments ]#
      begcML <- lb * mlo
      endcML <- mlc * lb
      mlcComment <- begcML * >*(1 - endcML) * endcML:
        record.series.add (kind: MlCode, text: $1)

      # multi-line doc comments
      begdML <- lblb * mlo
      enddML <- mlc * lblb
      mldComment <- begdML * >*(1 - enddML) * enddML:
        record.series.add (kind: MlDocs, text: $1)

      # thus, any multi-line comment
      multiline <- mldComment | mlcComment

      white <- {'\t', ' '}
      nl <- ?'\r' * '\n'
      text <- 1 - nl

      # we don't notate newlines inside multi-line comments
      newline <- >nl:
        record.series.add (kind: Newline, text: $1)

      # code comments like this one
      codComment <- lb * >*text:
        record.series.add (kind: Comment, text: $1)

      # doc comments
      docComment <- lblb * >*text:
        record.series.add (kind: Docs, text: $1)

      # capturing the comments
      comment <- docComment | codComment

      # significant blanks precede non-blank text
      blanks <- >+white - !white - nl:
        record.series.add (kind: Blank, text: $1)

      # code can terminate at an lb
      code <- >+(text - lb):
        record.series.add (kind: Code, text: $1)

      # indent precedes content; it may have multi-line comments in it
      indent <- multiline | blanks

      # content follows indent; it may have multi-line comments in it
      content <- multiline | code

      # a line with whitespace or less
      emptyline <- *white * newline

      # a line with optional indent, code, comments
      fullline <- *indent * *content * ?comment * newline

      # lines holding only whitespace are parsed as Blank⏎
      #line <- fullline | emptyline

      # lines holding only whitespace are parsed as ⏎
      line <- emptyline | fullline

      # documents are comprised of 1+ lines
      document <- +line * !1

  # FIXME: clean up this testing stuff
  let
    parsed = peggy.match(input & "\n")
  record.ok = parsed.ok
  if not parsed.ok:
    stdmsg().writeLine parsed.repr
  result = record
