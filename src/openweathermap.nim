## Nim-OpenWeatherMap
## ==================
##
## OpenWeatherMap API Lib for Nim, Free world wide Creative Commons & Open Data Licensed Weather data & maps.
##
## - Check the OpenWeatherMap Docs, the Lib is a 1:1 copy of the official Docs.
## - Each proc links to the official OWM API docs.
## - All procs should return an JSON Object JsonNode.
## - The naming of the procs follows the naming on the OWM Wiki.
## - The errors on the procs follows the errors on the OWM Wiki.
## - API Calls that use HTTP GET start with get_*.
## - API Calls that use HTTP POST start with post_*.
## - API Calls that use HTTP PUT start with put_*.
## - API Calls that use HTTP DELETE start with delete_*.
## - API Calls use the DoNotTrack HTTP Header.
## - The timeout argument is on Seconds.
## - For Proxy support define a OWM.proxy or AsyncOWM.proxy of Proxy type.
## - No OS-specific code, so it should work on Linux, Windows and Mac. Not JS.
## - Run the module itself for an Example.

import asyncdispatch, httpclient, strformat, strutils, xmldomparser, xmldom, json, tables

const
  owm_api_url* = "https://api.openweathermap.org/data/2.5/"     ## OpenWeatherMap HTTPS API URL for Weather.
  owm_api_air* = "https://api.openweathermap.org/pollution/v1/" ## OpenWeatherMap HTTPS API URL for Air Pollution.
  owm_api_map* = "https://tile.openweathermap.org/map/"         ## OpenWeatherMap HTTPS API URL for Maps.
  owm_ok_lang* = [
    "ar", "bg", "ca", "cz", "de", "el", "en", "fa", "fi", "fr", "gl", "hr", "hu",
    "it", "ja", "kr", "la", "lt", "mk", "nl", "pl", "pt", "ro", "ru", "se", "sk",
    "sl", "es", "tr", "ua", "vi", "zh_cn", "zh_tw"
  ]  ## Array of strings of OpenWeatherMap supported languages ISO Codes.
  owm_code2icon* = {
    "01d": "https://openweathermap.org/img/w/01d.png", "01n": "https://openweathermap.org/img/w/01n.png",
    "02d": "https://openweathermap.org/img/w/02d.png", "02n": "https://openweathermap.org/img/w/02n.png",
    "03d": "https://openweathermap.org/img/w/03d.png", "03n": "https://openweathermap.org/img/w/03n.png",
    "04d": "https://openweathermap.org/img/w/04d.png", "04n": "https://openweathermap.org/img/w/04n.png",
    "09d": "https://openweathermap.org/img/w/09d.png", "09n": "https://openweathermap.org/img/w/09n.png",
    "10d": "https://openweathermap.org/img/w/10d.png", "10n": "https://openweathermap.org/img/w/10n.png",
    "11d": "https://openweathermap.org/img/w/11d.png", "11n": "https://openweathermap.org/img/w/11n.png",
    "13d": "https://openweathermap.org/img/w/13d.png", "13n": "https://openweathermap.org/img/w/13n.png",
    "50d": "https://openweathermap.org/img/w/50d.png", "50n": "https://openweathermap.org/img/w/50n.png",
  }.to_table ## Static Table containing Code-to-Icon URLs, icons are all PNG with transparency.
  owm_code2description* = {
    "200": "thunderstorm with light rain",
    "201": "thunderstorm with rain",
    "202": "thunderstorm with heavy rain",
    "210": "light thunderstorm",
    "211": "thunderstorm",
    "212": "heavy thunderstorm",
    "221": "ragged thunderstorm",
    "230": "thunderstorm with light drizzle",
    "231": "thunderstorm with drizzle",
    "232": "thunderstorm with heavy drizzle",
    "300": "light intensity drizzle",
    "301": "drizzle",
    "302": "heavy intensity drizzle",
    "310": "light intensity drizzle rain",
    "311": "drizzle rain",
    "312": "heavy intensity drizzle rain",
    "313": "shower rain and drizzle",
    "314": "heavy shower rain and drizzle",
    "321": "shower drizzle",
    "500": "light rain",
    "501": "moderate rain",
    "502": "heavy intensity rain",
    "503": "very heavy rain",
    "504": "extreme rain",
    "511": "freezing rain",
    "520": "light intensity shower rain",
    "521": "shower rain",
    "522": "heavy intensity shower rain",
    "531": "ragged shower rain",
    "600": "light snow",
    "601": "snow",
    "602": "heavy snow",
    "611": "sleet",
    "612": "shower sleet",
    "615": "light rain and snow",
    "616": "rain and snow",
    "620": "light shower snow",
    "621": "shower snow",
    "622": "heavy shower snow",
    "701": "mist",
    "711": "smoke",
    "721": "haze",
    "731": "sand or dust whirls",
    "741": "fog",
    "751": "sand",
    "761": "dust",
    "762": "volcanic ash",
    "771": "squalls",
    "781": "tornado",
    "800": "clear sky",
    "801": "few clouds",
    "802": "scattered clouds",
    "803": "broken clouds",
    "804": "overcast clouds",
  }.to_table ## Static Table containing Code-to-Description, all English.
  owm_co2_digits2radius* = {
    "0": 78000, "1": 7862, "2": 786, "3": 78, "4": 8, "5": 1,
  }.to_table ## Static Table of floating point digits precision to search radius on Meters for CO2 Pollution. https://openweathermap.org/api/pollution/co

type
  OpenWeatherMapBase*[HttpType] = object
    proxy*: Proxy
    timeout*: int8
    api_key*, lang*: string
  OWM* = OpenWeatherMapBase[HttpClient]           ## OpenWeatherMap  Sync Client.
  AsyncOWM* = OpenWeatherMapBase[AsyncHttpClient] ## OpenWeatherMap Async Client.

proc owm_http_request(this: OWM | AsyncOWM, base_url, endpoint: string, accurate: bool ,
                      use_json = true, metric = true): Future[string] {.multisync.} =
  ## Base function for all OpenWeatherMap HTTPS GET/POST/PUT/DELETE API Calls.
  assert this.lang in owm_ok_lang, "Invalid Unsupported OpenWeatherMap Language."
  let
    a = if use_json: "" else: "&mode=html"
    b = if accurate: "&type=accurate" else: "&type=like"
    c = if metric:   "&units=metric"  else: "&units=imperial"
    all_arg = a & b & c & "&lang=" & this.lang & "&APPID=" & this.api_key
    responses =
      when this is AsyncOWM:
        await newAsyncHttpClient(
          proxy = when declared(this.proxy): this.proxy else: nil).request(
            url=base_url & endpoint & all_arg)
      else:
        newHttpClient(
          timeout = this.timeout * 1000, proxy = when declared(this.proxy): this.proxy else: nil).request(
            url=base_url & endpoint & all_arg)
  result = await responses.body


# Current Weather.


proc get_current_cityname*(this: OSM | AsyncOSM, city_name: string, country_code = ""): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#name
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"weather?q={city_name}{countr}")

proc get_current_cityid*(this: OSM | AsyncOSM, city_id: int): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#cityid
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"weather?id={city_id}")

proc get_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#geo
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"weather?lat={lat}&lon={lon}")

proc get_current_zipcode*(this: OSM | AsyncOSM, zip_code: int, country_code = ""): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#zip
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"weather?zip={zip_code}{countr}")

proc get_current_bbox*(this: OSM | AsyncOSM, left, bottom, right, top, zoom: int8, cluster: bool): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#rectangle
  let clstr = if cluster: "yes" else: "no"
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"box/city?bbox={left},{bottom},{right},{top},{zoom}&cluster={clstr}")

proc get_current_circle*(this: OSM | AsyncOSM, lat, lon, cnt: int8, cluster: bool): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#cycle
  let clstr = if cluster: "yes" else: "no"
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"find?lat={lat}&lon={lon}&cnt={cnt}&cluster={clstr}")

proc get_current_groupid*(this: OSM | AsyncOSM, ids: seq[int]): Future[string] {.multisync.} =
  ## https://openweathermap.org/current#severalid
  let a = ids.join(",")
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"group?id={a}")


# 5 Day Forecast Weather.


proc get_5d_forecast_cityname*(this: OSM | AsyncOSM, city_name: string, country_code = ""): Future[string] {.multisync.} =
  ## https://openweathermap.org/forecast5#name5
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"forecast?q={city_name}{countr}")

proc get_5d_forecast_cityid*(this: OSM | AsyncOSM, city_id: int): Future[string] {.multisync.} =
  ## https://openweathermap.org/forecast5#cityid5
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"forecast?id={city_id}")

proc get_5d_forecast_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/forecast5#geo5
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"forecast?lat={lat}&lon={lon}")

proc get_5d_forecast_zipcode*(this: OSM | AsyncOSM, zip_code: int, country_code = ""): Future[string] {.multisync.} =
  ## https://openweathermap.org/forecast5#zip
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"forecast?zip={zip_code}{countr}")


# UV Light Index.


proc get_uv_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/uvi#current
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_uv_forecast_coordinates*(this: OSM | AsyncOSM, lat, lon, cnt: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/uvi#forecast
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"uvi/forecast?lat={lat}&lon={lon}&cnt={cnt}")


# Air Pollution.


proc get_co2_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/pollution/co
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_o3_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/pollution/o3
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_so2_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/pollution/so2
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_no2_current_coordinates*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/pollution/no2
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"uvi?lat={lat}&lon={lon}")


# Maps.


proc get_map_clouds*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/weathermaps#clouds
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_map, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_map_precipitation*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/weathermaps#precip
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_map, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_map_pressure*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/weathermaps#pres
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_map, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_map_wind*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/weathermaps#wind
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_map, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_map_temp*(this: OSM | AsyncOSM, lat, lon: int8): Future[string] {.multisync.} =
  ## https://openweathermap.org/api/weathermaps#temp
  # {location}/{datetime}.json?appid={api_key}
  result = await owm_http_request(this, base_url=owm_api_map, endpoint=fmt"uvi?lat={lat}&lon={lon}")
