# Copyright 2019 - Thomas T. Jarløv

import
  asyncdispatch,
  httpclient,
  jester,
  json,
  htmlgen,
  nativesockets,
  parsecfg,
  strutils,
  times,
  os,
  re

import
  email,
  log_utils,
  tools

type
  Main = ref object ## Has main data
    identifier: string
    monitorinterval: int

  Urls = ref object ## URL and data
    urls: seq[string]
    responses: seq[string]

  Notify = ref object ## All elements which include a notification
    processState: bool
    processMemory: bool
    urlResponse: bool
    storageUse: bool
    memoryUsage: bool

  MonitorInterval = ref object ## Monitoring interval in seconds
    urlResponse: int
    processState: int
    processMemory: int
    storageUse: int
    memoryUsage: int

  Processes = ref object ## All the processes to watch
    processState: seq[string]
    processMemory: seq[string]
    maxmemoryusage: seq[int]

  Info = ref object ## General system information
    system: bool
    package: bool
    process: bool
    url: bool

  Alertlevel = ref object ## General system information
    storageUse: int
    memoryUsage: int
    swapUse: int

  Timing = ref object ## Various timing elements
    infoEvery: int
    infoPause: int

  Mailsend = ref object
    url: int
    processState: int
    processMemory: int
    storage: int
    memory: int

  Cluster = ref object
    apiPort: Port
    apiKey: string
    apicluster: seq[string]

  Mount = ref object
    mountPoint: seq[string]

var
  notify: Notify
  main: Main
  urls: Urls
  processes: Processes
  info: Info
  alertlevel: Alertlevel
  timing: Timing
  mailsend: Mailsend
  cluster: Cluster
  mount: Mount

new(notify)
new(main)
new(urls)
new(processes)
new(info)
new(alertlevel)
new(timing)
new(mailsend)
new(cluster)
new(mount)

const argHelp = """
Usage:
  sermon [option]

Options:
  -h, --help          Show this output
  -c, --config        Prints the path to your config file
  -s, --show          Prints the current health to the console
  -cs, --clustershow  Prints the current health of all nodes in cluster
  -cp, --clusterping  Checks the connection to the cluster nodes
  -ms, --mailstatus   Send a mail with health to emails in config"""


proc loadConfig() =
  ## Load the main config file

  let dict = loadConfig(getAppDir().replace("/src", "") / "config.cfg")

  # Set up identifier
  main.identifier       = dict.getSectionValue("Sermon", "instanceID")
  debug($main[])

  # Cluset
  cluster.apiPort       = Port(parseInt(dict.getSectionValue("Cluster", "apiPort")))
  cluster.apiKey        = dict.getSectionValue("Cluster", "apiKey")
  for i in split(dict.getSectionValue("Cluster", "apiCluster"), ","):
    cluster.apicluster.add(i)
  debug($cluster[])

  # Set up info choices
  info.system         = parseBool(dict.getSectionValue("Monitor", "system"))
  debug($info[])

  # Set up notifications
  notify.processState   = parseBool(dict.getSectionValue("Notify", "processState"))
  notify.processMemory  = parseBool(dict.getSectionValue("Notify", "processMemory"))
  notify.urlResponse    = parseBool(dict.getSectionValue("Notify", "urlResponse"))
  notify.memoryUsage    = parseBool(dict.getSectionValue("Notify", "memoryUsage"))
  notify.storageUse     = parseBool(dict.getSectionValue("Notify", "storageUse"))
  debug($notify[])

  # Set up alert levels
  alertlevel.storageUse   = parseInt(dict.getSectionValue("Alert_level", "storageUse"))
  alertlevel.memoryUsage  = parseInt(dict.getSectionValue("Alert_level", "memoryUse"))
  alertlevel.swapUse      = parseInt(dict.getSectionValue("Alert_level", "swapUse"))
  debug($alertlevel[])

  # Set up mountpoints
  for i in split(dict.getSectionValue("Mount", "mountpoint"), ","):
    mount.mountpoint.add(i)

  # Set up URLs
  for i in split(dict.getSectionValue("URL", "urls"), ","):
    urls.urls.add(i)
  for i in split(dict.getSectionValue("URL", "reponses"), ","):
    urls.responses.add(i)
  debug($urls[])

  # Set up processes
  for i in split(dict.getSectionValue("Processes", "processState"), ","):
    processes.processState.add(i)
  for i in split(dict.getSectionValue("Processes", "processMemory"), ","):
    processes.processMemory.add(i)
  for i in split(dict.getSectionValue("Processes", "maxMemoryUse"), ","):
    processes.maxmemoryUsage.add(parseInt(i))
  debug($processes[])



proc mailAllowed(lastMailSend: int): bool =
  ## Check if mail waiting time is over
  if lastMailSend == 0 or toInt(epochTime()) > (lastMailSend + timing.infoPause * 60):
    return true
  else:
    return false

proc notifyBaseInfo(): string =
  ## Generate base info to mails

  var base: string

  base.add(tr(("<td class=\"heading\">Item</td>") & ("<td class=\"heading\">Value</td>")))
  base.add(tr(("<td class=\"item\">Last boot:   </td>") & td(lastBoot())))
  base.add(tr(("<td class=\"item\">Uptime:      </td>") & td(uptime())))
  base.add(tr(("<td class=\"item\">System:      </td>") & td(os())))
  base.add(tr(("<td class=\"item\">Hostname:    </td>") & td(getHostname())))
  base.add(tr(("<td class=\"item\">Public IP:   </td>") & td(pubIP())))
  base.add(tr(("<td class=\"item\">Mem total:   </td>") & td($(getTotalMem() / 1024 / 1000) & "MB")))
  base.add(tr(("<td class=\"item\">Mem occupied:</td>") & td($(getOccupiedMem() / 1024 / 1000) & "MB")))
  base.add(tr(("<td class=\"item\">Mem free:    </td>") & td($(getFreeMem() / 1024 / 1000) & "MB")))
  base.add(tr(("<td class=\"item\">Nim verion:  </td>") & td($NimVersion)))
  base.add(tr(("<td class=\"item\">Compile time:</td>") & td($CompileTime)))
  base.add(tr(("<td class=\"item\">Compile data:</td>") & td($CompileDate)))

  return ("<table class=\"system\">" & (tbody(base)) & "</table>")

proc notifyUrl(url, responseCode: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.url):
    mailsend.url = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - URL (" & responseCode & ") alert: " & url, "<b>URL returned response code: </b>" & responseCode & "<br><b>URL:</b> " & url)

proc notifyProcesState(process, description, systemctl: string) =
  ## Notify proc on processes
  if mailAllowed(mailsend.processState):
    mailsend.processState = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - " & process & " " & description, "<b>Process changed to:</b><br>" & systemctl)

proc notifyProcesMem(process, maxmem: string) =
  ## Notify proc on process memory usage
  if mailAllowed(mailsend.processMemory):
    mailsend.processMemory = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - Process memory alert: " & process, "<b>Process is using above memory level.</b><br><b>Level: </b>" & maxmem & "<br><b>Process: </b>" & process)

proc notifyStorage(storagePath: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.storage):
    mailsend.storage = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - Storage warning, above " & $(alertlevel.storageUse) & "%", "<b>Warning level:<\b> " & $(alertlevel.storageUse) & "<br><br><b>Storage has increase above your warning level:<br></b>" & storagePath)

proc notifyMemory(element, usage, alert: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.memory):
    mailsend.memory = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - Memory warning, above " & alert & "%", "<b>Warning level:</b> " & alert & "<br><br><b>Memory usage has increase above your warning level:<br></b>" & element & " " & usage)


proc checkUrl(notifyOn = true, print = false, htmlGen = false): string =
  ## Monitor urls
  if urls.responses.len() == 0:
    return

  if htmlGen:
    result = "<tr><td class=\"heading\">Response</td><td class=\"heading\">URL</td>"

  for url in urls.urls:
    let responseCode = responseCodes(url).substr(0,2)
    if urls.responses.contains(responseCode):
      if notifyOn and notify.urlResponse:
        notifyUrl(url, responseCode)

      if print:
        error(responseCode & " - " & url)

      if htmlGen:
        result.add("<tr><td class=\"error\">" & responseCode & "</td><td>" & url & "</td></tr>")

    else:
      if print:
        success(responseCode & " - " & url)

      if htmlGen:
        result.add("<tr><td class=\"success\">" & responseCode & "</td><td>" & url & "</td></tr>")

proc checkUrlMon() =
  discard checkUrl(notifyOn = true, print = false, htmlGen = false)

proc checkUrlPrint() =
  discard checkUrl(notifyOn = false, print = true, htmlGen = false)

proc checkUrlHtml(notifyOn = true, print = false, htmlGen = false): string =
  return checkUrl(notifyOn = false, print = false, htmlGen = true)

proc checkProcessState(notifyOn = true, print = false) =
  ## Monitor processes using systemctl

  for pros in processes.processState:
    var prettyName = pros
    if prettyName.len() < 10:
      let count = (10 - prettyName.len())
      for i in countDown(count, 1):
        prettyName.add(" ")

    let prosData = systemctlStatus(pros)
    if prosData.contains("could not be found") or prosData.contains("is not a service"):
      if print:
        info(prettyName & ": is not a service")

      if notifyOn:
        notifyProcesState(pros, "could not be found", prosData)

    elif prosData.contains("inactive (dead)"):
      if print:
        error(prettyName & ": is inactive (dead)")

      if notifyOn:
        notifyProcesState(pros, "is inactive (dead)", prosData)

    else:
      if print:
        success(prettyName & ": is active (running)")


proc checkProcessStateMon() =
  checkProcessState(notifyOn = true, print = false)

proc checkProcessStatePrint() =
  checkProcessState(notifyOn = false, print = true)

proc checkProcessStateHtml(): string =
  ## Generate HTML for process' state
  if processes.processState.len() == 0:
    return

  result.add("<tr><td class=\"heading\">Process</td><td class=\"heading\">State</td></tr>")

  for pros in processes.processState:
    var prosData: string
    let prosStatus = systemctlStatus(pros)

    if prosStatus.contains("Active: inactive (dead)"):
      let prosHtmlState = split(splitLines(systemctlStatus(pros))[0], " - ")[0]
      let prosHtmlProcess = splitLines(systemctlStatus(pros))[2]
      result.add("<tr><td class=\"error\">" & prosHtmlState & "</td><td>" & prosHtmlProcess & "</td></tr>")

    elif prosStatus.contains("is not a service") or prosStatus.contains("could not be found"):
      result.add("<tr><td class=\"error\">" & pros & "</td><td>is not a service</td></tr>")

    else:
      let prosHtmlState = split(splitLines(systemctlStatus(pros))[0], " - ")[0]
      let prosHtmlProcess = splitLines(systemctlStatus(pros))[2]
      result.add("<tr><td class=\"success\">" & prosHtmlState & "</td><td>" & prosHtmlProcess & "</td></tr>")


proc checkProcessMem(notifyOn = true, print = false, htmlGen = false): string =
  ## Monitor the processes memory usage
  if processes.processMemory.len() == 0:
    return

  if htmlGen:
    result.add("<tr><td class=\"heading\">Process</td><td class=\"heading\">Limit</td><td class=\"heading\">Usage</td></tr>")

  var prosCount = 0
  for pros in processes.processMemory:
    var prettyName = pros
    if prettyName.len() < 10:
      let count = (10 - prettyName.len())
      for i in countDown(count, 1):
        prettyName.add(" ")

    let prosData = memoryUsageSpecific(pros)
    if prosData == 0:
      continue

    let memUsage = prosData #prosData.findAll(re".*Mb")

    var memPretty = $memUsage
    if ($memUsage).contains("."):
      memPretty = split($memUsage, ".")[0] & "." & split($memUsage, ".")[1].substr(0,1)

    if processes.maxmemoryUsage[prosCount] != 0:

      #for mem in memUsage:
      if toInt(memUsage) > processes.maxmemoryUsage[prosCount]:

        if notifyOn and notify.processMemory:
          notifyProcesMem(pros & ":  " & memPretty, $processes.maxmemoryUsage[prosCount])

        if print:
          error(prettyName & ": " & memPretty & " > " & $processes.maxmemoryUsage[prosCount] & "MB")

        if htmlGen:
          result.add("<tr><td class=\"error\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & memPretty & "MB</td></tr>")

      else:
        if print:
          success(prettyName & ": " & memPretty & " < " & $processes.maxmemoryUsage[prosCount] & "MB")

        if htmlGen:
          result.add("<tr><td class=\"success\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & memPretty & "MB</td></tr>")
    else:
      if print:
        success(prettyName & ": " & memPretty & "MB < " & $processes.maxmemoryUsage[prosCount] & "MB")

      if htmlGen:
        result.add("<tr><td class=\"success\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & memPretty & "MB</td></tr>")

    prosCount += 1


proc checkProcessMemMon() =
  discard checkProcessMem(notifyOn = true, print = false, htmlGen = false)

proc checkProcessMemPrint() =
  discard checkProcessMem(notifyOn = false, print = true, htmlGen = false)

proc checkProcessMemHtml(): string =
  return checkProcessMem(notifyOn = false, print = false, htmlGen = true)


proc checkStorage(notifyOn = true, print = false) =
  ## Monitor storage
  if alertlevel.storageUse == 0:
    return

  for line in serverSpace().split("\n"):
    if line.len() == 0:
      continue

    let spacePercent = line.findAll(re"\d\d%")
    if spacePercent.len() > 0:

      for spacePer in spacePercent:

        if alertlevel.storageUse != 0 and
              parseInt(spacePer.substr(0,1)) > alertlevel.storageUse:

          if notifyOn and notify.storageUse:
            notifyStorage(line)

          if print:
            error(line)

        else:
          if print:
            success(line)
    else:
      if print:
        success(line)

proc checkStorageMon() =
  checkStorage(notifyOn = true, print = false)

proc checkStoragePrint() =
  checkStorage(notifyOn = false, print = true)


proc checkStorageHtml(): tuple[ok: string, err: string] =
  ## Monitor storage
  if alertlevel.storageUse == 0:
    return

  var storage: string
  var storageErrors: string

  var itemCount = 0
  let storageSeq = serverSpaceSeq()

  for line in storageSeq:

    if line.len() == 0:
      continue

    let spacePercent = line.findAll(re"\d\d%")
    if spacePercent.len() == 0:

      if itemCount in [0, 6, 12, 18, 24, 30, 36, 42, 48, 54]:
        storage.add("<tr><td class=\"item\">" & line & "</td>")
      elif itemCount in [5, 11, 17, 23, 29, 35, 41, 47, 53]:
        storage.add("<td>" & line & "</td></tr>")
      else:
        storage.add("<td>" & line & "</td>")

    else:
      for spacePer in spacePercent:
        if alertlevel.storageUse != 0 and parseInt(spacePer.substr(0,1)) > alertlevel.storageUse:
          storageErrors = "<p class=\"error\">Usage: " & spacePer & " - Limit: " & $alertlevel.storageUse & "% = " & storageSeq[itemCount-4] & "</p>"

          storage.add("<td class=\"error\">" & line & "</td>")

        else:
          storage.add("<td>" & line & "</td>")

    itemCount += 1

  return (storage, storageErrors)


proc checkMemory(notifyOn = true, print = false, htmlGen = false): tuple[mem: string, memErr: string] =
  ## Monitor storage
  if alertlevel.memoryUsage == 0 and alertlevel.swapUse == 0:
    return

  var htmlMem: string
  var htmlMemErr: string

  let memTotal = memoryUsage().split("\n")
  let memTotalSeq = memoryUsageSeq()
  var itemCount = 0

  for item in memTotalSeq:
    if item.len() == 0:
      continue

    if itemCount == 0:
      if htmlGen: htmlMem.add("<tr class=\"memory\"><td class=\"item\">Item</td>")

    if itemCount in [6, 13, 20, 27]:
      if htmlGen: htmlMem.add("<tr class=\"memory\"><td class=\"item\">" & item & "</td>")

    elif itemCount in [5, 12, 18, 25]:
      if htmlGen: htmlMem.add("<td>" & item & "</td></tr>")

    elif itemCount notin [8, 15, 22, 29]:
      if htmlGen: htmlMem.add("<td>" & item & "</td>")

    else:
      # First line usage
      var alert = 0
      if memTotalSeq[itemCount-2] == "Swap:":
        alert = alertlevel.swapUse
      else:
        alert = alertlevel.memoryUsage

      var alertFloat: float
      if item.contains("Gi"):
        alertFloat = (alert / 1000)
      else:
        alertFloat = toFloat(alert)

      let mem = item.multiReplace([("Gi", ""), ("Mi", ""), (",", ".")])
      var error = false
      if alert == 0 or item.contains("B"):
        error = false

      elif item.contains("Gi"):
        if parseFloat(mem) > alertFloat:
          error = true

      elif item.contains("Mi"):
        if parseFloat(mem) > alertFloat:
          error = true

      var prettyName = memTotalSeq[itemCount-2]
      if prettyName.len() < 6:
        let count = (6 - prettyName.len())
        for i in countDown(count, 1):
          prettyName.add(" ")

      if error:
        if notifyOn and notify.memoryUsage:
          notifyMemory(memTotalSeq[itemCount-2], item, $alertFloat)

        if print:
          error(prettyName & " usage = " & item & " - limit = " & $alertFloat)

        if htmlGen:
          htmlMemErr = "<p class=\"error\">" & memTotalSeq[itemCount-2] & " usage = " & item & " - limit = " & $alertFloat & "</p>"
          htmlMem.add("<td class=\"error\">" & item & "</td>")

      else:
        if print:
          success(prettyName & " usage = " & item & " - limit = " & $alertFloat)

        if htmlGen:
          htmlMem.add("<td class=\"success\">" & item & "</td>")

    itemCount += 1

  return (htmlMem, htmlMemErr)


proc checkMemoryMon() =
  discard checkMemory(notifyOn = true, print = false, htmlGen = false)

proc checkMemoryPrint() =
  discard checkMemory(notifyOn = false, print = true, htmlGen = false)

proc checkMemoryHtml(): tuple[mem: string, memErr: string] =
  return checkMemory(notifyOn = false, print = false, htmlGen = true)


proc checkMountPrint() =
  for m in mount.mountpoint:
    let ret = mountPoint(m)
    if ret.contains("is a mountpoint"):
      success(ret)
    else:
      error(m & " was not found as a mountpoint")

proc checkMountHtml(): string =
  result = "<tr><td class=\"heading\">Mountpoint</td><td class=\"heading\">Is mounted</td>"
  for m in mount.mountpoint:
    let ret = mountPoint(m)
    if ret.contains("is a mountpoint"):
      result.add("<tr><td class=\"success\">" & m & "</td><td>is a mountpoint</td></tr>")
    else:
      result.add("<tr><td class=\"error\">" & m & "</td><td>not a mountpoint</td></tr>")


const css = """
<style>
  h3 {
    margin-bottom: 0.2rem;
  }
  hr {
    margin-top: 1rem;
  }
  .success {
    color: green;
  }
  .error {
    color: red;
  }
  table.system,
  table.storage,
  table.memory,
  table.processMemory,
  table.processState,
  table.url,
  table.mount {
    border: 1px solid grey;
  }
  table.system td.item,
  table.storage td.item,
  table.memory td.item {
    background: whitesmoke;
    font-weight: 500;
    padding: 3px;
    width: 120px;
  }
  table.system td.heading,
  table.processMemory td.heading,
  table.processState td.heading,
  table.url td.heading,
  table.mount td.heading {
    background: #122d3a;
    color: white;
    font-size: 115%;
    font-weight: 700;
    min-width: 120px;
    padding: 3px;
    text-align: center;
  }
  table.processMemory td.center {
    text-align: center;
  }
  table.memory tr td:first-child {
    background: whitesmoke;
    font-weight: 500;
    padding: 3px;
    width: 120px;
  }
</style>
"""

proc genHtml(): string =
  ## Generate HTML
  let processState = checkProcessStateHtml()
  let (storage, storageErrors) = checkStorageHtml()
  let url = checkUrlHtml()
  let mountData = checkMountHtml()
  let (mem, memErr) = checkMemoryHtml()
  let processMemory = checkProcessMemHtml()

  let htmlOut = "<html><head>" & css & "</head><body>" &
              "<h1>" & main.identifier & "</h1> started: " & $now() &
              "<hr>" &
              "<h3>System:</h3>" &
              notifyBaseInfo() &
              "<hr>" &
              "<h3>Process memory usage: </h3><table class=\"processMemory\">" & processMemory & "</table>" &
              "<hr>" &
              "<h3>Process state: </h3><table class=\"processState\">" & processState & "</table>" &
              "<hr>" &
              "<h3>Memory: </h3>" & memErr & "<table class=\"memory\">" & mem & "</table>" &
              "<hr>" &
              "<h3>Space: </h3>" & storageErrors & "<table class=\"storage\">" & storage & "</table>" &
              "<hr>" &
              "<h3>URL: </h3><table class=\"url\">" & url & "</table>" &
              "<hr>" &
              "<h3>Mount: </h3><table class=\"mount\">" & mountData & "</table>" &
              "<hr>" &
              "</body></html>"

  return htmlOut


proc showHealth() =
  ## Prints the health of the current node
  echo "------------------------------------------------------"
  echo "              System status"
  echo "------------------------------------------------------"
  infoCus("Last boot:    ", lastBoot())
  infoCus("Uptime:       ", uptime())
  infoCus("System:       ", os())
  infoCus("Hostname:     ", getHostname())
  infoCus("Public IP:    ", pubIP())
  infoCus("Mem total:    ", $(getTotalMem() / 1024 / 1000) & "MB")
  infoCus("Mem occupied: ", $(getOccupiedMem() / 1024 / 1000) & "MB")
  infoCus("Mem free:     ", $(getFreeMem() / 1024 / 1000) & "MB")
  infoCus("Nim verion:   ", $NimVersion)
  infoCus("Compile time: ", $CompileTime)
  infoCus("Compile data: ", $CompileDate)
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Configuration"
  echo "------------------------------------------------------"
  echo "Monitor process state : " & $processes.processState
  echo "Monitor process memory: " & $processes.processMemory
  echo "Monitor url response  : " & $urls.urls
  echo "Mountpoints to check  : " & $mount.mountpoint
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Memory usage"
  echo "------------------------------------------------------"
  checkMemoryPrint()
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Process status"
  echo "------------------------------------------------------"
  checkProcessStatePrint()
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Memory per process"
  echo "------------------------------------------------------"
  checkProcessMemPrint()
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Space usage"
  echo "------------------------------------------------------"
  if alertlevel.storageUse != 0 and serverSpace().findAll(re"\d\d%").len() > 0:
    for spacePer in serverSpace().findAll(re"\d\d%"):
      if parseInt(spacePer.substr(0,1)) > alertlevel.storageUse:
        error("You have reached your warning storage level at " & $alertlevel.storageUse & "\n")
        break
  checkStoragePrint()
  echo "\n"
  echo "------------------------------------------------------"
  echo "              Mount"
  echo "------------------------------------------------------"
  checkMountPrint()
  echo "\n"
  echo "------------------------------------------------------"
  echo "              URL health"
  echo "------------------------------------------------------"
  checkUrlPrint()
  echo "\n"


proc check() =
  loadConfig()

  if notify.urlResponse:
    checkUrlMon()

  if notify.processState:
    checkProcessStateMon()

  if notify.processMemory:
    checkProcessMemMon()

  if notify.memoryUsage:
    checkMemoryMon()

  if notify.storageUse:
    checkStorageMon()


proc run() =

  echo "sermon: The health of your system and more\n"

  let args = multiReplace(commandLineParams().join(" "), [("-", ""), (" ", "")])
  case args
  of " ":
    discard

  of "h", "help":
    echo argHelp

  of "s", "show":
    info("Loading config file")
    loadConfig()
    info("Config file loaded to memory\n")
    showHealth()

  of "c", "config":
    echo "Path to config file:"
    echo getAppDir() & "/config.json"

  of "cs", "clustershow":
    warning("Not implemented")

  of "cp", "clusterping":
    warning("Not implemented")

  of "ms", "mailstatus":
    info("Loading config file")
    loadConfig()
    info("Config file loaded to memory\n")
    info("Sending mail with system health")
    waitFor sendMail((main.identifier & " mailinfo: " & $now()), genHtml())

  of "m", "monitor":
    info("Loading config file")
    info("Check startet\n")
    check()

  else:
    if args.len() != 0:
      warning("The provided argument does not exists: " & args)

  quit()

run()


when defined(cluster):
  settings:
    port = cluster.apiPort

  routes:
    get "/@api":
      cond(@"api" == cluster.apiKey)
      resp(genHtml())

    get "/cluster":
      cond(@"api" == cluster.apiKey)

      if cluster.apicluster.len() == 0:
        resp("No cluster")

      var client = newHttpClient()
      var clustHtml = ""
      for cluster in cluster.apicluster:
        clustHtml.add(getContent(cluster))

      resp (genHtml() & clustHtml)