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
      any <- +Alpha | +Print | +1 | 0
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
      #mlcComment <- begcML * >!endcML * endcML:
      #mlcComment <- begcML * >(*1 - endcML) * endcML:
      mlcComment <- begcML * >(any - endcML) * endcML:
        record.series.add (kind: MlCode, text: $1)

      # multi-line doc comments
      begdML <- lblb * mlo
      enddML <- mlc * lblb
      mldComment <- begdML * >(*1 - enddML) * enddML:
        record.series.add (kind: MlDocs, text: $1)

      # thus, any multi-line comment
      mlComment <- mldComment | mlcComment

      white <- +{'\t', ' '}
      nl <- ?'\r' * '\n'
      text <- 1 - nl
      newline <- >nl:
        record.series.add (kind: Newline, text: $1)

      # eol comments
      notcML <- lb - (begcML | begdML)
      isEolComment <- notcML * *text * nl
      eolComment <- notcML * >*text * &nl:
        record.series.add (kind: Comment, text: $1)

      # doc comments
      notdML <- lblb - (begcML | begdML)
      isDocComment <- notdML * *text * nl
      docComment <- notdML * >*text * &nl:
        record.series.add (kind: Docs, text: $1)

      # testing for comments; for fence reasons
      isComment <- &isDocComment | &isEolComment

      # capturing the comments
      capComment <- docComment | eolComment

      # significant blanks precede text
      blanks <- >white * &text:
        record.series.add (kind: Blank, text: $1)

      # significant text may be preceded by blanks
      significant <- ?blanks * +text - &isComment

      # code is a series of significant text
      code <- >+significant - &isComment:
        record.series.add (kind: Code, text: $1)

      # content is a multi-line comment or other significant text
      content <- mlComment | code

      # we might remove blank captures eventually
      commentline <- >white * capComment:
        record.series.add (kind: Blank, text: $1)

      # lines may end with a comment before they
      # even get going with significant text
      contentline <- *content * ?capComment

      # don't even capture lines with just whitespace
      line <- (white | commentline | contentline) * newline

      # documents are comprised of 1+ lines
      document <- +line * !1

  # FIXME: clean up this testing stuff
  let
    parsed = peggy.match(input & "\n")
  record.ok = parsed.ok
  if not parsed.ok:
    stdmsg().writeLine parsed.repr
  result = record
