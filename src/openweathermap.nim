## Nim-OpenWeatherMap
## ==================
##
## OpenWeatherMap API Lib for Nim, Free world wide Creative Commons & Open Data Licensed Weather data.
##
## - Check the OpenWeatherMap Docs, the Lib is a 1:1 copy of the official Docs.
## - Each proc links to the official OWM API docs.
## - All procs should return an JSON Object ``JsonNode``.
## - The naming of the procs follows the naming on the OWM Wiki.
## - The errors on the procs follows the errors on the OWM Wiki.
## - API Calls are HTTP ``GET``.
## - API Calls use the DoNotTrack HTTP Header https://en.wikipedia.org/wiki/Do_Not_Track
## - The ``timeout`` argument is on Seconds.
## - For Proxy support define a ``OWM.proxy`` or ``AsyncOWM.proxy`` of ``Proxy`` type.
## - No OS-specific code, so it should work on Linux, Windows and Mac. Not JS.
## - Air Pollution works but returns lots of ``{"message":"not found"}`` until you find a coordinate with data, tiny coverage, endpoint is _Beta_.
## - 5 Days Forecast code is commented-out because is not working, send Pull Request if you can make it work.
## - Run the module itself for an Example.

import asyncdispatch, httpclient, strformat, strutils, json, tables, times

const
  owm_api_url* = "https://api.openweathermap.org/data/2.5/"     ## OpenWeatherMap HTTPS API URL for Weather.
  owm_api_air* = "https://api.openweathermap.org/pollution/v1/" ## OpenWeatherMap HTTPS API URL for Air Pollution.
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

proc owm_http_request(this: OWM | AsyncOWM, base_url, endpoint: string,
                      accurate = false, metric = true): Future[JsonNode] {.multisync.} =
  ## Base function for all OpenWeatherMap HTTPS GET/POST/PUT/DELETE API Calls.
  assert this.lang in owm_ok_lang, "Invalid Unsupported OpenWeatherMap Language."
  let
    a = if accurate: "&type=accurate" else: "&type=like"
    b = if metric:   "&units=metric"  else: "&units=imperial"
    all_arg =
      if base_url == owm_api_url:
        a & b & "&lang=" & this.lang & "&appid=" & this.api_key
      else:
        "?appid=" & this.api_key
  let responses =
      when this is AsyncOWM:
        await newAsyncHttpClient(
          proxy = when declared(this.proxy): this.proxy else: nil).request(
            url=base_url & endpoint & all_arg)
      else:
        newHttpClient(
          timeout = this.timeout * 1000, proxy = when declared(this.proxy): this.proxy else: nil).request(
            url=base_url & endpoint & all_arg)
  result = parseJson(await responses.body)


# Current Weather.


proc get_current_cityname*(this: OWM | AsyncOWM, city_name: string, country_code="",
                           accurate=false, metric=true): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#name
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"weather?q={city_name}{countr}", accurate, metric)

proc get_current_cityid*(this: OWM | AsyncOWM, city_id: int): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#cityid
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"weather?id={city_id}")

proc get_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float, accurate=false, metric=true): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#geo
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"weather?lat={lat}&lon={lon}", accurate, metric)

proc get_current_zipcode*(this: OWM | AsyncOWM, zip_code: int, country_code="", accurate=false, metric=true): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#zip
  let countr = if country_code != "": "," & country_code else: ""
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"weather?zip={zip_code}{countr}", accurate, metric)

proc get_current_bbox*(this: OWM | AsyncOWM, left, bottom, right, top: float, zoom: int8, cluster: bool, accurate=false, metric=true): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#rectangle
  let clstr = if cluster: "yes" else: "no"
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"box/city?bbox={left},{bottom},{right},{top},{zoom}&cluster={clstr}", accurate, metric)

proc get_current_circle*(this: OWM | AsyncOWM, lat, lon: float, cnt: int8, cluster: bool, accurate=false, metric=true): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#cycle
  let clstr = if cluster: "yes" else: "no"
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"find?lat={lat}&lon={lon}&cnt={cnt}&cluster={clstr}", accurate, metric)

proc get_current_groupid*(this: OWM | AsyncOWM, ids: seq[int]): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/current#severalid
  let a = ids.join(",")
  result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"group?id={a}")


# 5 Day Forecast Weather.  FIXME Fails I dunno why :(
# proc get_5d_forecast_cityname*(this: OWM | AsyncOWM, city_name: string, country_code = "", accurate=false, metric=true): Future[JsonNode] {.multisync.} =
#   ## https://openweathermap.org/forecast5#name5
#   let countr = if country_code != "": "," & country_code else: ""
#   result = await owm_http_request(
#     this, base_url=owm_api_url, endpoint=fmt"forecast?q={city_name}{countr}", accurate, metric)
#
# proc get_5d_forecast_cityid*(this: OWM | AsyncOWM, city_id: int, accurate=false, metric=true): Future[JsonNode] {.multisync.} =
#   ## https://openweathermap.org/forecast5#cityid5
#   result = await owm_http_request(this, base_url=owm_api_url, endpoint=fmt"forecast?id={city_id}", accurate, metric)
#
# proc get_5d_forecast_coordinates*(this: OWM | AsyncOWM, lat, lon: float, accurate=false, metric=true): Future[JsonNode] {.multisync.} =
#   ## https://openweathermap.org/forecast5#geo5
#   result = await owm_http_request(
#     this, base_url=owm_api_url, endpoint=fmt"forecast?lat={lat}&lon={lon}", accurate, metric)
#
# proc get_5d_forecast_zipcode*(this: OWM | AsyncOWM, zip_code: int, country_code = "", accurate=false, metric=true): Future[JsonNode] {.multisync.} =
#   ## https://openweathermap.org/forecast5#zip
#   let countr = if country_code != "": "," & country_code else: ""
#   result = await owm_http_request(
#     this, base_url=owm_api_url, endpoint=fmt"forecast?zip={zip_code}{countr}", accurate, metric)


# UV Light Index.


proc get_uv_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/uvi#current
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"uvi?lat={lat}&lon={lon}")

proc get_uv_forecast_coordinates*(this: OWM | AsyncOWM, lat, lon: float, cnt: int8): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/uvi#forecast
  result = await owm_http_request(
    this, base_url=owm_api_url, endpoint=fmt"uvi/forecast?lat={lat}&lon={lon}&cnt={cnt}")


# Air Pollution.


proc get_co2_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/pollution/co
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"co/{lat},{lon}/{$getDateStr()}Z.json")

proc get_o3_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/pollution/o3
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"o3/{lat},{lon}/{$getDateStr()}Z.json")

proc get_so2_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/pollution/so2
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"so2/{lat},{lon}/{$getDateStr()}Z.json")

proc get_no2_current_coordinates*(this: OWM | AsyncOWM, lat, lon: float): Future[JsonNode] {.multisync.} =
  ## https://openweathermap.org/api/pollution/no2
  result = await owm_http_request(this, base_url=owm_api_air, endpoint=fmt"no2/{lat},{lon}/{$getDateStr()}Z.json")


when is_main_module:
  # Sync OpenWeatherMap Client.
  let owm_client = OWM(timeout: 9, lang: "en", api_key: "YOUR FREE API KEY HERE")
  echo owm_client.get_current_cityname(city_name="montevideo", country_code="UY", accurate = true, metric = false)
  echo owm_client.get_current_coordinates(lat=9.9, lon=99.99, accurate=false, metric=false)
  echo owm_client.get_current_zipcode(zip_code=2804, country_code="AR", accurate=true, metric=false)
  echo owm_client.get_current_bbox(left=9.9, bottom=9.9, right= 50.0, top= 50.0, zoom=2, cluster=true, accurate=false, metric=true)
  echo owm_client.get_current_circle(lat=55.5, lon=9.9, cnt=2, cluster=true, accurate=true, metric=true)
  echo owm_client.get_uv_current_coordinates(lat=9.9, lon=9.9)
  echo owm_client.get_uv_forecast_coordinates(lat=9.9, lon=9.9, cnt=3)
  echo owm_client.get_co2_current_coordinates(lat=0.0, lon=10.0)
  echo owm_client.get_o3_current_coordinates(lat=55.0, lon=55.0)
  echo owm_client.get_so2_current_coordinates(lat=66.0, lon=66.0)
  echo owm_client.get_no2_current_coordinates(lat=77.0, lon=77.0)

  # Async OpenWeatherMap Client.
  proc test {.async.} =
    let
      async_owm_client = AsyncOWM(timeout: 9, lang: "en", api_key: "YOUR FREE API KEY HERE")
      async_resp = await async_owm_client.get_current_cityname(city_name="montevideo", country_code="UY")
    echo $async_resp
  waitFor test()
