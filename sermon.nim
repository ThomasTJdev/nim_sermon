# Copyright 2018 - Thomas T. Jarløv
## sermon
## ---------
##
## This program purpose is to monitor your system
## health using standard Linux tools. Therefore
## Linux is required.
##
## The idea of the program is to run it on your **ser**ver
## and **mon**itor the health. Which is also the reason
## for the name **sermon**.
##
## The program can run on your local machine
## or on your server. The best way to run the program
## is by adding it as a system service.
##
## Usage
## =====
## .. code-block::plain
##    sermon [options]
##
## Options
## =======
## .. code-block::plain
##    -h, --help          Show this output
##    -c, --config        Prints the path to your config file
##    -s, --show          Prints the current health to the console
##    -cs, --clustershow  Prints the current health of all nodes in cluster
##    -cp, --clusterping  Checks the connection to the cluster nodes
##    -ms, --mailstatus   Send a mail with health to emails in config
##
## Config file
## ============
## The config file (`config.cfg`) is where you specify
## the details which sermon use.
##
## To disable integers, set them to 0.
##
##
## Cluster
## =======
## The current GIT repo does not support the cluster
## parameter. The purpose of the cluster if to give
## you 1 place to monitor all of your sermon instances.
##
## Currently you can only access the cluster in
## the WWW-view - terminal is not supported.
##
## To enable cluster, compile with `-d:cluster`
##
## Example output
## --------------
## .. code-block::plain
##    $ sermon -s
##
##    ----------------------------------------
##               System status
##    ----------------------------------------
##    Last boot:  system boot  2018-10-27 06:43
##    Uptime:     10:25:07 up  3:42,  1 user,  load average: 1,00, 1,00, 0,88
##    System:     Linux sys 4.18.16-arch1-1-ARCH
##
##    ----------------------------------------
##                  Memory usage
##    ----------------------------------------
##    Error:   Mem: Usage: 3,0Gi - Limit: 2.0
##    Success: Swap: Usage: 0B - Limit: 1000.0
##
##    ----------------------------------------
##                  Memory per process
##    ----------------------------------------
##    Error:   nginx=26Mb > 20
##    Success: sshd=23Mb < 25
##    Error:   servermon=23Mb > 2
##
##
##    ----------------------------------------
##                  Process status
##    ----------------------------------------
##    Error:   ● nginx.service - Active: inactive (dead)
##    Error:   ● sshd.service - Active: inactive (dead)
##    Info:    servermon is not a service
##
##    ----------------------------------------
##                  Space usage
##    ----------------------------------------
##    Error:   You have reached your warning storage level at 40
##
##    Success: Filesystem                           Size  Used Avail Use% Mounted on
##    Success: dev                                  6,8G     0  6,8G   0% /dev
##    Success: run                                  6,8G  1,3M  6,8G   1% /run
##    Error:   /dev/mapper/AntergosVG-AntergosRoot  600G  150G  150G  50% /
##    Success: tmpfs                                5,8G   24M  5,7G   1% /dev/shm
##    Success: /dev/sda1                            243M   76M  151M  34% /boot
##
##    ----------------------------------------
##                  URL health
##    ----------------------------------------
##    Error:   301 - https://redirecturl.com
##    Success: 200 - https://nim-lang.org


import asyncdispatch, httpclient, jester, json, htmlgen, nativesockets, parsecfg, strutils, times, os, re
import src/email, src/log_utils, src/tools

type
  Main = ref object ## Has main data
    identifier: string
    monitorinterval: int

  Urls = ref object ## URL and data
    urls: seq[string]
    responses: seq[string]

  Notify = ref object ## All elements which include a notification
    boot: bool
    dailyInfo: bool
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
    monitor: seq[string]
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
    dailyInfo: string
    infoEvery: int
    infoPause: int

  Mailsend = ref object
    url: int
    processState: int
    processMemory: int
    storage: int
    memory: int

  Html = ref object
    url: string
    processState: string
    processMemory: string
    storage: string
    storageErrors: string
    memory: string
    memoryErrors: string

  Cluster = ref object
    apiPort: Port
    apiKey: string
    apicluster: seq[string]

var
  notify: Notify
  main: Main
  urls: Urls
  monitorInterval: MonitorInterval
  processes: Processes
  info: Info
  alertlevel: Alertlevel
  timing: Timing
  mailsend: Mailsend
  html: Html
  cluster: Cluster

new(notify)
new(main)
new(urls)
new(monitorInterval)
new(processes)
new(info)
new(alertlevel)
new(timing)
new(mailsend)
new(html)
new(cluster)

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

  let dict = loadConfig(getAppDir() & "/config.cfg")

  # Set up identifier
  main.identifier       = dict.getSectionValue("Sermon", "instanceID")
  debug($main[])

  # Cluset
  cluster.apiPort       = Port(parseInt(dict.getSectionValue("Cluster", "apiPort")))
  cluster.apiKey        = dict.getSectionValue("Cluster", "apiKey")
  for i in split(dict.getSectionValue("Cluster", "apiCluster"), ","):
    cluster.apicluster.add(i)
  debug($cluster[])

  # Set up SMTP
  smtpDetails.address   = dict.getSectionValue("SMTP", "SMTPAddress")
  smtpDetails.port      = dict.getSectionValue("SMTP", "SMTPPort")
  smtpDetails.fromMail  = dict.getSectionValue("SMTP", "SMTPFrom")
  smtpDetails.user      = dict.getSectionValue("SMTP", "SMTPUser")
  smtpDetails.password  = dict.getSectionValue("SMTP", "SMTPPassword")
  for i in split(dict.getSectionValue("SMTP", "SMTPMailTo"), ","):
    smtpDetails.toMail.add(i)
  debug($smtpDetails[])

  # Set up info choices
  info.system         = parseBool(dict.getSectionValue("Monitor", "system"))
  debug($info[])

  # Set up notifications
  notify.boot           = parseBool(dict.getSectionValue("Notify", "boot"))
  notify.dailyInfo      = parseBool(dict.getSectionValue("Notify", "dailyInfo"))
  notify.processState   = parseBool(dict.getSectionValue("Notify", "processState"))
  notify.urlResponse    = parseBool(dict.getSectionValue("Notify", "processMemory"))
  notify.memoryUsage    = parseBool(dict.getSectionValue("Notify", "urlResponse"))
  notify.processMemory  = parseBool(dict.getSectionValue("Notify", "memoryUsage"))
  notify.storageUse     = parseBool(dict.getSectionValue("Notify", "storageUse"))
  debug($notify[])

  # Set up monitor interval
  monitorInterval.urlResponse   = parseInt(dict.getSectionValue("Monitor_interval", "urlResponse"))
  monitorInterval.processState  = parseInt(dict.getSectionValue("Monitor_interval", "processState"))
  monitorInterval.processMemory = parseInt(dict.getSectionValue("Monitor_interval", "processMemory"))
  monitorInterval.memoryUsage   = parseInt(dict.getSectionValue("Monitor_interval", "memoryUsage"))
  monitorInterval.storageUse    = parseInt(dict.getSectionValue("Monitor_interval", "storageUse"))
  debug($monitorInterval[])

  # Set up timing
  timing.dailyInfo      = dict.getSectionValue("Notify_settings", "infoDaily")
  timing.infoEvery      = parseInt(dict.getSectionValue("Notify_settings", "infoEvery"))
  timing.infoPause      = parseInt(dict.getSectionValue("Notify_settings", "infoPause"))
  debug($timing[])

  # Set up alert levels
  alertlevel.storageUse   = parseInt(dict.getSectionValue("Alert_level", "storageUse"))
  alertlevel.memoryUsage  = parseInt(dict.getSectionValue("Alert_level", "memoryUse"))
  alertlevel.swapUse      = parseInt(dict.getSectionValue("Alert_level", "swapUse"))
  debug($alertlevel[])

  # Set up URLs
  for i in split(dict.getSectionValue("URL", "urls"), ","):
    urls.urls.add(i)
  for i in split(dict.getSectionValue("URL", "reponses"), ","):
    urls.responses.add(i)
  debug($urls[])

  # Set up processes
  for i in split(dict.getSectionValue("Processes", "processes"), ","):
    processes.monitor.add(i)
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


proc checkUrl(notifyOn = true, print = false, htmlGen = false) =
  ## Monitor urls
  if urls.responses.len() == 0:
    return

  if htmlGen:
    html.url = ""
    html.url = "<tr><td class=\"heading\">Response</td><td class=\"heading\">URL</td>"

  for url in urls.urls:
    let responseCode = responseCodes(url).substr(0,2)
    if urls.responses.contains(responseCode):
      if notifyOn and notify.urlResponse:
        notifyUrl(url, responseCode)

      if print:
        error(responseCode & " - " & url)

      if htmlGen:
        html.url.add("<tr><td class=\"error\">" & responseCode & "</td><td>" & url & "</td></tr>")

    else:
      if print:
        success(responseCode & " - " & url)

      if htmlGen:
        html.url.add("<tr><td class=\"success\">" & responseCode & "</td><td>" & url & "</td></tr>")


proc checkProcessState(notifyOn = true, print = false) =
  ## Monitor processes using systemctl

  for pros in processes.monitor:
    let prosData = systemctlStatus(pros)
    if prosData.contains("could not be found") or prosData.contains("is not a service"):
      if print:
        info(pros & " is not a service")

      if notifyOn:
        notifyProcesState(pros, "could not be found", prosData)

    elif prosData.contains("inactive (dead)"):
      if print:
        error(pros & " is inactive (dead)")

      if notifyOn:
        notifyProcesState(pros, "is inactive (dead)", prosData)

    else:
      if print:
        success(pros & " is active (running)")


proc checkProcessStateHtml() =
  ## Generate HTML for process' state
  if processes.monitor.len() == 0:
    return

  html.processState.add("<tr><td class=\"heading\">Process</td><td class=\"heading\">State</td></tr>")

  for pros in processes.monitor:
    var prosData: string
    let prosStatus = systemctlStatus(pros)

    if prosStatus.contains("Active: inactive (dead)"):
      let prosHtmlState = split(splitLines(systemctlStatus(pros))[0], " - ")[0]
      let prosHtmlProcess = splitLines(systemctlStatus(pros))[2]
      html.processState.add("<tr><td class=\"error\">" & prosHtmlState & "</td><td>" & prosHtmlProcess & "</td></tr>")

    elif prosStatus.contains("is not a service") or prosStatus.contains("could not be found"):
      html.processState.add("<tr><td class=\"error\">" & pros & "</td><td>is not a service</td></tr>")

    else:
      let prosHtmlState = split(splitLines(systemctlStatus(pros))[0], " - ")[0]
      let prosHtmlProcess = splitLines(systemctlStatus(pros))[2]
      html.processState.add("<tr><td class=\"success\">" & prosHtmlState & "</td><td>" & prosHtmlProcess & "</td></tr>")


proc checkProcessMem(notifyOn = true, print = false, htmlGen = false) =
  ## Monitor the processes memory usage
  if processes.monitor.len() == 0:
    return

  if htmlGen:
    html.processMemory.add("<tr><td class=\"heading\">Process</td><td class=\"heading\">Limit</td><td class=\"heading\">Usage</td></tr>")

  var prosCount = 0
  for pros in processes.monitor:
    let prosData = memoryUsageSpecific(pros)
    let memUsage = prosData.findAll(re".*Mb")

    if processes.maxmemoryUsage[prosCount] != 0 and memUsage.len() > 0:
      for mem in memUsage:
        if parseInt(mem.multiReplace([("Mb", ""), ("=", "")])) > processes.maxmemoryUsage[prosCount]:

          if notifyOn and notify.processMemory:
            notifyProcesMem(pros & " = " & prosData, $processes.maxmemoryUsage[prosCount])

          if print:
            error(pros & " = " & prosData & " > " & $processes.maxmemoryUsage[prosCount])

          if htmlGen:
            html.processMemory.add("<tr><td class=\"error\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & prosData & "</td></tr>")

        else:
          if print:
            success(pros & " = " & prosData & " < " & $processes.maxmemoryUsage[prosCount])

          if htmlGen:
            html.processMemory.add("<tr><td class=\"success\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & prosData & "</td></tr>")
    else:
      if print:
        success(pros & " = " & prosData & " < " & $processes.maxmemoryUsage[prosCount])

      if htmlGen:
        html.processMemory.add("<tr><td class=\"success\">" & pros & "</td><td class=\"center\">" & $processes.maxmemoryUsage[prosCount] & "MB</td><td class=\"center\">" & prosData & "</td></tr>")

    prosCount += 1


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
          if notifyOn and notify.storageUse: notifyStorage(line)
          if print: error(line)

        else:
          if print:success(line)
    else:
      if print: success(line)


proc checkStorageHtml(notifyOn = true, print = false, htmlGen = false) =
  ## Monitor storage
  if alertlevel.storageUse == 0:
    return

  if htmlGen:
    html.storage = ""
    html.storageErrors = ""

  var itemCount = 0
  let storageSeq = serverSpaceSeq()

  for line in storageSeq:

    if line.len() == 0:
      continue

    let spacePercent = line.findAll(re"\d\d%")
    if spacePercent.len() == 0:
      if print:
        success(line)

      if htmlGen:
        if itemCount in [0, 6, 12, 18, 24, 30, 36, 42, 48, 54]:
          html.storage.add("<tr><td class=\"item\">" & line & "</td>")
        elif itemCount in [5, 11, 17, 23, 29, 35, 41, 47, 53]:
          html.storage.add("<td>" & line & "</td></tr>")
        else:
          html.storage.add("<td>" & line & "</td>")

    else:
      for spacePer in spacePercent:
        if alertlevel.storageUse != 0 and
              parseInt(spacePer.substr(0,1)) > alertlevel.storageUse:
          if notifyOn and notify.storageUse:
            notifyStorage(line)

          if print:
            error(line)

          if htmlGen:
            html.storageErrors = "<p class=\"error\">Usage: " & spacePer & " - Limit: " & $alertlevel.storageUse & "% = " & storageSeq[itemCount-4] & "</p>"
            html.storage.add("<td class=\"error\">" & line & "</td>")

        else:
          if print:
            success(line)

          if htmlGen:
            html.storage.add("<td>" & line & "</td>")

    itemCount += 1


proc checkMemory(notifyOn = true, print = false, htmlGen = false) =
  ## Monitor storage
  if alertlevel.memoryUsage == 0 and alertlevel.swapUse == 0:
    return

  if htmlGen:
    html.memory = ""
    html.memoryErrors = ""

  let memTotal = memoryUsage().split("\n")
  let memTotalSeq = memoryUsageSeq()
  var itemCount = 0

  for item in memTotalSeq:
    if item.len() == 0:
      continue

    if itemCount == 0:
      if htmlGen: html.memory.add("<tr class=\"memory\"><td class=\"item\">Item</td>")

    if itemCount in [6, 13, 20, 27]:
      if htmlGen: html.memory.add("<tr class=\"memory\"><td class=\"item\">" & item & "</td>")

    elif itemCount in [5, 12, 18, 25]:
      if htmlGen: html.memory.add("<td>" & item & "</td></tr>")

    elif itemCount notin [8, 15, 22, 29]:
      if htmlGen: html.memory.add("<td>" & item & "</td>")

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

      if error:
        if notifyOn and notify.memoryUsage:
          notifyMemory(memTotalSeq[itemCount-2], item, $alertFloat)

        if print:
          error(memTotalSeq[itemCount-2] & " usage = " & item & " - limit = " & $alertFloat)

        if htmlGen:
          html.memoryErrors = "<p class=\"error\">" & memTotalSeq[itemCount-2] & " usage = " & item & " - limit = " & $alertFloat & "</p>"
          html.memory.add("<td class=\"error\">" & item & "</td>")

      else:
        if print:
          success(memTotalSeq[itemCount-2] & " usage = " & item & " - limit = " & $alertFloat)

        if htmlGen:
          html.memory.add("<td class=\"success\">" & item & "</td>")

    itemCount += 1




proc monitorUrl() {.async.} =
  ## Loop to monitor the urls
  while notify.urlResponse:
    if monitorInterval.urlResponse == 0:
      break
    checkUrl()
    await sleepAsync(monitorInterval.urlResponse * 1000)

proc monitorProcessState() {.async.} =
  ## Loop to monitor the processes
  while notify.processState:
    if monitorInterval.processState == 0:
      break
    checkProcessState()
    await sleepAsync(monitorInterval.processState * 1000)

proc monitorProcessMem() {.async.} =
  ## Loop to monitor the processes memory usage
  while notify.processMemory:
    if monitorInterval.processMemory == 0:
      break
    checkProcessMem()
    await sleepAsync(monitorInterval.processMemory * 1000)

proc monitorStorage() {.async.} =
  ## Loop to monitor the storage
  while notify.storageUse:
    if monitorInterval.storageUse == 0:
      break
    checkStorage()
    await sleepAsync(monitorInterval.storageUse * 1000)

proc monitorMemory() {.async.} =
  ## Loop to monitor the storage
  while notify.memoryUsage:
    if monitorInterval.memoryUsage == 0:
      break
    checkMemory()
    await sleepAsync(monitorInterval.memoryUsage * 1000)


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
  table.url {
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
  table.url td.heading {
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
  checkProcessStateHtml()
  checkUrl(false, false, true)
  checkMemory(false, false, true)
  checkStorageHtml(false, false, true)
  checkProcessMem(false, false, true)

  let htmlOut = "<html><head>" & css & "</head><body>" &
              "<h1>" & main.identifier & "</h1> started: " & $now() &
              "<hr>" &
              "<h3>System:</h3>" &
              notifyBaseInfo() &
              "<hr>" &
              "<h3>Process memory usage: </h3><table class=\"processMemory\">" & html.processMemory & "</table>" &
              "<hr>" &
              "<h3>Process state: </h3><table class=\"processState\">" & html.processState & "</table>" &
              "<hr>" &
              "<h3>Memory: </h3>" & html.memoryErrors & "<table class=\"memory\">" & html.memory & "</table>" &
              "<hr>" &
              "<h3>Space: </h3>" & html.storageErrors & "<table class=\"storage\">" & html.storage & "</table>" &
              "<hr>" &
              "<h3>URL: </h3><table class=\"url\">" & html.url & "</table>" &
              "<hr>" &
              "</body></html>"

  # Clear
  html.processMemory = ""
  html.processState = ""
  html.memoryErrors = ""
  html.memory = ""
  html.storageErrors = ""
  html.storage = ""
  html.url = ""

  return htmlOut

proc notifyOnboot() =
  ## Send email on boot
  if info.system:
    asyncCheck sendMail((main.identifier & " started: " & $now()), genHtml())

  else:
    asyncCheck sendMail(main.identifier & " started (sermon)", main.identifier & " started: " & $now())


proc showHealth() =
  ## Prints the health of the current node
  echo "----------------------------------------"
  echo "              System status"
  echo "----------------------------------------"
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
  echo "----------------------------------------"
  echo "              Memory usage"
  echo "----------------------------------------"
  checkMemory(false, true, false)
  echo "\n"
  echo "----------------------------------------"
  echo "              Memory per process"
  echo "----------------------------------------"
  checkProcessMem(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              Process status"
  echo "----------------------------------------"
  checkProcessState(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              Space usage"
  echo "----------------------------------------"
  if alertlevel.storageUse != 0 and serverSpace().findAll(re"\d\d%").len() > 0:
    for spacePer in serverSpace().findAll(re"\d\d%"):
      if parseInt(spacePer.substr(0,1)) > alertlevel.storageUse:
        error("You have reached your warning storage level at " & $alertlevel.storageUse & "\n")
        break
  checkStorage(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              URL health"
  echo "----------------------------------------"
  checkUrl(false, true, false)
  echo "\n"





proc dailyInfo() {.async.} =
  ## Run job every day at HH:mm
  let nextRun = toTime(parse(getDateStr() & " " & timing.dailyInfo, "yyyy-MM-dd HH:mm")) + 1.days
  var waitBeforeRun = parseInt($toUnix(nextRun))
  let firstWaiting = parseInt($(waitBeforeRun - toInt(epochTime())))
  await sleepAsync(firstWaiting * 1000)

  while notify.dailyInfo:
    when defined(dev): info("dailyInfo() running")

    asyncCheck sendMail((main.identifier & ": " & $now()), genHtml())

    if timing.infoEvery != 0:
      await sleepAsync(timing.infoEvery * 1000 * 60000)
    else:
      waitBeforeRun += 86400
      await sleepAsync((waitBeforeRun - toInt(epochTime())) * 1000)



proc init() =
  loadConfig()

  if notify.boot:
    notifyOnboot()

  if notify.urlResponse:
    asyncCheck monitorUrl()

  if notify.processState:
    asyncCheck monitorProcessState()

  if notify.processMemory:
    asyncCheck monitorProcessMem()

  if notify.memoryUsage:
    asyncCheck monitorMemory()

  if notify.storageUse:
    asyncCheck monitorStorage()

  if notify.dailyInfo:
    asyncCheck dailyInfo()



when isMainModule:
  if not fileExists(getAppDir() & "/config.cfg"):
    warning("The config file, config.cfg, does not exists.")
    info("Generating a standard config for you.")
    info("You can edit it anytime: config.cfg")
    copyFile(getAppDir() & "/config_default.cfg", getAppDir() & "/config.cfg")
    success("Config file generated")

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
    quit(0)

  else:
    if args.len() != 0:
      warning("The provided argument does not exists: " & args)
      quit(0)

  if args.len() != 0:
    quit(0)

  init()


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