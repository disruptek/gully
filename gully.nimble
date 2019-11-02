version = "0.0.3"
author = "disruptek"
description = "a tiny tool to format code comments"
license = "MIT"
requires "nim >= 0.20.0"
requires "cligen >= 0.9.41"
requires "npeg >= 0.20.0"
requires "bump >= 1.8.3"
requires "https://github.com/stefantalpalaru/nim-unittest2.git >= 0.0.1"
requires "https://github.com/disruptek/cutelog.git >= 1.0.0"

srcDir = "src"
bin = @["gully"]
