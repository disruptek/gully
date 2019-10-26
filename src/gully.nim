import macros
import streams
import strutils
import strformat
import tables

import gully/cutelog

when isMainModule:

  # depending on whether this is the main module, we'll build some values for
  # use by cligen. but for flexibility, we don't actually want to check for
  # isMainModule -- we wanna check for cligen.
  #
  # this might go away at some point depending on how the tests work

  import cligen

const
  # recall that
  # Newlines = {'\c', '\n'} per strutils
  EndOfLine = Whitespace - {' ', '\t', '\v'}

type
  MutationKind = enum

    # constraints
    MaxWidth
    MinWidth
    Padding
    Syntax
    Flow
    Header
    Footer
    Leader
    Indent
    Grow
    TabSize

    # goals
    WordWrap
    Remove
    Center
    AlignR
    Strip
    Border
    Shrink
    Justify
    Thick
    Thin
    Gravity
    Gully

    # flags
    DryRun
    LogLevel

  Preposition = enum
    Left, Right
    Top, Bottom
    Both, Any,
    All, None,
    Above, Below
    Inside, Outside
    Near, Far

  ContentKind = enum Code, Comments, Whitespace

  HelpText = seq[tuple[switch: string; help: string]]

const
  IntegerMutants = {MaxWidth, MinWidth, Padding, TabSize}
  StringMutants = {Syntax, Header, Footer, Leader}
  BooleanMutants = {Flow, WordWrap, Remove, Center, AlignR, Strip, Shrink,
                    Justify, Thick, Thin, Indent, Gully, DryRun}
  PrepositionMutants = {Border, Grow}
  ContentMutants = {Gravity}
  LogLevelMutants = {LogLevel}

  Constraints = {MaxWidth .. TabSize}
  Goals = {WordWrap .. Gully}
  Flags {.used.} = {DryRun .. LogLevel}

when false:
  type
    ConstraintType = range[MaxWidth .. TabSize]
    GoalType = range[WordWrap .. Gully]
    FlagType = range[DryRun .. LogLevel]

type
  Mutation = ref object
    switch: ref string
    help: ref string
    case kind: MutationKind:
    of IntegerMutants:
      integer: int
    of StringMutants:
      text: string
    of BooleanMutants:
      boolean: bool
    of PrepositionMutants:
      prep: Preposition
    of ContentMutants:
      content: ContentKind
    of LogLevelMutants:
      level: Level

  Recipe = ref object
    #flags: set[FlagType]
    mutations: OrderedTableRef[MutationKind, Mutation]

type
  ## a top-level type representing either the input or the output
  Document = ref object
    recipe: Recipe             ## a collection of mutations to perform
    lines: LineGroup           ## adjacent lines that comprise the document

  ## it's sometimes useful to operate on a group of adjacent lines
  LineGroup = ref object
    group: seq[Line]
    maxLen: int

  ## a Document is comprised of Lines
  Line = ref object
    indent: int                ## the point at which whitespace ends
    input: string              ## the line before we applied any mutation
    work: string               ## the line after mutation; lacks terminator
    terminator: string         ## the string that signifies the EOL

proc `--`(mutation: Mutation): string =
  ## convenience to render the mutation as a command-line switch
  if mutation.switch == nil:
    result = toLowerAscii($mutation.kind)
  else:
    result = mutation.switch[]

iterator values(recipe: Recipe): Mutation =
  ## iterate over mutations in the given ``Recipe``
  for mutation in recipe.mutations.values:
    yield mutation

iterator items(lines: LineGroup): Line =
  ## iterate over lines in a ``LineGroup``
  for line in lines.group.items:
    yield line

iterator items(document: Document): Line =
  ## iterate over lines in a ``Document``
  for line in document.lines.items:
    yield line

proc `$`(line: Line): string =
  result = line.input

proc len(line: Line): int =
  result = line.work.len + line.terminator.len

proc len(lines: LineGroup): int =
  result = lines.group.len

proc len(document: Document): int =
  result = document.lines.len

proc `$`*(document: Document): string =
  var
    count: int
    size = document.len
  for line in document.items:
    # if the last line is empty, lacking even a terminator, omit it from output
    if count == size:
      if line.terminator.len == 0:
        break
    debug &"{count}: {line.work} + terminator of {line.terminator.len}"
    result &= $line
    count.inc

proc terminator(line: string): string =
  ## any combination of newline characters terminating the string
  for i in line.low .. line.high:
    if i < line.len:
      if line[^(i + 1)] in EndOfLine:
        result = line[^(i + 1)] & result

proc newLine(content: string): Line =
  ## create a new ``Line``
  var
    terminator = content.terminator
    work: string
  if terminator.len == 0:
    work = content
  else:
    work = content[0 .. ^(terminator.len + 1)]
  result = Line(input: content, work: work,
                terminator: terminator)

proc add(lines: LineGroup; line: Line) =
  ## add a ``Line`` to the ``LineGroup``
  lines.group.add line
  lines.maxLen = max(lines.maxLen, line.len)

proc add*(document: Document; line: Line) =
  ## add a ``Line`` to a ``Document``
  document.lines.add line

proc newLineGroup*(): LineGroup =
  ## create a new ``LineGroup``
  new result

proc newDocument*(): Document =
  ## make a new ``Document``
  new result
  result.lines = newLineGroup()

proc newDocument*(stream: Stream): Document =
  ## make a new ``Document``; populate it from an input ``Stream``
  result = newDocument()
  var
    input = stream.readAll
  for line in input.splitLines(keepEol = true):
    result.add newLine(line)

proc newMutation*(kind: MutationKind): Mutation =
  ## all mutations are instantiated here
  result = Mutation(kind: kind)

proc defaultNode(mutation: Mutation): NimNode {.compileTime.} =
  ## the value of the mutation as a ``NimNode``
  case mutation.kind:
  of IntegerMutants:
    result = newLit(mutation.integer)
  of StringMutants:
    result = newLit(mutation.text)
  of BooleanMutants:
    result = newLit(mutation.boolean)
  of PrepositionMutants:
    result = newLit(mutation.prep)
  of ContentMutants:
    result = newLit(mutation.content)
  of LogLevelMutants:
    result = newLit(mutation.level)

proc typeName(kind: MutationKind): string =
  ## the type name for the value of the mutation
  case kind:
  of IntegerMutants:
    result = "int"
  of StringMutants:
    result = "string"
  of BooleanMutants:
    result = "bool"
  of PrepositionMutants:
    result = "Preposition"
  of ContentMutants:
    result = "ContentKind"
  of LogLevelMutants:
    result = "Level"

proc typeName(mutation: Mutation): string =
  ## the type name for the value of the mutation
  result = typeName(mutation.kind)

proc typeDef(mutation: Mutation): NimNode {.compileTime.} =
  ## produce an ident node referring to the value type of the mutation
  result = newIdentNode(typeName(mutation))

proc newMutation(kind: MutationKind; value: int): Mutation =
  ## create an ``int`` mutation
  result = newMutation(kind)
  result.integer = value

proc newMutation(kind: MutationKind; value: string): Mutation =
  ## create a ``string`` mutation
  result = newMutation(kind)
  result.text = value

proc newMutation(kind: MutationKind; value: bool): Mutation =
  ## create a ``bool`` mutation
  result = newMutation(kind)
  result.boolean = value

proc newMutation(kind: MutationKind; value: Preposition): Mutation =
  ## create a ``Preposition`` mutation
  result = newMutation(kind)
  result.prep = value

proc newMutation(kind: MutationKind; value: ContentKind): Mutation =
  ## create a ``ContentKind`` mutation
  result = newMutation(kind)
  result.content = value

proc newMutation(kind: MutationKind; value: Level): Mutation =
  ## create a log ``Level`` mutation
  result = newMutation(kind)
  result.level = value

proc `[]`*(recipe: Recipe; kind: MutationKind): Mutation =
  ## convenience syntax for fetching the given mutation
  result = recipe.mutations[kind]

proc `[]=`*(recipe: Recipe; kind: MutationKind; mutation: Mutation) =
  ## a singular entry for mutations into the recipe
  assert kind notin recipe.mutations
  recipe.mutations[kind] = mutation

proc add*[T](recipe: Recipe; kind: MutationKind; value: T) {.used.} =
  ## used at runtime to instantiate new mutations in the cligen'd proc
  recipe.mutations[kind] = newMutation(kind, value)

proc add*[T](recipe: Recipe; kind: MutationKind; value: T; switch: string; help = "") =
  ## instantiate a new mutation with the given switch and add it to the recipe
  var
    mutation = newMutation(kind, value)
  new mutation.switch
  new mutation.help
  mutation.switch[] = switch
  if help != "":
    mutation.help[] = help
  recipe[kind] = mutation

proc contains*(recipe: Recipe; kind: MutationKind): bool =
  ## is a mutation of the provided kind in the given ``Recipe``
  result = recipe.mutations.contains kind

proc newRecipe*(): Recipe =
  ## create a new ``Recipe`` and prepare it for ``Mutation``
  new result
  result.mutations = newOrderedTable[MutationKind, Mutation]()

proc switchIdent*(switch: string): NimNode =
  ## turn a string into its suitable ident"long_option"
  result = newIdentNode(switch.replace("-", "_"))

proc switchIdent*(mutation: Mutation): NimNode =
  ## turn a mutation into its suitable ident"long_option"
  result = switchIdent(--mutation)

proc toIdentDefs*(mutation: Mutation): NimNode =
  ## turn a mutation into a param typedef for a cligen input proc
  result = newIdentDefs(mutation.switchIdent, mutation.typeDef,
                        mutation.defaultNode)

when defined(debug):
  const logLevel = lvlDebug
elif defined(release) or defined(danger):
  const logLevel = lvlNotice
else:
  const logLevel = lvlInfo

proc createDefaultRecipe*(): Recipe {.compileTime.} =
  ## enumerate the default recipe, setting defaults and help text
  result = newRecipe()

  # start with hard constraints
  result.add MaxWidth, 80, "max-width",
    "the desired width of your source"
  result.add MinWidth, 16, "min-width",
    "the minimum size of comment area to add"
  result.add TabSize, 2, "tab-size",
    "the width of your tabulators in spaces"
  result.add Padding, 2, "padding",
    "margin of spaces between code and comments"
  result.add Syntax, "#", "syntax",
    "the syntax for your EOL comments"
  result.add Header, "#[", "header",
    "token which begins multi-line comments"
  result.add Footer, "]#", "footer",
    "token which ends multi-line comments"
  result.add Leader, "  ", "leader",
    "token which precedes multi-line comment lines"
  result.add Grow, Above, "grow-lines",
    "directions in which to add needed new lines"
  result.add Indent, on, "indent",
    "left-align comments to column of nearby code"
  result.add Flow, off, "flow-mo",
    "make no attempt to vertically align comments"

  for kind in Constraints:
    if kind notin result:
      error &"{kind} defined too late"
  for mutation in result.values:
    if mutation.kind notin Constraints:
      error &"{mutation.kind} defined too early"

  # next, enumerate soft goals
  result.add Remove, off, "remove-comments",
    "strip all comments discovered in the input"
  result.add WordWrap, on, "word-wrap",
    "enable breaking long lines on whitespace"
  result.add Center, off, "center-text",
    "surround comments with equal whitespace"
  result.add AlignR, off, "align-right",
    "align comments to the right margin of source"
  result.add Strip, on, "strip-whitespace",
    "strip leading and trailing whitespace"
  result.add Border, Left, "borders",
    "sides on which to add comment token borders"
  result.add Shrink, on, "shrink-wrap",
    "merge adjacent comments when wrapping"
  result.add Justify, off, "justify",
    "begin and end comments at column boundaries"
  result.add Thick, off, "thick",
    "grow comments by width before height"
  result.add Thin, off, "thin",
    "grow comments by height before width"
  result.add Gravity, Comments, "gravity",
    "cede extra space to `Code` or `Comments`"
  result.add Gully, on, "gully",
    "create comments that share lines with code"

  # make sure we've defined goals in the right place
  for kind in Goals:
    if kind notin result:
      error &"{kind} defined too late"
  for mutation in result.values:
    if mutation.kind notin Constraints:
      if mutation.kind notin Goals:
        error &"{mutation.kind} defined too early"

  # flags can go last
  result.add DryRun, off, "dry-run",
    "copy input to stdout and result to stderr"
  result.add LogLevel, logLevel, "log-level",
    "set the log level"

  for kind in MutationKind.low .. MutationKind.high:
    if kind notin result:
      error &"failed to define {kind}"
    when defined(debug):
      let mutation = result[kind]
      hint &"{kind} --{--mutation}: {mutation.typeName} " &
                                &"= {mutation.defaultNode.repr}"

proc makeCliEntryProcedure*(recipe: Recipe; nameIt: string): NimNode {.compileTime.} =
  ## create a new entry procedure for ``cligen`` using the given ``Recipe``
  let
    name = newIdentNode(nameIt).postfix("*")
  var
    body = newStmtList()
    params: seq[NimNode]

  # put something useful in the doc comments
  body.add newCommentStmtNode("generated by a macro for use by cligen")

  # the procedure will return an int
  params.add ident"int"

  # if the user wants to enable logging, let's set the level early
  if LogLevel in recipe:
    body.add newCall(ident"setLogFilter", recipe[LogLevel].switchIdent)

  # var recipe = newRecipe()
  body.add newVarStmt(ident"recipe", newCall(ident"newRecipe"))

  for mutation in recipe.values:
    params.add mutation.toIdentDefs
    let
      # recipe.add
      recipeadd = newDotExpr(ident"recipe", ident"add")
      # result.add(MaxWidth, max_width, "max-width")
      addcall = recipeadd.newCall(newLit(mutation.kind),
                                  mutation.switchIdent,
                                  newLit(--mutation))
    # add result.add(...) to the body
    body.add addcall

  # proc cliRecipe(...): int = ...
  result = newProc(name = name, params = params, body = body)

proc helpText*(recipe: Recipe): HelpText =
  ## generate help text from a recipe; see also ``keyValueToHelp``
  for mutation in recipe.values:
    result.add (switch: --mutation, help: mutation.help[])

macro keyValueToHelp*(help: static[HelpText]): untyped =
  ## turn a sequence of ``(switch: string, help: string)``
  ## into ``{"switch-name": "help", ...}``;
  ## this is the required input for cligen's ``dispatchGen``
  result = newNimNode(nnkTableConstr)
  for each in help.items:
    result.add newColonExpr(newLit(each.switch), newLit(each.help))

when declaredInScope(createDefaultRecipe):
  # make a default recipe that we can use with cligen
  let
    defaultRecipe {.compileTime.} = createDefaultRecipe()

when declaredInScope(defaultRecipe):
  # use defaultRecipe to compose a proc for cligen to consume
  macro cliEntryProcedureBody*(name: static[string]; body: untyped): untyped =
    ## create a cli entry with the given body
    result = makeCliEntryProcedure(defaultRecipe, name)
    result.body.add body

when declaredInScope(cligen):
  proc tweakFromArgumentOrder*(recipe: var Recipe; parsed: seq[ClParse]) =
    # now we have our recipe and the parsed stuff;
    # sort the argument order...
    discard

proc includesFailure*(parsed: seq[ClParse]): bool =
  ## true if the list of parsed options includes a failure
  for parse in parsed:
    if parse.status != clOk:
      return true

proc `$`*(parse: ClParse): string =
  ## render a parse result
  when true:
    result = parse.message
  else:
    case parse.status:
    of clHelpOnly, clVersionOnly:
      result = parse.message
    else:
      result = &"{parse.paramName}: {parse.message}"

proc outputErrors*(parsed: seq[ClParse]) =
  ## report command-line parse errors to the user
  for parse in parsed:
    if parse.status in {clOk}:
      continue
    error $parse

when isMainModule:
  let
    console = newConsoleLogger(levelThreshold = logLevel,
                               useStderr = true, fmtStr = "")
    logger = newCuteLogger(console)
  addHandler(logger)

  var
    # make a seq into which we'll store the parsed options in order;
    # set its initial size according to the number of options
    parsed: seq[ClParse] = newSeqOfCap[ClParse](ord(MutationKind.high))

  cliEntryProcedureBody("cliRecipe"):
    # mutate the recipe according to the order of arguments on the cli
    recipe.tweakFromArgumentOrder(parsed)

    let
      # load the input into a new document
      original = newDocument(stdin.newFileStream)
    var
      # we'll start with simply outputing the original input
      output = original

    # make sure that we are always prepared to return a valid
    # document to stdout in the event of a failure somewhere
    defer:
      stdout.write($output)

    if DryRun in recipe and recipe[DryRun].boolean:
      debug "dry run; dump to stderr"
      # write whatever we have generated to stderr
      stderr.write($output)
      # reset output to input
      output = original

  # generate defaultCommandLine and give it some options to set things up
  when declaredInScope(cliRecipe):
    var
      help {.compileTime.} = defaultRecipe.helpText

    dispatchGen(cliRecipe, cmdName = "gully", setByParse = addr parsed,
                doc = "a code comment formatter", help = keyValueToHelp(help),
                dispatchName = "defaultCommandLine")

    when declaredInScope(defaultCommandLine):
      let result = defaultCommandLine()
      if parsed.includesFailure:
        parsed.outputErrors()

      quit result
