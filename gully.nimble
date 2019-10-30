version = "0.0.2"
author = "disruptek"
description = "a tiny tool to format code comments"
license = "MIT"
requires "nim >= 0.20.0"
requires "cligen#337c447118879ad875d40969619fc64a02b94312"
requires "npeg >= 0.20.0"
requires "https://github.com/stefantalpalaru/nim-unittest2.git >= 0.0.1"

srcDir = "src"
bin = @["gully"]
