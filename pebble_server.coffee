my_request = require "request"
my_http = require "http"
fs = require "fs"
path = require "path"
jade = require "jade"
mime = require 'mime'


icons =
  'clear-day' :  
    'icon': 0
    'font': 'B'
  'clear-night' :      
    'icon': 1
    'font': 'C'
  'rain' :        
    'icon': 2
    'font': 'R'
  'snow' :        
    'icon': 3
    'font': 'W'
  'sleet' :        
    'icon': 4
    'font': 'X'
  'wind' :        
    'icon': 5
    'font': 'F'
  'fog' :        
    'icon': 6
    'font': 'M'
  'cloudy' :        
    'icon': 7
    'font': 'N'
  'partly-cloudy-day' :        
    'icon': 8
    'font': 'H'
  'partly-cloudy-night' :        
    'icon': 9
    'font': 'I'
  'no-weather' :       
    'icon': 10
    'font': ')'
  
forecast =
  'icon': 0
  'font': ')'
  'temperature': 0
  'humidity': 0
  'clouds': 0
  'rain_prob': 0
  'rain': 0
  'wind': 0
  'wind_dir': 0
  'number': 0
  'street': ''
  'city': ''
  'latitude': 0
  'longitude': 0
  'time': 0
  
String::stripAccents = ->
  translate_re = /[àáâãäçèéêëìíîïñòóôõöùúûüýÿÀÁÂÃÄÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝ]/g
  translate = "aaaaaceeeeiiiinooooouuuuyyAAAAACEEEEIIIINOOOOOUUUUY"
  @replace translate_re, (match) ->
    translate.substr translate_re.source.indexOf(match) - 1, 1
    
pad2 = (number) ->
  ((if number < 10 then "0" else "")) + number
  
String::truncate = (n) ->
  @substr(0, n - 1)

my_http.createServer((request, response) ->
  api_key = "cadac7d880dc4faa96e18a35a96846ec"
  if request.method == 'GET'
    current_time = new Date()
    filePath = request.url
    if filePath is "/"
      fs.readFile 'jade/pebble_server.jade', 'utf8', (err, data) ->
        if err 
          throw err
        fn = jade.compile data,
          'pretty': true
        html = fn 
          time: current_time.getHours() + ":" + current_time.getMinutes() + ":" + current_time.getSeconds()
          data: forecast
        response.setHeader 'Content-Type', 'text/html'
        response.writeHead 200
        response.end html
        
    else
      content_type = mime.lookup filePath
      fs.readFile __dirname + filePath, (err, data) ->
        response.setHeader 'Content-Type', content_type
        response.writeHead 200
        response.end data
      
  if request.method == 'POST'
    request.on "data", (data)->
      params = JSON.parse data.toString('utf-8')
      latitude = params["1"]/10000
      longitude = params["2"]/10000
      forecast.latitude = latitude
      forecast.longitude = longitude
      units = params["3"]
      date = new Date()
      forecast.time = pad2(date.getHours()) + ":" + pad2(date.getMinutes()) + ":" + pad2(date.getSeconds())
      console.log "--------- #{date} ---------"
      console.log "Lat: #{latitude} - Long: #{longitude} - Units: #{units}"
      url = "http://api.forecast.io/forecast/#{api_key}/#{latitude},#{longitude}?units=#{units}&exclude=hourly,daily,alerts"
      my_request url, (error, res, body) ->
        if error
          console.log "Error con url #{url}: #{res}"
        else
          if IsJson body
            data = JSON.parse body
            forecast.icon = data.currently.icon
            forecast.font = icons[forecast.icon].font
            forecast.temperature = Math.round data.currently.temperature 
            forecast.humidity = Math.round data.currently.humidity*100
            forecast.clouds = Math.round data.currently.cloudCover*100
            forecast.rain = (data.currently.precipIntensity*2.54).toFixed(2)
            forecast.rain_prob = Math.round data.currently.precipProbability*100
            forecast.wind = Math.round data.currently.windSpeed*1.609344
            forecast.wind_dir = Math.round data.currently.windBearing
          else
            forecast.icon = icons['no-weather'].icon
            forecast.font = icons['no-weather'].font
            forecast.temperature = -1 
            forecast.humidity = -1
        url = "http://maps.googleapis.com/maps/api/geocode/json?latlng=#{latitude},#{longitude}&sensor=true"
        my_request url, (error, res, body) ->
          if error
            console.log "Error con url #{url}: #{res}"
          else
            if IsJson body
              place = JSON.parse body
              forecast.number = 0
              forecast.street = "Sin localizar"
              forecast.city = "Sin localizar"
              for component in place.results[0].address_components
                #console.log component
                if 'street_number' in component.types
                  forecast.number = parseInt component.long_name
                if 'route' in component.types
                  forecast.street = component.long_name.stripAccents()
                  forecast.street = tidyString forecast.street
                
                if 'locality' in component.types
                  forecast.city = component.long_name.stripAccents()
              #forecast.number = parseInt place.results[0].address_components[0].long_name
              #forecast.street = place.results[0].address_components[1].long_name.stripAccents()
            response.writeHeader 200,
              'Content-Type': 'application/json'
            response.write JSON.stringify 
              #"1": ['B', icons[forecast.icon].icon]
              #"2": ['b', forecast.temperature]
              #"3": ['B', forecast.humidity]
              #"4": ['B', forecast.number]
              #"5": forecast.street
              #"6": forecast.city
              "1": ['B', icons[forecast.icon].icon]
              "2": forecast.temperature + "° " + forecast.humidity + "%"
              "5": forecast.street + ", " + forecast.number
              "6": forecast.city
            response.end()
            console.log "Enviado respuesta --->"
            console.log "    Temp: #{forecast.temperature} - Hum: #{forecast.humidity} - #{forecast.icon}"
            console.log "    Lugar: #{forecast.street}, #{forecast.number} - #{forecast.city}"
).listen 3000
console.log "##############################################################"
console.log "################### Server Running on 3000 ###################"
console.log "##############################################################"


IsJson = (str) ->
  try
    JSON.parse str
  catch e
    return false
  true
  
tidyString = (str) ->
  str = str.replace /Calle de la /, ""
  str = str.replace /Calle del /, ""
  str = str.replace /Calle de /, ""
  str = str.replace /Calle /, ""
  str = str.replace /Avenida de la /, ""
  str = str.replace /Avenida del /, ""
  str = str.replace /Avenida de /, ""
  str = str.replace /Avenida/, ""
  str = str.replace /Paseo de la /, ""
  str = str.replace /Paseo del /, ""
  str = str.replace /Paseo de /, ""
  str = str.replace /Paseo /, ""
  str = str.truncate 20
  

  

