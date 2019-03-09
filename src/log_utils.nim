# Copyright 2018 - Thomas T. Jarløv

import terminal

proc error*(msg: string) =
  styledWriteLine(stderr, fgRed, "Error:   ", resetStyle, msg)

proc warning*(msg: string) =
  styledWriteLine(stderr, fgMagenta, "Warning: ", resetStyle, msg)

proc info*(msg: string) =
  styledWriteLine(stderr, fgWhite, "Info:    ", resetStyle, msg)

proc success*(msg: string) =
  styledWriteLine(stderr, fgGreen, "Success: ", resetStyle, msg)

proc debug*(msg: string) =
  when defined(dev):
    styledWriteLine(stderr, fgYellow, "Debug:   ", resetStyle, msg)

proc infoCus*(topic, msg: string) =
  styledWriteLine(stderr, fgWhite, topic, resetStyle, msg)

proc infoBlank*(topic, msg: string) =
  styledWriteLine(stderr, fgWhite, "         ", resetStyle, msg)