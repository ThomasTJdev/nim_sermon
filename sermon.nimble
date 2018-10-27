# Package

version       = "0.1.0"
author        = "ThomasTJdev"
description   = "Tool to monitor various items on your Linux instance"
license       = "MIT"
srcDir        = "src"
bin           = @["sermon"]


# Dependencies

requires "nim >= 0.19.0"
requires "jester >= 0.4.1"

import distros
if detectOs(Windows):
  echo "Cannot run on Windows"
  quit()