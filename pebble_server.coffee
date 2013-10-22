my_request = require 'request'
fs = require 'fs'
path = require 'path'
jade = require 'jade'
mime = require 'mime'
seq = require 'seq'

server = (request, response) ->
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
      seq()
        .par( 'weather', ->
          url = "http://api.forecast.io/forecast/#{api_key}/#{latitude},#{longitude}?units=#{units}&exclude=hourly,daily,alerts"
          my_request url, this 
          )
        .par( 'location', ->
          url = "http://maps.googleapis.com/maps/api/geocode/json?latlng=#{latitude},#{longitude}&sensor=true"
          my_request url, this          )
        .seq( (weather, location)->
          weather = JSON.parse this.vars['weather'].body
          location = JSON.parse this.vars['location'].body
          forecast.icon = weather.currently.icon
          forecast.font = icons[forecast.icon].font
          forecast.temperature = Math.round weather.currently.temperature 
          forecast.humidity = Math.round weather.currently.humidity*100
          forecast.clouds = Math.round weather.currently.cloudCover*100
          forecast.rain = (weather.currently.precipIntensity*2.54).toFixed(2)
          forecast.rain_prob = Math.round weather.currently.precipProbability*100
          forecast.wind = Math.round weather.currently.windSpeed*1.609344
          forecast.wind_dir = Math.round weather.currently.windBearing
          for component in location.results[0].address_components
                #console.log component
            if 'street_number' in component.types
              forecast.number = parseInt component.long_name
            if 'route' in component.types
              forecast.street = component.long_name.stripAccents()
              forecast.street = forecast.street                  
            if 'locality' in component.types
              forecast.city = component.long_name.stripAccents()
          response.writeHeader 200,
            'Content-Type': 'application/json'
          content = 
            "1": ['B', icons[forecast.icon].icon]
            "2": forecast.temperature + "° " + forecast.humidity + "%"
            "6": forecast.city
            "5": ''
          ln = 124 - (49 + 7*Object.keys(content).length + 1 + content["2"].length + content["6"].length)
          if forecast.number
            ln = ln - (forecast.number.toString().length + 2) 
          content["5"] = tidyString(forecast.street, ln) + [(", " + forecast.number) if forecast.number]
          response.write JSON.stringify content              
          response.end()
          socketio.sockets.emit 'update', 
            time: pad2 date.getHours() + ":" + pad2 date.getMinutes() + ":" + pad2 date.getSeconds()
            data: forecast
          console.log "Enviado respuesta --->"
          console.log "    Temp: #{forecast.temperature} - Hum: #{forecast.humidity} - #{forecast.icon}"
          console.log "    Lugar: #{forecast.street}, #{forecast.number} - #{forecast.city}"
        )

app = require('http').createServer(server)
app.listen 3000

socketio = require('socket.io').listen(app)

console.log "##############################################################"
console.log "################### Server Running on 3000 ###################"
console.log "##############################################################"

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

IsJson = (str) ->
  try
    JSON.parse str
  catch e
    return false
  true
  
tidyString = (str, ln) ->
  str = str.replace /Calle de los /, "C. "
  str = str.replace /Calle de las /, "C. "
  str = str.replace /Calle de la /, "C. "
  str = str.replace /Calle del /, "C. "
  str = str.replace /Calle de /, "C. "
  str = str.replace /Calle /, "C. "
  str = str.replace /Avenida de los /, "Av. "
  str = str.replace /Avenida de las /, "Av. "
  str = str.replace /Avenida de la /, "Av. "
  str = str.replace /Avenida del /, "Av. "
  str = str.replace /Avenida de /, "Av. "
  str = str.replace /Avenida/, "Av. "
  str = str.replace /Paseo de los /, "P. "
  str = str.replace /Paseo de las /, "P. "
  str = str.replace /Paseo de la /, "P. "
  str = str.replace /Paseo del /, "P. "
  str = str.replace /Paseo de /, "P. "
  str = str.replace /Paseo /, "P. "
  str = str.replace /Plaza de los /, "Pz. "
  str = str.replace /Plaza de las /, "Pz. "
  str = str.replace /Plaza de la /, "Pz. "
  str = str.replace /Plaza del /, "Pz. "
  str = str.replace /Plaza de /, "Pz. "
  str = str.replace /Plaza /, "Pz. "
  str = str.truncate ln