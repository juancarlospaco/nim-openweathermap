# Nim-OpenWeatherMap

[OpenWeatherMap](https://openweathermap.org) API Lib for [Nim](https://nim-lang.org), Free world wide [Creative Commons](http://creativecommons.org/licenses/by-sa/4.0) & [Open Data](http://opendatacommons.org/licenses/odbl) Licensed Weather [data](https://openweathermap.org/city).

![OpenWeatherMap](https://raw.githubusercontent.com/juancarlospaco/nim-openweathermap/master/owm.jpg "OpenWeatherMap")


# Install

- `nimble install openweathermap`


# Use

```nim
import openweathermap

# Sync OpenWeatherMap Client.
let owm_client = OWM(timeout: 9, lang: "en", api_key: "YOUR FREE API KEY HERE")
echo owm_client.get_current_cityname(city_name="montevideo", country_code="UY", accurate=true, metric=false)
echo owm_client.get_current_coordinates(lat=9.9, lon=99.99, accurate=false, metric=false)
echo owm_client.get_current_zipcode(zip_code=2804, country_code="AR", accurate=true, metric=false)
echo owm_client.get_current_bbox(left=9.9, bottom=9.9, right= 50.0, top= 50.0, zoom=2, cluster=true, accurate=false, metric=true)
echo owm_client.get_current_circle(lat=55.5, lon=9.9, cnt=2, cluster=true, accurate=true, metric=true)
echo owm_client.get_uv_current_coordinates(lat=9.9, lon=9.9)         # UV Light.
echo owm_client.get_uv_forecast_coordinates(lat=9.9, lon=9.9, cnt=3) # UV Light.
echo owm_client.get_co2_current_coordinates(lat=0.0, lon=10.0)       # CO2 Air Pollution.
echo owm_client.get_o3_current_coordinates(lat=55.0, lon=55.0)       # O3  Air Pollution.
echo owm_client.get_so2_current_coordinates(lat=66.0, lon=66.0)      # SO3 Air Pollution.
echo owm_client.get_no2_current_coordinates(lat=77.0, lon=77.0)      # NO2 Air Pollution.

# Async OpenWeatherMap Client.
proc test {.async.} =
  let
    async_owm_client = AsyncOWM(timeout: 9, lang: "en", api_key: "YOUR FREE API KEY HERE")
    async_resp = await async_owm_client.get_current_cityname(city_name="montevideo", country_code="UY")
  echo $async_resp
waitFor test()
```


# API

- [Check the OpenWeatherMap Docs](https://openweathermap.org/api), the Lib is a 1:1 copy of the official Docs.
- Each proc links to the official OWM API docs.
- All procs should return an JSON Object `JsonNode`.
- The naming of the procs follows the naming on the OWM Wiki.
- The errors on the procs follows the errors on the OWM Wiki.
- API Calls are HTTP `GET`.
- API Calls use [the DoNotTrack HTTP Header.](https://en.wikipedia.org/wiki/Do_Not_Track)
- The `timeout` argument is on Seconds.
- For Proxy support define a `OWM.proxy` or `AsyncOWM.proxy` of `Proxy` type.
- No OS-specific code, so it should work on Linux, Windows and Mac. Not JS.
- Air Pollution works but returns lots of `{"message":"not found"}` until you find a coordinate with data, tiny coverage, endpoint is _Beta_.
- 5 Days Forecast code is commented-out because is not working, send Pull Request if you can make it work.
- Run the module itself for an Example.


# Support

All the Free tier is covered, including [Maps](https://openweathermap.org/api/weathermaps) & [Air Pollution](https://openweathermap.org/api/pollution/co), [except alerts endpoint.](https://openweathermap.org/triggers)


# FAQ

- This works without SSL ?.

No.

- This works with Asynchronous code ?.

Yes.

- This works with Synchronous code ?.

Yes.

- This requires API Key or Login ?.

[Yes. A Free No-Cost API Key.](http://home.openweathermap.org/users/sign_up)

- This requires Credit Card or Payments ?.

No.

- Can I use the OpenWeatherMap data ?.

Yes.


# Requisites

- None.
