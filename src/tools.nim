# Copyright 2018 - Thomas T. Jarløv

import httpclient, nativesockets, strutils, osproc, streams

proc linuxOutToSeq(data: string): seq[string] =
  ## Loop through linux whitespace separated command
  ## and generates a seq[string]
  var ws = false
  var collector: string
  var outp: seq[string]
  for i in data:
    if isNilOrWhitespace($i):
      ws = true
      continue
    else:
      if ws and collector.len() != 0:
        outp.add(collector)
        collector = ""
      collector.add(i)
      ws = false

  if collector.len() != 0:
    outp.add(collector)

  return outp

#[Keeping - maybe psutil can use it
  proc seqToHtmlTable(data: seq[string], hasHeading: bool, headingCount, colCount: int): string =
  ## Loop through seq and generates HTML table
  var countCol = 0
  var countRow = 1
  var isHeading = true
  var html = ""
  for i in data:
    countCol += 1
    if countCol == 1:
      html.add("<tr>")

    if countCol == 1 and isHeading and hasHeading:
      html.add("<td></td>")

    html.add("<td>" & i & "</td>")

    if countCol == headingCount and isHeading and hasHeading:
      isHeading = false
      countCol = 0
      html.add("</tr>")
      continue

    if countCol == colCount:
      html.add("</tr>")
      countCol = 0
      continue

  if countCol < colCount:
    for i in countCol+1 .. colCount:
      html.add("<td></td>")
    html.add("</tr>")

  return html]#

proc responseCodes*(url: string): string =
  ## Return HTTP(s) response code
  var client = newHttpClient(timeout=3500)
  let status = client.request(url).status
  close(client)
  return status

proc serverSpace*(): string =
  ## Returns available disk space
  return execProcess("df -h")

proc serverSpaceSpecific*(location: string): string =
  ## Returns available disk space
  return execProcess("df -h " & location)

proc serverSpaceSeq*(): seq[string] =
  ## Returns data for memory and swap in seq[string]

  # Remove "mounted on" => "mounted"
  var outp = linuxOutToSeq(serverSpace())
  outp.delete(find(outp, "on"))
  return outp

proc serverSpaceValue*(location = "/"): string =

  return execProcess("df --human-readable --local --output=avail " & location).replace("Avail\n", "").strip()

#[proc serverSpaceHtml*(): string =
  ## Returns data for memory and swap in seq[string]
  return "<table>" & seqToHtmlTable(serverSpaceSeq(), false, 6, 6) & "</table>"]#

proc memoryUsage*(): string =
  ## Returns data for memory and swap
  return execProcess("free -h")

proc memoryUsageSeq*(): seq[string] =
  ## Returns data for memory and swap in seq[string]
  return linuxOutToSeq(memoryUsage())

#[proc memoryUsageHtml*(): string =
  ## Returns data for memory and swap in a HTML formatted string
  return "<table>" & seqToHtmlTable(memoryUsageSeq(), true, 6, 7) & "</table>"]#

proc memoryUsageSpecific*(process: string): float =
  ## Returns the specific memory usage for a process
  let pid = execProcess("pgrep -x " & process)
  if pid.len() == 0:
    return 0

  var memTot: float
  var memOut: string

  for pi in split(pid):
    if pi.len() == 0:
      continue
    let mem = execProcess("ps -p " & pi & " -o rss").replace("RSS\n").strip()
    let memMB = (parseInt($mem) / 1024)
    memTot += memMB

  return memTot
  #return execProcess("""ps -A -o pid,rss,command | grep """ & process & """ | grep -v grep | awk '{total+=$2}END{printf("%dMb", total/1024)}'""").replace("\n", "")

proc os*(): string =
  ## Returns OS details
  return execProcess("uname -a").strip()

proc pubIP*(): string =
  ## Return public IP
  var client = newHttpClient(timeout=1000)
  try:
    return client.getContent("http://api.ipify.org").strip()
  except:
    return "timeout (1000ms)"

proc lastBoot*(): string =
  ## Returns boot time
  return execProcess("who -b").strip().replace("\n", "")

proc uptime*(): string =
  ## Returns uptime
  return execProcess("uptime --pretty").strip() & " since " & execProcess("uptime --since").strip()

proc rebootRequired*(): bool =
  ## Returns if reboot is required
  ##
  ## Does no support all OS.
  ## TODO: Find solution
  if execProcess("ls /var/run/reboot-required") == "/var/run/reboot-required":
    return true
  else:
    return false

proc packageUpgradable*(): string =
  ## Returns upgradable packages
  if not execProcess("which apt").contains("no apt"):
    return execProcess("/usr/lib/update-notifier/apt-check --human-readable")
  elif not execProcess("which pacman").contains("no pacman"):
    return execProcess("pacman -Qu")

proc systemctlStatus*(process: string): string =
  ## Returns data for memory and swap
  return execProcess("systemctl status " & process)

proc mountPoint*(mountDir: string): string =
  ## Check if dir is a mountpoint
  return execProcess("mountpoint " & mountDir)