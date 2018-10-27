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
## Example output
## --------------
## .. code-block::plain
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


import asyncdispatch, httpclient, jester, json, strutils, times, os, re
import email, logging, tools

type
  Main = object ## Has main data
    identifier: string
    monitorinterval: int

  Urls = object ## URL and data
    urls: seq[string]
    responses: seq[string]

  Notify = object ## All elements which include a notification
    boot: bool
    dailyinfo: bool
    processstate: bool
    processmemory: bool
    urlresponse: bool
    storagepercentage: bool
    memoryusage: bool

  MonitorInterval = object ## Monitoring interval in seconds
    urlresponse: int
    processstate: int
    processmemory: int
    storagepercentage: int
    memoryusage: int

  Processes = object ## All the processes to watch
    monitor: seq[string]
    maxmemoryusage: seq[int]
    systemctlNew: seq[string]
    systemctlOld: seq[string]

  Info = object ## General system information
    system: bool
    package: bool
    process: bool
    url: bool

  Alertlevel = object ## General system information
    storagepercentage: int
    memoryusage: int
    swapusage: int

  Timing = object ## Various timing elements
    dailyinfo: string
    dailyinfoevery: int
    mailnotify: int

  Mailsend = object
    url: int
    processstate: int
    processmemory: int
    storage: int
    memory: int

  Html = object
    url: string
    processstate: string
    processmemory: string
    storage: string
    storageErrors: string
    memory: string
    memoryErrors: string

  Www = object
    apiport: Port
    apikey: string
    apicluster: seq[string]

var notify: Notify
var main: Main
var urls: Urls
var monitorInterval: MonitorInterval
var processes: Processes
var info: Info
var alertlevel: Alertlevel
var timing: Timing
var mailsend: Mailsend
var html: Html
var www: Www


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
  var sermonConfig = parseFile(getAppDir() & "/config.json")
  for obj in items(sermonConfig):

    # Info
    if obj.hasKey("info"):
      info.system = obj["info"]["system"].getBool()
      info.package = obj["info"]["package"].getBool()
      info.process = obj["info"]["process"].getBool()
      info.url = obj["info"]["url"].getBool()

    # Processes
    if obj.hasKey("processes"):
      for i in items(obj["processes"]["monitor"]):
        processes.monitor.add(i.getStr())
      for i in items(obj["processes"]["maxmemoryusage"]):
        processes.maxmemoryusage.add(i.getInt())

    # URLs
    if obj.hasKey("urls"):
      for i in items(obj["urls"]["monitor"]):
        urls.urls.add(i.getStr())
      for i in items(obj["urls"]["response"]):
        urls.responses.add(i.getStr())

    # SMTP
    if obj.hasKey("email"):
      smtpDetails.address = obj["email"]["smtp"]["address"].getStr()
      smtpDetails.port = obj["email"]["smtp"]["port"].getStr()
      smtpDetails.fromMail = obj["email"]["smtp"]["from"].getStr()
      smtpDetails.user = obj["email"]["smtp"]["user"].getStr()
      smtpDetails.password = obj["email"]["smtp"]["password"].getStr()
      for i in items(obj["email"]["notifyemail"]):
        smtpDetails.toMail.add(i.getStr())

    # Notify
    if obj.hasKey("notify"):
      notify.boot = obj["notify"]["boot"].getBool()
      notify.dailyinfo = obj["notify"]["dailyinfo"].getBool()
      notify.processstate = obj["notify"]["processstate"].getBool()
      notify.processmemory = obj["notify"]["processmemory"].getBool()
      notify.urlresponse = obj["notify"]["urlresponse"].getBool()
      notify.storagepercentage = obj["notify"]["storagepercentage"].getBool()
      notify.memoryusage = obj["notify"]["memoryusage"].getBool()

     # Main
    if obj.hasKey("main"):
      main.identifier = obj["main"]["identifier"].getStr()

    # Monitor interval
    if obj.hasKey("monitorinterval"):
      monitorInterval.urlresponse = obj["monitorinterval"]["urlresponse"].getInt()
      monitorInterval.processstate = obj["monitorinterval"]["processstate"].getInt()
      monitorInterval.processmemory = obj["monitorinterval"]["processmemory"].getInt()
      monitorInterval.storagepercentage = obj["monitorinterval"]["storagepercentage"].getInt()
      monitorInterval.memoryusage = obj["monitorinterval"]["memoryusage"].getInt()

    # Space
    if obj.hasKey("alertlevel"):
      alertlevel.storagepercentage = obj["alertlevel"]["storagepercentage"].getInt()
      alertlevel.memoryusage = obj["alertlevel"]["memoryusage"].getInt()
      alertlevel.swapusage = obj["alertlevel"]["swapusage"].getInt()

    # Timing
    if obj.hasKey("timing"):
      timing.dailyinfo = obj["timing"]["dailyinfo"].getStr()
      timing.dailyinfoevery = obj["timing"]["dailyinfoevery"].getInt()
      timing.mailnotify = obj["timing"]["mailnotify"].getInt()

    # Timing
    if obj.hasKey("www"):
      www.apiport = Port(obj["www"]["apiport"].getInt())
      www.apikey = obj["www"]["apikey"].getStr()
      for i in items(obj["www"]["apicluster"]):
        www.apicluster.add(i.getStr())


proc mailAllowed(lastMailSend: int): bool =
  ## Check if mail waiting time is over
  if lastMailSend == 0 or toInt(epochTime()) > (lastMailSend + timing.mailnotify * 60):
    return true
  else:
    return false

proc notifyUrl(url, responseCode: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.url):
    mailsend.url = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - URL (" & responseCode & ") alert: " & url, "<b>URL returned response code: </b>" & responseCode & "<br><b>URL:</b> " & url)

proc notifyProcesState(process, systemctl: string) =
  ## Notify proc on processes
  if mailAllowed(mailsend.processstate):
    mailsend.processstate = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - proces state alert: " & process, "<b>Process changed to:</b><br>" & systemctl)

proc notifyProcesMem(process, maxmem: string) =
  ## Notify proc on process memory usage
  if mailAllowed(mailsend.processmemory):
    mailsend.processmemory = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - proces memory alert: " & process, "<b>Process is using above memory level.</b><br><b>Level: </b>" & maxmem & "<br><b>Process: </b>" & process)

proc notifyStorage(storagePath: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.storage):
    mailsend.storage = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - Storage warning, above " & $(alertlevel.storagepercentage) & "%", "<b>Warning level:<\b> " & $(alertlevel.storagepercentage) & "<br><br><b>Storage has increase above your warning level:<br></b>" & storagePath)

proc notifyMemory(element, usage, alert: string) =
  ## Notify when url response match an alert
  if mailAllowed(mailsend.memory):
    mailsend.memory = toInt(epochTime())
    asyncCheck sendMail(main.identifier & " - Memory warning, above " & alert & "%", "<b>Warning level:</b> " & alert & "<br><br><b>Memory usage has increase above your warning level:<br></b>" & element & " " & usage)



proc checkUrl(notifyOn = true, print = false) =
  ## Monitor urls
  if urls.responses.len() == 0:
    return
  html.url = ""
  for url in urls.urls:
    let responseCode = responseCodes(url).substr(0,2)
    if urls.responses.contains(responseCode):
      if notifyOn and notify.urlresponse: notifyUrl(url, responseCode)
      if print: error(responseCode & " - " & url)
      html.url.add("<tr><td class=\"error\">" & responseCode & " - " & url & "</td></tr>")
    else:
      if print: success(responseCode & " - " & url)
      html.url.add("<tr><td class=\"success\">" & responseCode & " - " & url & "</td></tr>")

proc checkProcessState(notifyOn = true) =
  ## Monitor processes using systemctl
  processes.systemctlOld = processes.systemctlNew
  processes.systemctlNew = @[]

  for pros in processes.monitor:
    var prosData: string
    if systemctlStatus(pros).contains("could not be found"):
      prosData = pros & " is not a service"
    else:
      prosData = splitLines(systemctlStatus(pros))[0] &
                    " - " &
                    split(splitLines(systemctlStatus(pros))[2], ";")[0].strip()
    processes.systemctlNew.add(prosData)

    if processes.systemctlOld.len() > 0:
      if not processes.systemctlOld.contains(prosData):
        if notifyOn and notify.processstate: notifyProcesState(pros, prosData)

  processes.systemctlOld = @[]

proc checkProcessStateHtml() =
  ## Generate HTML for process' state
  html.processstate = ""
  checkProcessState(false)
  for pros in processes.systemctlNew:
    if pros.contains("Active: inactive (dead)"):
      html.processstate.add("<tr><td class=\"error\">" & pros.replace(re"-.*-", "-") & "</td></tr>")
    elif pros.contains("is not a service"):
      html.processstate.add("<tr><td>" & pros.replace(re"-.*-", "-") & "</td></tr>")
    else:
      html.processstate.add("<tr><td class=\"success\">" & pros.replace(re"-.*-", "-") & "</td></tr>")

proc checkProcessMem(notifyOn = true, print = false) =
  ## Monitor the processes memory usage
  html.processmemory = ""
  var prosCount = 0
  for pros in processes.monitor:
    let prosData = memoryUsageSpecific(pros)
    let memUsage = prosData.findAll(re"=.*Mb")

    if processes.maxmemoryusage[prosCount] != 0 and memUsage.len() > 0:
      for mem in memUsage:
        if parseInt(mem.multiReplace([("Mb", ""), ("=", "")])) > processes.maxmemoryusage[prosCount]:
          if notifyOn and notify.processmemory: notifyProcesMem(prosData, $processes.maxmemoryusage[prosCount])
          if print: error(prosData & " > " & $processes.maxmemoryusage[prosCount])
          html.processmemory.add("<tr><td class=\"error\">" & prosData & " > " & $processes.maxmemoryusage[prosCount] & "</td></tr>")
        else:
          if print: success(prosData & " < " & $processes.maxmemoryusage[prosCount])
          html.processmemory.add("<tr><td class=\"success\">" & prosData & " > " & $processes.maxmemoryusage[prosCount] & "</td></tr>")
    else:
      if print: success(prosData & " < " & $processes.maxmemoryusage[prosCount])
      html.processmemory.add("<tr><td class=\"success\">" & prosData & " > " & $processes.maxmemoryusage[prosCount] & "</td></tr>")

    prosCount += 1

proc checkStorage(notifyOn = true, print = false) =
  ## Monitor storage
  if alertlevel.storagepercentage == 0:
    return

  html.storage = ""
  for line in serverSpace().split("\n"):
    if line.len() == 0:
      continue

    let spacePercent = line.findAll(re"\d\d%")
    if spacePercent.len() > 0:
      for spacePer in spacePercent:
        if alertlevel.storagepercentage != 0 and
              parseInt(spacePer.substr(0,1)) > alertlevel.storagepercentage:
          if notifyOn and notify.storagepercentage: notifyStorage(line)
          if print: error(line)
        else:
          if print: success(line)
    else:
      if print: success(line)

proc checkStorageHtml(notifyOn = true, print = false) =
  ## Monitor storage
  if alertlevel.storagepercentage == 0:
    return

  html.storage = ""
  html.storageErrors = ""
  var itemCount = 0
  let storageSeq = serverSpaceSeq()

  for line in storageSeq:

    if line.len() == 0:
      continue
    let spacePercent = line.findAll(re"\d\d%")
    if spacePercent.len() == 0:
      if print: success(line)
      if itemCount in [0, 6, 12, 18, 24, 30, 36, 42, 48, 54]:
        html.storage.add("<tr><td>" & line & "</td>")
      elif itemCount in [5, 11, 17, 23, 29, 35, 41, 47, 53]:
        html.storage.add("<td>" & line & "</td></tr>")
      else:
        html.storage.add("<td>" & line & "</td>")
    else:
      for spacePer in spacePercent:
        if alertlevel.storagepercentage != 0 and
              parseInt(spacePer.substr(0,1)) > alertlevel.storagepercentage:
          if notifyOn and notify.storagepercentage: notifyStorage(line)
          if print: error(line)
          html.storageErrors = "<p class=\"error\">Usage: " & spacePer & " - Limit: " & $alertlevel.storagepercentage & "% = " & storageSeq[itemCount-4] & "</p>"
          html.storage.add("<td class=\"error\">" & line & "</td>")
        else:
          if print: success(line)
          html.storage.add("<td>" & line & "</td>")

    itemCount += 1

proc checkMemory(notifyOn = true, print = false) =
  ## Monitor storage
  if alertlevel.memoryusage == 0 and alertlevel.swapusage == 0:
    return

  html.memory = ""
  html.memoryErrors = ""
  let memTotal = memoryUsage().split("\n")
  let memTotalSeq = memoryUsageSeq()
  var itemCount = 0
  for item in memTotalSeq:
    if item.len() == 0:
      continue

    if itemCount == 0:
      html.memory.add("<tr class=\"memory\"><td></td>")

    if itemCount in [6, 13, 20, 27]:
      html.memory.add("<tr class=\"memory\"><td>" & item & "</td>")

    elif itemCount in [5, 12, 18, 25]:
      html.memory.add("<td>" & item & "</td></tr>")

    elif itemCount notin [8, 15, 22, 29]:
      html.memory.add("<td>" & item & "</td>")

    else:
      # First line usage
      var alert = 0
      if memTotalSeq[itemCount-2] == "Swap:":
        alert = alertlevel.swapusage
      else:
        alert = alertlevel.memoryusage

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
        if parseFloat(mem) > alertFloat: error = true
      elif item.contains("Mi"):
        if parseFloat(mem) > alertFloat: error = true

      if error:
        if notifyOn and notify.memoryusage: notifyMemory(memTotalSeq[itemCount-2], item, $alertFloat)
        if print: error(memTotalSeq[itemCount-2] & " Usage: " & item & " - Limit: " & $alertFloat)
        html.memoryErrors = "<p class=\"error\">Usage: " & item & " - Limit: " & $alertFloat & " = " & memTotalSeq[itemCount-2] & "</p>"
        html.memory.add("<td class=\"error\">" & item & "</td>")
      else:
        if print: success(memTotalSeq[itemCount-2] & " Usage: " & item & " - Limit: " & $alertFloat)
        html.memory.add("<td class=\"success\">" & item & "</td>")

    itemCount += 1




proc monitorUrl() {.async.} =
  ## Loop to monitor the urls
  while notify.urlresponse:
    checkUrl()
    await sleepAsync(monitorInterval.urlresponse * 1000)

proc monitorProcessState() {.async.} =
  ## Loop to monitor the processes
  while notify.processstate:
    checkProcessState()
    await sleepAsync(monitorInterval.processstate * 1000)

proc monitorProcessMem() {.async.} =
  ## Loop to monitor the processes memory usage
  while notify.processstate:
    checkProcessMem()
    await sleepAsync(monitorInterval.processmemory * 1000)

proc monitorStorage() {.async.} =
  ## Loop to monitor the storage
  while notify.storagepercentage:
    checkStorage()
    await sleepAsync(monitorInterval.storagepercentage * 1000)

proc monitorMemory() {.async.} =
  ## Loop to monitor the storage
  while notify.memoryusage:
    checkMemory()
    await sleepAsync(monitorInterval.memoryusage * 1000)


const css = """
<style>
  h3 {
    margin-bottom: 0.2rem;
  }
  hr {
    margin-top: 1rem;
  }
  table tr td {
    border-bottom: 1px solid grey;
  }
  table.noborder tr td {
    border-bottom: transparent;
  }
  .success {
    color: green;
  }
  .error {
    color: red;
  }
</style>
"""
proc genHtml(): string =
  ## Generate HTML
  checkProcessStateHtml()
  checkUrl(false)
  checkMemory(false)
  checkStorageHtml(false)
  checkProcessMem(false)

  return "<html><head>" & css & "</head><body>" &
              "<h1>" & main.identifier & "</h1> started: " & $now() &
              "<hr>" &
              "<h3>Uptime:</h3> " & uptime() &
              "<hr>" &
              "<h3>Last boot:</h3> " & lastBoot() &
              "<hr>" &
              "<h3>OS:</h3> " & os() &
              "<hr>" &
              "<h3>Process memory usage: </h3><table class=\"noborder\">" & html.processmemory & "</table>" &
              "<hr>" &
              "<h3>Process state: </h3><table class=\"noborder\">" & html.processstate & "</table>" &
              "<hr>" &
              "<h3>Memory: </h3>" & html.memoryErrors & "<table>" & html.memory & "</table>" &
              "<hr>" &
              "<h3>Space: </h3>" & html.storageErrors & "<table>" & html.storage & "</table>" &
              "<hr>" &
              "<h3>URL: </h3><table class=\"noborder\">" & html.url & "</table>" &
              "<hr>" &
              "</body></html>"

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
  infoCus("Last boot:  ", lastBoot())
  infoCus("Uptime:     ", uptime())
  infoCus("System:     ", os())
  echo "\n"
  echo "----------------------------------------"
  echo "              Memory usage"
  echo "----------------------------------------"
  checkMemory(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              Memory per process"
  echo "----------------------------------------"
  checkProcessMem(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              Process status"
  echo "----------------------------------------"
  checkProcessState()
  for pros in processes.systemctlNew:
    if pros.contains("Active: inactive (dead)"):
      error(pros.replace(re"-.*-", "-"))
    elif pros.contains("is not a service"):
      info(pros.replace(re"-.*-", "-"))
    else:
      success(pros.replace(re"-.*-", "-"))
  echo "\n"
  echo "----------------------------------------"
  echo "              Space usage"
  echo "----------------------------------------"
  if serverSpace().findAll(re"\d\d%").len() > 0:
    error("You have reached your warning storage level at " & $alertlevel.storagepercentage & "\n")
  checkStorage(false, true)
  echo "\n"
  echo "----------------------------------------"
  echo "              URL health"
  echo "----------------------------------------"
  checkUrl(false, true)
  echo "\n"





proc dailyInfo() {.async.} =
  ## Run job every day at HH:mm
  let nextRun = toTime(parse(getDateStr() & " " & timing.dailyinfo, "yyyy-MM-dd HH:mm")) + 1.days
  var waitBeforeRun = parseInt($toUnix(nextRun))
  let firstWaiting = parseInt($(waitBeforeRun - toInt(epochTime())))
  await sleepAsync(firstWaiting * 1000)

  while notify.dailyinfo:
    when defined(dev): info("dailyInfo() running")

    asyncCheck sendMail((main.identifier & ": " & $now()), genHtml())

    if timing.dailyinfoevery != 0:
      await sleepAsync(timing.dailyinfoevery * 60)
    else:
      waitBeforeRun += 86400
      await sleepAsync((waitBeforeRun - toInt(epochTime())) * 1000)



proc init() =
  loadConfig()

  if notify.boot:
    notifyOnboot()

  checkProcessState()

  if notify.urlresponse:
    asyncCheck monitorUrl()

  if notify.processstate:
    asyncCheck monitorProcessState()

  if notify.processmemory:
    asyncCheck monitorProcessMem()

  if notify.memoryusage:
    asyncCheck monitorMemory()

  if notify.storagepercentage:
    asyncCheck monitorStorage()

  if notify.dailyinfo:
    asyncCheck dailyInfo()



when isMainModule:
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
    checkProcessState()
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


settings:
  port = www.apiport

routes:
  get "/@api":
    cond(@"api" == www.apikey)
    resp(genHtml())

  get "/cluster":
    cond(@"api" == www.apikey)
    var client = newHttpClient()
    var clustHtml = ""
    for cluster in www.apicluster:
      clustHtml.add(getContent("http://127.0.0.1:8334/123456"))

    resp (genHtml() & clustHtml)