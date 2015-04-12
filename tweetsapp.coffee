tweetUrl = "https://twitter.com/naval/status/456255410136027136"
tweetFormat = "#stream-items-id > li:nth-child(n) > div > div > p"
hockeyUrl = "http://www.hockey-reference.com/players/s/shacked01.html"
hockeyFormat = "#stats_basic_nhl > thead > tr:nth-child(2)"

Results = new Mongo.Collection ('results')

if Meteor.isClient
  Meteor.subscribe 'results'
  Template.tweets.events
    "click #reset": () ->  Meteor.call "resetAll"
      
    "click #bt_header": (event) ->
      Meteor.call "chScrape"
        , tb_url.value
        , tb_header.value
      false

    "click #bt_data": (event) ->
      Meteor.call "jqScrape"
        , tb_url.value
        , tb_data.value
      false

    "click #bt_table": (event) ->
      Meteor.call "xrayScrape"
        , tb_url.value
        , tb_table_root.value
        , tb_table_header.value
        , tb_table_data.value
      false
      
  Template.navbar.helpers
    arr3: -> [1..3]
  Template.tweets.helpers
    results: -> Results.find()
    headerDefaultFormat: "#stats_basic_nhl > thead > tr:nth-child(2)"
    dataDefaultFormat: "#stats_basic_nhl > tbody > tr"

savetoDB = (label, scraperes) ->
  console.log "savetoDB", label, scraperes
  query = label: label
  recs = (Results.find query)
  if recs.count() is 0
    console.log "chresult empty, create new record", recs.count()
    Results.insert
      label: label
      text: scraperes.join(" ")
      count: scraperes.length
  else
    console.log label, recs.count(), " record found. updating"
    recs.map (doc, i, c) ->
      Results.update doc._id, $set:
        text: scraperes.join(" ")
        count: scraperes.length

if Meteor.isServer
  Meteor.publish 'results', -> Results.find()

  Meteor.methods
    resetAll: () ->
      console.log "resetAll"
      recs = Results.find()
      recs.map (doc, i, c) ->
        Results.update doc._id, $set:
          text: ""
          count: 0
      
    ###  scrape using cheerio.js ###
    chScrape: (url, format) -> 
      console.log "chScrape", url, format
      html = Meteor.http.get url

      $ = Meteor.npmRequire("cheerio").load html.content
      chResults = $(format).map (i, elem) ->
          elemtext = $(elem).text().replace(/(\r\n|\n|\r)/g,"")
          console.log "chResults: ", elemtext
          elemtext
        .get()
      savetoDB "chResults", chResults

    ###  scrape using jsdom/jquery ###
    jqScrape: (url,format) ->
      html = Meteor.http.get url
      
      # http://stackoverflow.com/questions/21358015/error-jquery-requires-a-window-with-a-document
      jq = Meteor.npmRequire("jquery")(Meteor.npmRequire("jsdom").jsdom().parentWindow)
      jqDoc = jq html.content

      # http://stackoverflow.com/questions/23866237/jquery-cheerio-going-over-an-array-of-elements
      jqResults = jqDoc.find(format).map (i, elem) ->
          elemtext = jq(elem).text().replace(/(\r\n|\n|\r)/g,"")
          console.log "jqResults: ", elemtext
          elemtext
        .get()
      savetoDB "jqResults", jqResults
      
    ###  scrape using x-ray.js ###
    xrayScrape: (url, root, header, data) -> 
#      check coffeescript self-initiating functions
      future = new (Npm.require 'fibers/future')()
      xray url
        .select([{
          $root: [root],
          headers: [header]
          data: [data]
          }])
        .run (err,rowarr)->
          rowtextarr = for row in rowarr
            rowtext = ([row.headers..., row.data...]).join(" ") 
            console.log "xrayResults", rowtext
            rowtext
          future.return rowtextarr
      xrayResults = do future.wait
      savetoDB "xrayResults", xrayResults
    #    .write(process.stdout)