# gully

You pass it code on input and it adds an area you can use to write comments
directly adjacent to your code.

If the code already has such comments, it will clean them up per your
instruction.

Of course, it knows how to format conventional line comments, as well.

## Usage

This tool is designed to be used from within an editor; eg. you're piping a code
block into it and replacing that input with this tool's output.

I used `par` for formatting text, but it has some deficiencies when it comes to
formatting comments, especially those adjacent to code. Also, it has no concept
of dividing the screen vertically.

### Input
```nim
when defined(debug):
  const logLevel = lvlDebug
elif defined(release):
  const logLevel = lvlNotice
else:
  const logLevel = lvlInfo
```

### Output

Add a gully.

```nim
when defined(debug):           # 
  const logLevel = lvlDebug    # 
elif defined(release):         # 
  const logLevel = lvlNotice   # 
else:                          # 
  const logLevel = lvlInfo     # 
```

### Input
```nim
when defined(debug):           # if you want debugging, we'll give you debugging!  otherwise,
  const logLevel = lvlDebug    # if this is a production build, we think you only want >= notices.
elif defined(release):         #   otherwise, you are probably
  const logLevel = lvlNotice   #  interested in
else:                          # the extra
  const logLevel = lvlInfo     # info.
```

### Output

Word-wrap the comments.

```nim
when defined(debug):           # if you want debugging, we'll give
  const logLevel = lvlDebug    # you debugging! otherwise, if this
elif defined(release):         # is a production build, we think you
  const logLevel = lvlNotice   # only want >= notices.  otherwise,
else:                          # you are probably interested in the
  const logLevel = lvlInfo     # extra info.
```

### Input
```nim
when defined(debug):           # if you want debugging, we'll give
  const logLevel = lvlDebug    # you debugging! otherwise, if this
elif defined(release) or defined(danger):           # is a production build, we think you
  const logLevel = lvlNotice   # only want >= notices.  otherwise,
else:                          # you are probably interested in the
  const logLevel = lvlInfo     # extra info.
```

### Output
Align the comments vertically.

```nim
when defined(debug):                        # if you want debugging, we'll give
  const logLevel = lvlDebug                 # you debugging! otherwise, if this
elif defined(release) or defined(danger):   # is a production build, we think you
  const logLevel = lvlNotice                # only want >= notices.  otherwise,
else:                                       # you are probably interested in the
  const logLevel = lvlInfo                  # extra info.
```

## Command-Line Options
$ gully --help                                                                                               22:17
Usage:
  gully [optional-params] 
a code comment formatter
Options(opt-arg sep :|=|spc):
  -h, --help                                    print this cligen-erated help
  --help-syntax                                 advanced: prepend,plurals,..
  -m=, --max-width=      int          80        the desired width of your source
  --min-width=           int          16        the minimum size of comment area to add
  -t=, --tab-size=       int          2         the width of your tabulators in spaces
  -p=, --padding=        int          2         margin of spaces between code and comments
  -s=, --syntax=         string       "#"       the syntax for your EOL comments
  --header=              string       "#["      token which begins multi-line comments
  -f=, --footer=         string       "]#"      token which ends multi-line comments
  -l=, --leader=         string       "  "      token which precedes multi-line comment lines
  -g=, --grow-lines=     Preposition  Above     directions in which to add needed new lines
  -i, --indent           bool         true      left-align comments to column of nearby code
  --flow-mo              bool         false     make no attempt to vertically align comments
  -r, --remove-comments  bool         false     strip all comments discovered in the input
  -w, --word-wrap        bool         true      enable breaking long lines on whitespace
  -c, --center-text      bool         false     surround comments with equal whitespace
  -a, --align-right      bool         false     align comments to the right margin of source
  --strip-whitespace     bool         true      strip leading and trailing whitespace
  -b=, --borders=        Preposition  Left      sides on which to add comment token borders
  --shrink-wrap          bool         true      merge adjacent comments when wrapping
  -j, --justify          bool         false     begin and end comments at column boundaries
  --thick                bool         false     grow comments by width before height
  --thin                 bool         false     grow comments by height before width
  --gravity=             ContentKind  Comments  cede extra space to `Code` or `Comments`
  --gully                bool         true      create comments that share lines with code
  -d, --dry-run          bool         false     copy input to stdout and result to stderr
  --log-level=           Level        lvlDebug  set the log level

## Library Use
There are some procedures exported for your benefit; see [the documentation for the module as generated directly from the source](https://disruptek.github.io/gully/gully.html).

## License
MIT
