var tweetUrl = "https://twitter.com/naval/status/456255410136027136"
var tweetFormat = "#stream-items-id > li:nth-child(n) > div > div > p"
hockeyUrl = "http://www.hockey-reference.com/players/s/shacked01.html";
var hockeyFormat = '#stats_basic_nhl > thead';

if (Meteor.isClient) {
  Template.tweets.events({
    "submit #infoHeader": function(event) {
      Meteor.call('getData'
        , event.target.url.value
        , event.target.format.value
        , function(error, result) {
            console.log("click ", result);
            Session.set("header", result)
            }
      );
      return false
    },
    
    "submit #infoData": function(event) {
      Meteor.call('getData'
        , event.target.url.value
        , event.target.format.value
        , function(error, result) {
            console.log("click ", result);
            Session.set("data", result)
            }
      );
      return false
    }

  });

  Template.tweets.helpers({
    scrapedHeader: function() {
      return Session.get("header");
    },
    scrapedData: function() {
      return Session.get("data");
    }
  });
};


if (Meteor.isServer) {
  Meteor.startup(function () {
    Meteor.call('getData', hockeyUrl, hockeyFormat
      , function(error, result) {
        });
  });
  
  Meteor.methods({
      getData: function (url, format){
        var cheerio = Meteor.npmRequire('cheerio');
        rawpage = Meteor.http.get(url);
        $ = cheerio.load(rawpage.content);
        var header = $(format) // .find('th').slice(10).text();
//        console.log(header.toString() );
          
//          for (x in header){
//            console.log(x);
//          };

          console.log(header.length);
          console.log(header.children().text());
          var resp = $(format).text();
        return resp;
      }
    });
};

