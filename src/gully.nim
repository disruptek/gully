import macros
import streams
import strutils except Whitespace
import strformat
import tables
import random
from sugar import `=>`, `->`

import cutelog
import bump
import gully/parser

const
  logLevel =
    when defined(debug):
      lvlDebug
    elif defined(release):
      lvlNotice
    elif defined(danger):
      lvlNotice
    else:
      lvlInfo

when isMainModule:

  # depending on whether this is the main module, we'll build some values for
  # use by cligen. but for flexibility, we don't actually want to check for
  # isMainModule -- we wanna check for cligen.
  #
  # this might go away at some point depending on how the tests work

  import cligen

type
  DuplicateOption* = object of ValueError

  MutationKind* = enum

    # constraints
    MaxWidth
    MinWidth
    Padding
    Language
    Flow
    Header
    Footer
    Leader
#    Alternate
    Indent
    Grow
    TabSize

    # goals
    WordWrap
#    Cycle
#    Fence
    Remove
    Center
    AlignR
    Strip
    Border
    Shrink
    Justify
    Thick
    Thin
    Hoist
#   Tiny
#   Huge
    Gravity
    Gully

    # flags
    DryRun
    Jiggle
#    Statistics
#    Verbose
    LogLevel

  ConstraintType = range[MaxWidth .. TabSize]
  GoalType = range[WordWrap .. Gully]
  FlagType = range[DryRun .. LogLevel]

  Preposition* = enum
    Left, Right
    Top, Bottom
    Both, Any,
    All, None,
    Above, Below
    Inside, Outside
    Near, Far

  Content* = enum Code, Comments, Whitespace

  MultiLinedness = enum mlNone, mlHeader, mlFooter, mlLeader

  HelpText = seq[tuple[switch: string; help: string]]

  Lang* = enum
    Nim = "nim"
    C = "c"
    Cpp = "c++"
    Go = "go"
    Python = "python"
    Js = "js"
    CSharp = "c#"

const
  IntegerMutants = {MaxWidth, MinWidth, Padding, TabSize}
  StringMutants = {Header, Footer, Leader}
  LanguageMutants = {Language}
  BooleanMutants = {Flow, WordWrap, Remove, Center, AlignR, Strip, Shrink,
                    Justify, Thick, Thin, Indent, Hoist, Gully, DryRun,
                    Jiggle}
  PrepositionMutants = {Border, Grow}
  ContentMutants = {Gravity}
  LogLevelMutants = {LogLevel}

  Constraints = {MaxWidth .. TabSize}
  Goals = {WordWrap .. Gully}
  Flags = {DryRun .. LogLevel}

type
  Mutation* = ref object
    recipe*: Recipe
    source*: SourceKind
    switch*: ref string
    help*: ref string
    case kind*: MutationKind:
    of IntegerMutants:
      integer*: int
    of StringMutants:
      text*: string
    of BooleanMutants:
      boolean*: bool
    of PrepositionMutants:
      prep*: Preposition
    of ContentMutants:
      content*: Content
    of LogLevelMutants:
      level*: Level
    of LanguageMutants:
      lang*: Lang

  Recipe* = ref object
    mutations: OrderedTableRef[MutationKind, Mutation]
    arguments: TableRef[string, MutationKind]
    constraints: seq[ConstraintType]   ## requested constraints, in order
    goals: seq[GoalType]               ## requested goals, in order
    flags: set[FlagType]               ## requested flags

  ## a top-level type representing either the input or the output
  Document* = ref object
    recipe: Recipe             ## a collection of mutations to perform
    groups: seq[LineGroup]     ## consecutive groups of adjacent lines
    syntax: Syntax

  ## it's sometimes useful to operate on a group of adjacent lines
  LineGroup = ref object
    document: Document
    group: seq[Line]
    maxLen: int

  ## a LineGroup is comprised of Lines
  Line = ref object
    document: Document
    indent: int                ## the point at which whitespace ends
    input: string              ## the line before we applied any mutation
    work: string               ## the line after mutation; lacks terminator
    terminator: string         ## the string that signifies the EOL
    multi: set[MultiLinedness] ## the varieties of multi-linedness here
    tokens: seq[TokenText]     ## the parsed contents of the line

  Score* = range[0.0 .. 1.0]
  ScoreCard* = OrderedTableRef[MutationKind, Score]

  Improvement* = ref object
    original*: Document
    improved*: Document
    recipe*: Recipe
    score*: Score

  SourceKind* = enum UserProvided, Backfilled

proc `--`*(mutation: Mutation): string =
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

iterator items*(document: Document): Line =
  ## iterate over lines in a ``Document``
  for group in document.groups.items:
    for line in group:
      yield line

proc len*(line: Line): int =
  for tt in line.tokens:
    result.inc tt.text.len + tt.lhs + tt.rhs

proc len*(lines: LineGroup): int =
  result = lines.group.len

proc len*(document: Document): int =
  for group in document.groups.items:
    result.inc group.len

proc `$`*(document: Document): string =
  var
    count: int
    size = document.len
  for line in document.items:
    # if the last line is empty, lacking even a terminator, omit it from output
    if count == size:
      if line.terminator.len == 0:
        break
    when defined(debug):
      debug &"{count}: " &
        line.tokens.render(document.syntax).strip(leading = false)
    result &= line.tokens.render(document.syntax)
    count.inc

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
    result = "Content"
  of LogLevelMutants:
    result = "Level"
  of LanguageMutants:
    result = "Lang"

proc typeName(mutation: Mutation): string =
  ## the type name for the value of the mutation
  result = typeName(mutation.kind)

proc typeDef(mutation: Mutation): NimNode {.compileTime.} =
  ## produce an ident node referring to the value type of the mutation
  result = newIdentNode(typeName(mutation))

proc newMutation*(kind: MutationKind; source = Backfilled): Mutation =
  ## all mutations are instantiated here
  result = Mutation(kind: kind, source: source)

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

proc newMutation(kind: MutationKind; value: Content): Mutation =
  ## create a ``Content`` mutation
  result = newMutation(kind)
  result.content = value

proc newMutation(kind: MutationKind; value: Level): Mutation =
  ## create a log ``Level`` mutation
  result = newMutation(kind)
  result.level = value

proc newMutation(kind: MutationKind; value: Lang): Mutation =
  ## create a ``Language`` mutation
  result = newMutation(kind)
  result.lang = value

proc `[]`*(recipe: Recipe; kind: MutationKind): Mutation =
  ## convenience language for fetching the given mutation
  result = recipe.mutations[kind]

proc `[]=`*(recipe: Recipe; kind: MutationKind; mutation: Mutation) =
  ## a singular entry for mutations into the recipe
  assert kind notin recipe.mutations

  # a link to the recipe is needed so that, for example, we can
  # check the tab size when measuring whitespace from elsewhere
  mutation.recipe = recipe

  recipe.mutations[kind] = mutation
  recipe.arguments[--mutation] = kind

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
  result.arguments = newTable[string, MutationKind]()

proc newLine(document: Document; input: seq[TokenText]): Line =
  ## create a new ``Line`` from a series of tokens
  result = Line(tokens: input, document: document,
                terminator: input[^1].text)

proc shrinkable(line: Line): int =
  ## the number of characters by which we can reduce line length
  let
    length = line.len
  if length != 0:
    result = lengths(line.tokens).text

proc add(lines: LineGroup; line: Line) =
  ## add a ``Line`` to the ``LineGroup``
  lines.group.add line
  lines.maxLen = max(lines.maxLen, line.len)

proc newLineGroup*(document: Document): LineGroup =
  ## create a new ``LineGroup``
  result = LineGroup(document: document)

proc add*(document: Document; line: Line) =
  ## add a ``Line`` to a ``Document``
  if document.groups.len == 0:
    document.groups.add document.newLineGroup()
  document.groups[^1].add line

proc chooseSyntax*(recipe: Recipe): Syntax =
  ## instantiate an appropriate syntax from the Recipe
  assert TabSize in recipe
  let
    tabs = block:
      if TabSize in recipe:
        recipe[TabSize].integer
      else:
        13  # have fun with this lucky number
  result = Syntax(docs: "##", eolc: "#", tabsize: tabs,
                  cheader: "#[", cfooter: "]#", cleader: "# ",
                  dheader: "##[", dfooter: "]##", dleader: "## ")

proc newDocument(): Document =
  ## make a new ``Document``
  new result

proc newDocument*(recipe: Recipe; input: string): Document =
  ## create a Document using a Recipe for syntax and an input string
  result = newDocument()
  result.syntax = recipe.chooseSyntax()

  if input == "":
    return

  let
    parsed = input.parseDocument(result.syntax)
  if parsed.ok == false:
    raise newException(ValueError, "unable to parse input")
  for line in parsed.items:
    result.add result.newLine(line)

proc newDocument*(recipe: Recipe; stream: Stream): Document =
  ## create a Document using a Recipe for syntax and a Stream for input
  result = recipe.newDocument(stream.readAll)

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
  of LanguageMutants:
    result = newLit(mutation.lang)

proc `$`*(mutation: Mutation): string =
  result = $mutation.kind
  case mutation.kind:
  of IntegerMutants:
    result &= &"={mutation.integer}"
  of StringMutants:
    result &= &"`{mutation.text}`"
  of BooleanMutants:
    result &= &"={mutation.boolean}"
  of PrepositionMutants:
    result &= &".{mutation.prep}"
  of ContentMutants:
    result &= &".{mutation.content}"
  of LogLevelMutants:
    result &= &".{mutation.level}"
  of LanguageMutants:
    result &= &".{mutation.lang}"

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

proc createDefaultRecipe*(): Recipe =
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
  result.add Header, "#[", "header",
    "token which begins multi-line comments"
  result.add Footer, "]#", "footer",
    "token which ends multi-line comments"
  result.add Leader, "  ", "leader",
    "token which precedes multi-line comment lines"
  result.add Language, Nim, "language",
    "the syntax to use for your comments"
  result.add Grow, Above, "grow",
    "directions in which to add needed new lines"
  result.add Indent, on, "indent",
    "left-align comments to column of nearby code"
  result.add Flow, off, "flow-mo",
    "make no attempt to vertically align comments"

  when defined(debug):
    # make sure we've defined constraints in the right place
    for kind in Constraints:
      assert kind in result,
        &"{kind} defined too late"
    for mutation in result.values:
      assert mutation.kind in Constraints,
        &"{mutation.kind} defined too early"

  # next, enumerate soft goals
  result.add Remove, off, "remove",
    "strip all comments discovered in the input"
  result.add WordWrap, on, "word-wrap",
    "enable breaking long lines on whitespace"
  result.add Center, off, "center-text",
    "surround comments with equal whitespace"
  result.add AlignR, off, "align-right",
    "align comments to the right margin of source"
  result.add Strip, on, "strip",
    "strip leading and trailing whitespace"
  result.add Border, Left, "borders",
    "sides on which to add comment token borders"
  result.add Shrink, on, "shrink-wrap",
    "merge adjacent comments when wrapping"
  result.add Justify, off, "justify",
    "begin and end comments at column boundaries"
  result.add Hoist, on, "hoist",
    "move multiline comments to their own lines"
  result.add Thick, off, "thick",
    "grow comments by width before height"
  result.add Thin, off, "thin",
    "grow comments by height before width"
  result.add Gravity, Comments, "gravity",
    "cede extra space to `Code` or `Comments`"
  result.add Gully, on, "gully",
    "create comments that share lines with code"

  when defined(debug):
    # make sure we've defined goals in the right place
    for kind in Goals:
      assert kind in result,
        &"{kind} defined too late"
    for mutation in result.values:
      if mutation.kind notin Constraints:
        assert mutation.kind in Goals,
          &"{mutation.kind} defined too early"

  # flags can go last
  result.add DryRun, off, "dry-run",
    "copy input to stdout and result to stderr"
  result.add Jiggle, off, "jiggle",
    "subtly tweak by randomizing option order"
  result.add LogLevel, logLevel, "log-level",
    "set the log level"

  when defined(debug):
    # now make sure we're not forgetting something
    for kind in MutationKind.low .. MutationKind.high:
      assert kind in result,
        &"failed to define {kind}"
      when false:
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
  body.add newCommentStmtNode("(generated by a macro for use by cligen)")

  # the procedure will return an int
  params.add ident"int"

  # if the user wants to enable logging, let's set the level early
  if LogLevel in recipe:
    body.add newCall(ident"setLogFilter", recipe[LogLevel].switchIdent)

  # var recipe = newRecipe()
  body.add newVarStmt(ident"recipe", newCall(ident"newRecipe"))

  # add each cli option to the proc parameters
  for mutation in recipe.values:
    params.add mutation.toIdentDefs
    let
      # recipe.add
      recipeadd = newDotExpr(ident"recipe", ident"add")
      # result.add(MaxWidth, max_width, "max-width")
      addcall = recipeadd.newCall(newLit(mutation.kind),
                                  mutation.switchIdent,
                                  newLit(--mutation))
    # add result.add(...) to the body; this is where
    # we add the mutation and its value to the recipe
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

proc orderedMutation(recipe: Recipe; kind: MutationKind): bool =
  ## true if the recipe calls for a given mutation
  case kind:
  of Constraints:
    result = kind in recipe.constraints
  of Goals:
    result = kind in recipe.goals
  of Flags:
    result = kind in recipe.flags

proc orderMutation(recipe: var Recipe; kind: MutationKind; source: SourceKind) =
  ## add the given mutation to the recipe, preserving order
  assert kind in recipe, "inconceivable!"
  case kind:
  of Constraints:
    recipe.constraints.add kind
  of Goals:
    recipe.goals.add kind
  of Flags:
    recipe.flags.incl kind
  recipe[kind].source = source
  if source == UserProvided:
    debug &"user added {recipe[kind]}"

proc orderUnspecifiedOptions(recipe: var Recipe) =
  ## order any options that the user didn't specify;

  # we use the order defined in the recipe to ensure
  # that whatever wisdom it holds is reproduced here
  for mutation in recipe.values:
    # obviously, we'll skip unspecified flags,
    if mutation.kind in Flags:
      continue
    # but otherwise, as long as it's unique
    if not recipe.orderedMutation(mutation.kind):
      # everything else is added
      recipe.orderMutation(mutation.kind, Backfilled)

  # if the user wants to jiggle, let's dance
  if Jiggle in recipe:
    if recipe[Jiggle].boolean:
      randomize()
      recipe.goals.shuffle

when declaredInScope(cligen):
  proc considerArgumentOrder*(recipe: var Recipe; parsed: seq[ClParse]) =
    ## lookup the arguments and register them, in order, in the recipe
    for parse in parsed:
      let
        kind = recipe.arguments[parse.paramName.replace("_", "-")]
      if recipe.orderedMutation(kind):
        # we really only know how to handle one
        # instance of each mutation -- if that!
        raise newException(DuplicateOption,
                           &"duplicate option {kind} specified")
      recipe.orderMutation(kind, UserProvided)

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
      case parse.status:
      of clOk:
        discard
      of clHelpOnly, clVersionOnly:
        log(lvlFatal, $parse)
      else:
        log(lvlError, $parse)

when false:
  proc orderLength(recipe: Recipe): int =
    ## the number of affective mutations in the recipe
    result = recipe.constraints.len + recipe.goals.len

iterator order(recipe: Recipe): Mutation =
  ## yield mutations in appropriate order based upon input, role
  for kind in recipe.constraints:
    yield recipe[kind]
  for kind in recipe.goals:
    yield recipe[kind]

proc canShrinkWithin(group: LineGroup; size: int): bool =
  ## true if the group can shrink in width to <= given size
  for line in group.items:
    let l = line.len
    if l > size:
      if l - line.shrinkable > size:
        return false

proc scoreByLine[T: Document | LineGroup](many: T; mutation: Mutation;
  predicate: (Mutation, Line) -> Score): Score =
  ## all lines have the same weight (for now)
  var
    score: float
    count: int
  for line in many.items:
    count.inc
    score += predicate(mutation, line)
  if count == 0:
    result = 1.0
  result = score / count.float

proc scoreByGroup(document: Document; mutation: Mutation;
                  predicate: (Mutation, LineGroup) -> Score): Score =
  ## all groups have the same weight (for now)
  var
    score: float
    count: int
  for group in document.groups.items:
    count.inc
    score += predicate(mutation, group)
  if count == 0:
    result = 1.0
  result = score / count.float

proc measureTrailingWhitespace(text: string; tabSize: int): int =
  ## does what it says on the tin!
  for i in countDown(text.high, text.low):
    if text[i] == '\t':
      result.inc tabSize
    elif text[i] in strutils.Whitespace:
      result.inc
    else:
      break

proc scorePadding(mutation: Mutation; line: Line): Score =
  assert TabSize in mutation.recipe
  result = 1.0
  for index, value in line.tokens.pairs:
    block:
      # find any comments
      if value.kind in {MlCode, MlDocs, Comment, Docs}:
        # that aren't at the beginning of the line
        if index > 0:
          # and precede code
          if line.tokens[index - 1].kind == Token.Code:
            break
      continue

    let
      ts = mutation.recipe[TabSize].integer
      tw = measureTrailingWhitespace(line.tokens[index - 1].text,
                                     tabSize = ts)
    if tw < mutation.integer:
      result = tw.float / mutation.integer.float
    return

proc scoreMaxWidth(mutation: Mutation; line: Line): Score =
  let
    l = line.len
  result = 1.0
  if l > mutation.integer:
    result -= min(1.0, (l - mutation.integer).float / mutation.integer.float)
  debug &"score for {mutation} is {result} and l is {l}"

proc score(mutation: Mutation; document: Document): Score =
  var
    score: float
  case mutation.kind:
  of MaxWidth:
    # the lines should be no longer than X characters
    result = document.scoreByLine(mutation, scoreMaxWidth)
  of Padding:
    # any eol comments should be separated from code by X characters
    result = document.scoreByLine(mutation, scorePadding)
  of Language, Header, Footer, Leader, TabSize:
    result = 1.0
  else:
    # FIXME: this should eventually be a defect
    when false:
      raise newException(Defect, &"{mutation.kind} scoring unimplemented")
      warn &"{mutation.kind} scoring unimplemented"
    result = 1.0
    return
  debug &"score for {mutation} is {score}"

proc tally*(card: ScoreCard): Score =
  ## tally a scorecard
  var
    score = 1.0 # nothin' from nothin' leaves nothin'
  for s in card.values:
    score = score * 2.0 + s
    if score > 0.0:
      score = score / 3.0
  result = score

proc score*(recipe: Recipe; document: Document): ScoreCard =
  ## calculate a score for the document
  const tableSize = 32
  assert ord(MutationKind.high) <= tableSize
  result = newOrderedTable[MutationKind, Score](tableSize)
  # each successfive metric is worth half as much to the final result
  for mutation in recipe.order:
    result[mutation.kind] = mutation.score(document)

proc newImprovement(recipe: Recipe;
                    original: Document; improved: Document): Improvement =
  result = Improvement(recipe: recipe, original: original, improved: improved)

iterator improvements(recipe: Recipe; original: Document): Improvement =
  ## produce improved versions of the original document for consideration
  var
    head = original
    next = original
  var
    improvement = recipe.newImprovement(head, next)
  improvement.score = recipe.score(next).tally
  yield improvement

when isMainModule:
  let
    console = newConsoleLogger(levelThreshold = logLevel,
                               useStderr = true, fmtStr = "")
    logger = newCuteLogger(console)
  addHandler(logger)

  let
    version = projectVersion("gully")
  if version.isSome:
    clCfg.version = $version.get
  else:
    clCfg.version = "(unknown version)"

  var
    # make a seq into which we'll store the parsed options in order;
    # set its initial size according to the number of options
    parsed: seq[ClParse] = newSeqOfCap[ClParse](ord(MutationKind.high))

  cliEntryProcedureBody("cliRecipe"):
    # mutate the recipe according to the order of arguments on the cli
    try:
      recipe.considerArgumentOrder(parsed)
    except DuplicateOption as e:
      log(lvlError, e.msg)
      return 1

    # add in the other available options as per their defaults
    recipe.orderUnspecifiedOptions()

    let
      # load the input into a new document
      original = recipe.newDocument(stdin.newFileStream)
    var
      # we'll start with simply outputing the original input
      output = original

    # make sure that we are always prepared to return a valid
    # document to stdout in the event of a failure somewhere
    defer:
      stdout.write($output)

    for applied in recipe.improvements(output):
      debug "improvement scores", $applied.score
      output = applied.improved

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
      try:
        let result = defaultCommandLine()
        when false:
          # this shouldn't be necessary with newest cligen
          if parsed.includesFailure:
            parsed.outputErrors()
        quit result
      except ParseError:
        discard
      except HelpOnly:
        discard
      quit 1
