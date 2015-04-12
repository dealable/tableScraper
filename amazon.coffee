Products = new Mongo.Collection 'products'
@amzn =
  url: "http://www.amazon.com/Apple-iPhone-Gold-16-GB/dp/B00NQGP3SO"
  root: "#a-page"
  img_src: "#landingImage[data-a-dynamic-image]"
  dataroot: "#productDetailsTable .content ul"
  sel_name: "#productTitle"
  sel_header: "li b"
  sel_data: "li"

amzn_urls = [
  "http://www.amazon.com/Apple-iPhone-Gold-16-GB/dp/B00NQGP3SO"
  "http://www.amazon.com/BLU-Advance-Unlocked-Phone-White/dp/B00HPTMCRI"
  "http://www.amazon.com/BLU-Advance-Unlocked-Phone-Black/dp/B00GXHPN1U"
  "http://www.amazon.com/Samsung-GT-i8200-Factory-Unlocked-International/dp/B00INEIZN4"
  "http://www.amazon.com/Samsung-GT-I8200-Unlocked-Android-Smartphone/dp/B00SX86GYU"
  "http://www.amazon.com/Amazon-Fire-Phone-32GB-Unlocked/dp/B00OC0USA6"
  "http://www.amazon.com/LG-Realm-Black-Boost-Mobile/dp/B00N15E6TW"
  "http://www.amazon.com/Motorola-Moto-2nd-generation-Unlocked/dp/B00MWI4HW0"
  "http://www.amazon.com/AT-Nokia-Lumia-635-Contract/dp/B00LBFFSNM"
  "http://www.amazon.com/Apple-iPhone-16GB-White-Unlocked/dp/B0097CZJEO"
  "http://www.amazon.com/Samsung-GT-i8200-Factory-Unlocked-International/dp/B00IVI3LWM"
]

TabularTables = {}
Meteor.isClient and Template.registerHelper("TabularTables", TabularTables)
TabularTables.Products = new Tabular.Table(
  name: "AmazonProducts"
  collection: Products
  columns: [
    data: "amzn_name"
    title: "Name"
  ,
    data: "amzn_asin"
    title: "ASIN"
  ,
    data: "amzn_model_num"
    title: "Model Number"
  ,
    data: "amzn_weight"
    title: "Weight"
  ,
    data: "amzn_size"
    title: "Size"
  ,
#    data: "lastCheckedOut"
#    title: "Last Checkout"
#    render: (val, type, doc) ->
#      if val instanceof Date
#        moment(val).calendar()
#      else
#        "Never"
#  ,
    data: "amzn_seller_rank"
    title: "Seller Rank"
  ,
    tmpl: Meteor.isClient and Template.amazonProducts
    data: "amzn_img_src"
   ]
)

if Meteor.isClient
  Meteor.subscribe "products"

  Template.amazon.helpers
    sample_url_values: amzn_urls
#    nameCount: -> (Session.get "amzn").name.length
#    name:      -> (Session.get "amzn").name # join(" ")
#    img_src: -> (Session.get "amzn").img_src # join(" ")
#    detailsCount:   -> (Session.get "amzn").info.details.length
#    header: -> 
#      details = (Session.get "amzn").info.details
#      for detail in details
#        detail.field
#    data: -> 
#      details = (Session.get "amzn").info.details
#      for detail in details
#        detail.data

  Template.amazon.events
    "change #sample_urls": (item) -> tb_amzn.value = item.target.value
    "click #amzn_reset": () ->  Meteor.call "amzn_resetAll"
    
    "click #bt_amazon": (event) ->
      templ =
        url: tb_amzn.value
        root: tb_amzn_root.value
        name: tb_amzn_name.value
        img_src: tb_amzn_imgsrc.value
        dataroot: tb_amzn_dataroot.value
        header: tb_amzn_header.value
        data: tb_amzn_data.value

      Meteor.call "amazonScrape", templ
      false

#  Template.amazonProducts.helpers
#    amzn_img_src: @amzn_img_src
#    'click .edit_product': -> addBookToCheckoutCart @_id

if Meteor.isServer
  Meteor.publish 'products'
  ###  scrape using x-ray.js ###
  Meteor.methods
    amzn_resetAll: () ->
      console.log "Reset Product DB"
      res = Products.remove({})
      console.log res

    amazonScrape: (templ) -> 
      future = new (Npm.require 'fibers/future')()
      labelToKey = (str) -> switch str
        when "Product Dimensions" then "amzn_size"
        when "Shipping Weight" then "amzn_weight"
        when "ASIN" then "amzn_asin"
        when "Item model number" then "amzn_model_num"
        when "Unlocked Cell Phones" then "amzn_seller_rank"
        else str

      mkObj = (err,product)->
        for detail in product.info.details # remove useless data
          header = detail.field
          if header in ["Amazon Best Sellers Rank:", "Average Customer Review:"]
            detail.data = ""
          else
            detail.data = detail.data.replace(header,"").trim()
          detail
          detail.field = labelToKey header.replace(":","")

        # reduce details array and merge with original object
        res = {}
        for key, value of product
          if key is 'info'
            data = value.details
            #console.log "before1", data
            data.reduce(
                (obj,item) ->
                  val = item.data
                  if val isnt '' then obj[item.field] = val
                  obj
                res
              )
          else res[key] = value
        console.log "after", res
        future.return res
  
      saveToDB = (res) ->
        # add to Products collection
        query = amzn_asin: res.amzn_asin
        console.log "query", query
        recs = (Products.find query)
        if recs.count() is 0
          console.log "create new ASIN"
          Products.insert res
        else
          console.log label, recs.count(), "ASIN exists. updating"
          recs.map (doc, i, c) ->
            Products.update doc._id, $set: res

      # define helper function to manipulate string within xray
      rmNewLines = (str) -> str.replace(/(\r\n|\n|\r)/g,"").trim()
      getURL = (str) ->
        patt = /\"([\w\n\:\/_\-\.]+)\"/g
        arr = while match = patt.exec(str)
          match[1]
        arr[0]

      # xray call
      xray templ.url 
        .prepare('rmNewLines', rmNewLines)
        .prepare('getURL', getURL)
        .select({
          amzn_name: templ.name,
          amzn_img_src: templ.img_src + " | getURL",
          # add S3 to project before save images
          #        img: templ.imgsrc,
          info: {
            $root: templ.dataroot,
            details: [{
              field: templ.header + " | rmNewLines"
              data: templ.data + " | rmNewLines"
            }]
          }})
        .run mkObj
        res = do future.wait
        saveToDB res