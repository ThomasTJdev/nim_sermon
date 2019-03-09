# Package

version       = "0.2.5"
author        = "ThomasTJdev"
description   = "Tool to monitor various items on your Linux server"
license       = "MIT"
skipDirs      = @["src"]
bin           = @["sermon"]
installFiles  = @["config_default.cfg"]


# Dependencies

requires "nim >= 0.19.4"
requires "jester >= 0.4.1"

import distros
task setup, "Generating executable":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

before install:
  setupTask()