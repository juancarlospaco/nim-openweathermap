# Nim-OpenWeatherMap

[OpenWeatherMap](https://openweathermap.org) API Lib for [Nim](https://nim-lang.org), Free world wide [Creative Commons](http://creativecommons.org/licenses/by-sa/4.0) & [Open Data](http://opendatacommons.org/licenses/odbl) Licensed Weather [data](https://openweathermap.org/city) & [maps](https://owm.io/beautiful_maps).

![OpenWeatherMap](https://raw.githubusercontent.com/juancarlospaco/nim-openweathermap/master/owm.jpg "OpenWeatherMap")


# Install

- `nimble install openweathermap`


# Use

```nim
import openweathermap
# ? ? ?
```


# API

- [Check the OpenWeatherMap Docs](https://openweathermap.org/api), the Lib is a 1:1 copy of the official Docs.
- Each proc links to the official OWM API docs.
- All procs should return an JSON Object `JsonNode`.
- The naming of the procs follows the naming on the OWM Wiki.
- The errors on the procs follows the errors on the OWM Wiki.
- API Calls that use HTTP `GET` start with `get_*`.
- API Calls that use HTTP `POST` start with `post_*`.
- API Calls that use HTTP `PUT` start with `put_*`.
- API Calls that use HTTP `DELETE` start with `delete_*`.
- API Calls use [the DoNotTrack HTTP Header.](https://en.wikipedia.org/wiki/Do_Not_Track)
- The `timeout` argument is on Seconds.
- For Proxy support define a `OWM.proxy` or `AsyncOWM.proxy` of `Proxy` type.
- No OS-specific code, so it should work on Linux, Windows and Mac. Not JS.
- Run the module itself for an Example.


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
