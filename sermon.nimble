# Package

version       = "0.3.1"
author        = "ThomasTJdev"
description   = "Tool to monitor various items on your Linux server"
license       = "MIT"
bin           = @["sermon"]
installDirs   = @["src"]
installFiles  = @["config_default.cfg"]


# Dependencies

requires "nim >= 0.20.2"
requires "jester >= 0.4.3"

import distros
task setup, "Generating executable":
  if detectOs(Windows):
    echo "Cannot run on Windows"
    quit()

before install:
  setupTask()