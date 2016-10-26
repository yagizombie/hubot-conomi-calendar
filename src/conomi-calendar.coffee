# Description
#   スケジュールの調整を行ったり、カレンダーを登録してくれる
#
# Configuration:
#   CONOMI_CALENDAR_ID
#   CONOMI_CALENDAR_SECRET
#
# Commands:
#   hubot 予定 - 本日の予定
#   hubot <YYYY-MM-DD>の予定 - YYYY-MM-DDの予定
#   hubot <xxx@brainpad.co.jp>の予定 - 本日の予定
#   hubot <xxx>の予定 - 本日の予定
#
# Author:
#    yagizombie <yanagihara+zombie@brainpad.co.jp>

moment = require('moment')
moment.locale('ja')
fs = require('fs')
readline = require('readline')
google = require('googleapis')
googleAuth = require('google-auth-library')
calendar = google.calendar('v3')

SCOPES = [ 'https://www.googleapis.com/auth/calendar' ]
TOKEN_DIR = (process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE) + '/.credentials/'
TOKEN_PATH = TOKEN_DIR + 'calendar-api-quickstart.json'

authorize = (callback, msg, calendarId, m) ->
    clientSecret = process.env.CONOMI_CALENDAR_SECRET
    clientId = process.env.CONOMI_CALENDAR_ID
    redirectUrl = "urn:ietf:wg:oauth:2.0:oob"
    auth = new googleAuth
    oauth2Client = new (auth.OAuth2)(clientId, clientSecret, redirectUrl)
    # Check if we have previously stored a token.
    fs.readFile TOKEN_PATH, (err, token) ->
        if err
            getNewToken oauth2Client, callback, msg, calendarId, m
        else
            oauth2Client.credentials = JSON.parse(token)
            callback oauth2Client, msg, calendarId, m
        return
    return

getNewToken = (oauth2Client, callback, msg, calendarId, m) ->
    authUrl = oauth2Client.generateAuthUrl(
        access_type: 'offline'
        scope: SCOPES)
    console.log 'Authorize this app by visiting this url: ', authUrl
    rl = readline.createInterface(
        input: process.stdin
        output: process.stdout)
    rl.question 'Enter the code from that page here: ', (code) ->
        rl.close()
        oauth2Client.getToken code, (err, token) ->
            if err
                console.log 'Error while trying to retrieve access token', err
                return
            oauth2Client.credentials = token
            storeToken token
            callback oauth2Client, msg, calendarId, m
            return
        return
    return

storeToken = (token) ->
    try
        fs.mkdirSync TOKEN_DIR
    catch err
        if err.code != 'EEXIST'
            throw err
    fs.writeFile TOKEN_PATH, JSON.stringify(token)
    console.log 'Token stored to ' + TOKEN_PATH
    return

getEvents = (auth, msg, calendarId, m) ->
    calendar.events.list {
        auth: auth
        calendarId: calendarId
        timeMin: m.startOf('day').toDate().toISOString()
        timeMax: m.endOf('day').toDate().toISOString()
        maxResults: 20
        singleEvents: true
        orderBy: 'startTime'
    }, (err, response) ->
        dstr = ""
        if moment().format("YYYY-MM-DD") == m.format("YYYY-MM-DD")
            dstr = "今日"
        else if moment().add("days",1).format("YYYY-MM-DD") == m.format("YYYY-MM-DD")
            dstr = "明日"
        else if moment().add("days",2).format("YYYY-MM-DD") == m.format("YYYY-MM-DD")
            dstr = "明後日"
        if err
            console.log "ERROR(calendar event): " + err
            msg.send 'うわぁ～～～～～っ!?誰?'
            return
        msg.send "#{dstr} #{m.format("YYYY-MM-DD")} の予定 -- #{calendarId}"
        events = response.items
        if events.length == 0
            # console.log 'No upcoming events found.'
            msg.send "予定が入っていないなんて、サミシイやつだなぁ... (fu)"
        else
            # console.log 'Upcoming 10 events:'
            i = 0
            message = "/quote ∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴ \n"
            while i < events.length
                event = events[i]
                start = event.start.dateTime or event.start.date
                end = event.start.dateTime or event.start.date

                # setting time?
                if start.indexOf("T") >= 0
                    start = start.split("T")[1][0..4]
                    message = "#{message}#{start}  #{event.summary}\n"
                else
                    message = "#{message}#{event.summary}\n"

                i++
            # console.log "#{message}があります。"
            msg.send "#{message}"
            msg.send "だよ。 @#{msg.message.user.mention_name}"

module.exports = (robot) ->
    robot.respond /予定/i, (msg) ->
        calendarId = msg.message.user.email_address
        authorize getEvents, msg, calendarId, moment()

    robot.respond /([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*)の予定/i, (msg) ->
        calendarId = msg.match[1]
        authorize getEvents, msg, calendarId, moment()

    robot.respond /([0-9]{4}-[0-9]{2}-[0-9]{2})の([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*)の予定/i, (msg) ->
        calendarId = msg.match[2]
        authorize getEvents, msg, calendarId, moment(msg.match[1])

    robot.respond /([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)の予定/i, (msg) ->
        if /[0-9]{4}-[0-9]{2}-[0-9]{2}/i.test(msg.match[1])
            calendarId = msg.message.user.email_address
            authorize getEvents, msg, calendarId, moment(msg.match[1])
        else
            calendarId = msg.match[1] + "@brainpad.co.jp"
            authorize getEvents, msg, calendarId, moment()

    robot.respond /([0-9]{4}-[0-9]{2}-[0-9]{2})の([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)の予定/i, (msg) ->
        calendarId = msg.match[2] + "@brainpad.co.jp"
        authorize getEvents, msg, calendarId, moment(msg.match[1])
