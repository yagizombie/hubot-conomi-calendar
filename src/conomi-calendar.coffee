# Description
#   スケジュールの調整を行ったり、カレンダーを登録してくれる
#
# Configuration:
#   CONOMI_CALENDAR_ID
#   CONOMI_CALENDAR_SECRET
#
# Commands:
#   hubot 予定 - 本日の予定
#   hubot <xxx@brainpad.co.jp>の予定 - 本日の予定
#   hubot <xxx>の予定 - 本日の予定
#
# Author:
#    yagizombie <yanagihara+zombie@brainpad.co.jp>

moment = require('moment')
fs = require('fs')
readline = require('readline')
google = require('googleapis')
googleAuth = require('google-auth-library')
calendar = google.calendar('v3')

SCOPES = [ 'https://www.googleapis.com/auth/calendar' ]
TOKEN_DIR = (process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE) + '/.credentials/'
TOKEN_PATH = TOKEN_DIR + 'calendar-api-quickstart.json'

authorize = (callback, msg, calendarId) ->
    clientSecret = process.env.CONOMI_CALENDAR_SECRET
    clientId = process.env.CONOMI_CALENDAR_ID
    redirectUrl = "urn:ietf:wg:oauth:2.0:oob"
    auth = new googleAuth
    oauth2Client = new (auth.OAuth2)(clientId, clientSecret, redirectUrl)
    # Check if we have previously stored a token.
    fs.readFile TOKEN_PATH, (err, token) ->
        if err
            getNewToken oauth2Client, callback, msg, calendarId
        else
            oauth2Client.credentials = JSON.parse(token)
            callback oauth2Client, msg, calendarId
        return
    return

getNewToken = (oauth2Client, callback, msg, calendarId) ->
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
            callback oauth2Client, msg, calendarId
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

getEvents = (auth, msg, calendarId) ->
    moment.locale('ja')
    calendar.events.list {
        auth: auth
        calendarId: calendarId
        timeMin: moment().startOf('day').toDate().toISOString()
        timeMax: moment().endOf('day').toDate().toISOString()
        maxResults: 20
        singleEvents: true
        orderBy: 'startTime'
    }, (err, response) ->
        msg.send "今日(#{moment().format("YYYY-MM-DD")})の予定は!! (sap)"
        if err
            console.log "ERROR(calendar event): " + err
            msg.send 'うわぁ～～～～～っ!?誰?'
            return
        events = response.items
        if events.length == 0
            # console.log 'No upcoming events found.'
            msg.send "予定が入っていないなんて、サミシイやつだなぁ... (fu)"
        else
            # console.log 'Upcoming 10 events:'
            i = 0
            message = "/quote ∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴‥∵‥∴‥∴‥∵‥∴\n"
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
    robot.respond /(予定)/i, (msg) ->
        calendarId = msg.message.user.email_address
        authorize getEvents, msg, calendarId

    robot.respond /([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*)の(予定)/i, (msg) ->
        calendarId = msg.match[1]
        authorize getEvents, msg, calendarId

    robot.respond /([a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+)の(予定)/i, (msg) ->
        calendarId = msg.match[1] + "@brainpad.co.jp"
        authorize getEvents, msg, calendarId
