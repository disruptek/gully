version = "0.0.4"
author = "disruptek"
description = "a tiny tool to format code comments"
license = "MIT"
requires "cligen < 2.0.0"
requires "npeg < 1.0.0"
requires "bump >= 1.8.3 & < 2.0.0"
requires "https://github.com/stefantalpalaru/nim-unittest2.git >= 0.0.1"
requires "https://github.com/disruptek/cutelog.git >= 1.0.0 & < 2.0.0"

srcDir = "src"
bin = @["gully"]
