# Copyright 2018 - Thomas T. Jarløv

import asyncdispatch, smtp, strutils, os, asyncnet
import logging

type
  SMTPDetails* = ref object
    address*: string
    port*: string
    fromMail*: string
    user*: string
    password*: string
    toMail*: seq[string]

var smtpDetails*: SMTPDetails
new(smtpDetails)

smtpDetails.address = ""

proc sendMail*(subject, message: string) {.async.} =
  ## Send the email through smtp

  when defined(noemail):
    info("Email disabled - skipped mail")

  if smtpDetails.address.len() == 0:
    error("No SMTP address has been specified. Email was not send.")
    return

  const otherHeaders = @[("Content-Type", "text/html; charset=\"UTF-8\"")]

  var client = newAsyncSmtp(useSsl = true)
  await client.connect(smtpDetails.address, Port(parseInt(smtpDetails.port)))
  await client.auth(smtpDetails.user, smtpDetails.password)

  let toList = smtpDetails.toMail

  var headers = otherHeaders
  headers.add(("From", smtpDetails.fromMail))

  let encoded = createMessage(subject, message, toList, @[], headers)

  try:
    when defined(dev): info("sendMail() running")
    await client.sendMail(smtpDetails.fromMail, toList, $encoded)

  except:
    error("Error in sending mail")