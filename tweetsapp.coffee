tweetUrl = "https://twitter.com/naval/status/456255410136027136"
tweetFormat = "#stream-items-id > li:nth-child(n) > div > div > p"
hockeyUrl = "http://www.hockey-reference.com/players/s/shacked01.html"
hockeyFormat = "#stats_basic_nhl > thead > tr:nth-child(2)"

if Meteor.isClient
  Template.tweets.events
    "submit #infoHeader": (event) ->
      Meteor.call "getData"
        , event.target.headerUrl.value
        , event.target.headerFormat.value
        , (error, result) ->
          console.log "click ", result
          Session.set "header", result
      false

    "submit #infoData": (event) ->
      Meteor.call "getData"
        , event.target.dataUrl.value
        , event.target.dataFormat.value
        , (error, result) ->
          console.log "click ", result
          Session.set "data", result
      false
  Template.navbar.helpers
    arr3: -> [1..3]
  Template.tweets.helpers
    scrapedHeaderCount: -> (Session.get "header").length
    scrapedHeader:      -> (Session.get "header").join(" ")
    scrapedDataCount:   -> (Session.get "data").length
    scrapedData:        -> (Session.get "data").join(" ")

if Meteor.isServer
  Meteor.startup ->
    Meteor.call "getData"
      , hockeyUrl
      , hockeyFormat
      , (error, result) ->

  Meteor.methods
    getData: (url, format) ->
      cheerio = Meteor.npmRequire("cheerio")
      rawpage = Meteor.http.get(url)
      $ = cheerio.load rawpage.content

      storevar =[]
      $(format).each (i, elem) ->
          storevar[i] = $(elem).text().replace(/(\r\n|\n|\r)/g," ")
          console.log storevar[i]
      storevar
