import strutils
import streams

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
    cheader*: string
    cfooter*: string
    cleader*: string
    dheader*: string
    dfooter*: string
    dleader*: string

  Token* {.pure.} = enum
    Blank
    Code
    Comment
    Docs
    MlCode
    MlDocs
    Newline = "⏎"

  TokenText* = object
    kind*: Token
    text*: string
    lhs*: int
    rhs*: int

  LineLengths* = object
    blanks*: int
    code*: int
    text*: int

proc `$`*(tokens: seq[Token]): string =
  for t in tokens:
    if result.len != 0:
      if t != Newline:
        result &= ","
    result &= $t

proc len*(tt: TokenText): int =
  ## return the length of the token text including any delimiter syntax
  result = tt.text.len + tt.lhs + tt.rhs

proc lengths*(token: TokenText): LineLengths =
  ## tally the lengths of single token/text
  case token.kind:
  of Blank:
    result.blanks = token.len
  of Code:
    result.code = token.len
  of Docs, Comment, MlDocs, MlCode:
    result.text = token.len
  of Newline:
    discard

proc lengths*(series: seq[TokenText]): LineLengths =
  ## tally the lengths of a series of token/text
  for tt in series.items:
    let
      lens = tt.lengths
    result.blanks.inc lens.blanks
    result.code.inc lens.code
    result.text.inc lens.text

proc render*(series: seq[TokenText]; syntax: Syntax): string =
  ## render a series of token/text in the given syntax
  assert syntax != nil, "cannot render with syntax"
  for tt in series.items:
    case tt.kind:
    of Comment:
      result &= syntax.eolc & tt.text
    of Docs:
      result &= syntax.docs & tt.text
    of MlCode:
      result &= syntax.cheader & tt.text & syntax.cfooter
    of MlDocs:
      result &= syntax.dheader & tt.text & syntax.dfooter
    else:
      result &= tt.text

proc render*(document: ParsedDocument; syntax: Syntax): string =
  ## render a parsed document in the given syntax
  result = document.series.render(syntax)

proc asTokenList*(parsed: ParsedDocument): seq[Token] =
  for tt in parsed.series:
    result.add tt.kind

proc render*(parsed: ParsedDocument): string =
  ## render a parsed document for testing
  for tt in parsed.series:
    if result.len > 0:
      result &= ", "
    if tt.text == "\n":
      result.add $Newline
    else:
      result.add "`" & tt.text & "`"

proc parseDocument*(input: string; syntax: Syntax): ParsedDocument =
  ## parse a document from a string
  assert syntax != nil, "nil syntax is not supported"

  # we need well-formed input in order to parse the document
  if input.len == 0 or input[^1] != '\n':
    raise newException(ValueError, "parseable documents terminate with a newline")

  # accumulate a record of tokens and their values in this result
  var
    record = ParsedDocument(ok: false, syntax: syntax)

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
      mlcComment <- >begcML * >*(1 - endcML) * >endcML:
        record.series.add TokenText(kind: MlCode,
                                    text: $2, lhs: len($1), rhs: len($3))

      # multi-line doc comments
      begdML <- lblb * mlo
      enddML <- mlc * lblb
      mldComment <- >begdML * >*(1 - enddML) * >enddML:
        record.series.add TokenText(kind: MlDocs,
                                    text: $2, lhs: len($1), rhs: len($3))

      # thus, any multi-line comment
      multiline <- mldComment | mlcComment

      white <- {'\t', ' '}
      nl <- ?'\r' * '\n'
      text <- 1 - nl

      # we don't notate newlines inside multi-line comments
      newline <- >nl:
        record.series.add TokenText(kind: Newline, text: $1)

      # code comments like this one
      codComment <- >lb * >*text:
        record.series.add TokenText(kind: Comment, text: $2, lhs: len($1))

      # doc comments
      docComment <- >lblb * >*text:
        record.series.add TokenText(kind: Docs, text: $2, lhs: len($1))

      # capturing the comments
      comment <- docComment | codComment

      # significant blanks precede non-blank text
      blanks <- >+white - !white - nl:
        record.series.add TokenText(kind: Blank, text: $1)

      # code can terminate at an lb
      code <- >+(text - lb):
        record.series.add TokenText(kind: Code, text: $1)

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

  let
    parsed = peggy.match(input)
  record.ok = parsed.ok
  result = record

proc parseDocument*(stream: Stream; syntax: Syntax): ParsedDocument =
  ## parse a stream into tokens
  let
    input = stream.readAll
  result = input.parseDocument(syntax)

iterator items*(parsed: ParsedDocument): seq[TokenText] =
  ## iterate over lines (of tokens) in a parsed document
  var
    index = 0
    line: seq[TokenText]

  while index < parsed.series.len:
    line.add parsed.series[index]
    if parsed.series[index].kind == Newline:
      yield line
      line = @[]
    index.inc
  assert parsed.series[^1].kind == Newline
