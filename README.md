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
elif defined(release) or defined(danger):
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

- `--max-width` specify the desired width of your source; defaults to `80`
- `--min-width` do nothing if you cannot achieve a gully of at least this width; defaults to `16`
- `--syntax` specify the syntax for your EOL comments; defaults to `#`
- `--wrap` toggle word-wrapping; defaults to `on`
- `--remove` finds your comment block and erases it; use with care!
- `--center` center the comment text in its block; defaults to `off`
- `--right-align` aligns the comments to the `--max-right` column
- `--strip` toggle whitespace-stripping; defaults to `on`
- `--borders` an integer representing border count: `1`, `2`, or `4`; defaults to `1`
- `--flow` just flow my comments to maximize space and don't try to align them vertically; defaults to `off`
- `--padding` provide a margin of at least this many characters between the comment gully and the code; defaults to `3`
- `--grow` allow the comments to escape the block and flow `above` the code (the default), `below` the code, or `both`
- `--gravity` whether to afford more space to the `code`, the `comments` (the default)
- `--thick` try to utilize all the columns first, and then grow in height; defaults to `off`
- `--thin` try to utilize all the lines first, and then grow in width; defaults to `off`
- `--justify` justify the comments

## License
MIT
