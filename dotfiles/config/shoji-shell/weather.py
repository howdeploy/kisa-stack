"""Optional two-location weather, configured by the installing user (Open-Meteo)."""
import json
import math
import os
import sys
from urllib.error import URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

CITIES = ()
CONDITIONS = {
    0: ("Ясно", "brightness"),
    1: ("Малооблачно", "cloud"), 2: ("Облачно", "cloud"), 3: ("Пасмурно", "cloud"),
    45: ("Туман", "cloud-fog"), 48: ("Туман, изморозь", "cloud-fog"),
    51: ("Морось", "cloud-rain"), 53: ("Морось", "cloud-rain"), 55: ("Сильная морось", "cloud-rain"),
    56: ("Ледяная морось", "cloud-rain"), 57: ("Ледяная морось", "cloud-rain"),
    61: ("Небольшой дождь", "cloud-rain"), 63: ("Дождь", "cloud-rain"), 65: ("Сильный дождь", "cloud-rain"),
    66: ("Ледяной дождь", "cloud-rain"), 67: ("Ледяной дождь", "cloud-rain"),
    71: ("Небольшой снег", "cloud-snow"), 73: ("Снег", "cloud-snow"), 75: ("Сильный снег", "cloud-snow"),
    77: ("Снежная крупа", "cloud-snow"),
    80: ("Ливневый дождь", "cloud-rain"), 81: ("Ливень", "cloud-rain"), 82: ("Сильный ливень", "cloud-rain"),
    85: ("Снежный ливень", "cloud-snow"), 86: ("Сильный снег", "cloud-snow"),
    95: ("Гроза", "cloud-lightning"), 96: ("Гроза с градом", "cloud-lightning"),
    97: ("Сильная гроза", "cloud-lightning"), 99: ("Гроза с градом", "cloud-lightning"),
}


def number(value):
    return type(value) in (int, float) and math.isfinite(value)


def parse(payload):
    if not isinstance(payload, list) or len(payload) != len(CITIES):
        raise ValueError("Expected two locations")
    cities = []
    for (city_id, name, latitude, longitude), item in zip(CITIES, payload):
        if not isinstance(item, dict):
            raise ValueError("Invalid location")
        lat, lon = item.get("latitude"), item.get("longitude")
        if not number(lat) or not number(lon) or abs(lat - latitude) > 0.15 or abs(lon - longitude) > 0.15:
            raise ValueError("Wrong location")
        current, units = item.get("current"), item.get("current_units")
        if not isinstance(current, dict) or not isinstance(units, dict):
            raise ValueError("Missing current weather")
        temp, stamp, code, day = (current.get(key) for key in ("temperature_2m", "time", "weather_code", "is_day"))
        if not number(temp) or not -90 <= temp <= 65 or not number(stamp) or stamp <= 0:
            raise ValueError("Invalid temperature or timestamp")
        if units.get("temperature_2m") != "°C" or units.get("time") != "unixtime":
            raise ValueError("Unexpected units")
        if type(code) is not int or type(day) is not int or day not in (0, 1):
            raise ValueError("Invalid weather code or daylight flag")
        description, icon = CONDITIONS.get(code, ("Нет описания", "cloud"))
        if code == 0 and day == 0:
            icon = "moon"
        cities.append(dict(id=city_id, name=name, temperature=temp, time=stamp * 1000,
                           description=description, icon=icon))
    return cities


def self_check():
    sample = [dict(latitude=lat, longitude=lon,
                   current_units={"temperature_2m": "°C", "time": "unixtime"},
                   current=dict(temperature_2m=0, time=1790503200, weather_code=0, is_day=0))
              for _, _, lat, lon in CITIES]
    sample[1]["current"].update(temperature_2m=-7.5, weather_code=75, is_day=1)
    result = parse(sample)
    assert result[0]["temperature"] == 0 and result[0]["icon"] == "moon"
    assert result[1]["name"] == CITIES[1][1] and result[1]["icon"] == "cloud-snow"
    malformed = json.loads(json.dumps(sample))
    malformed[0]["current"]["temperature_2m"] = None
    for invalid in ({"error": True}, sample[::-1], malformed):
        try:
            parse(invalid)
        except ValueError:
            continue
        raise AssertionError("Invalid weather was accepted")
    print("Weather: locations, zero/freezing temperatures, night/snow and invalid data OK")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-check"]:
        CITIES = (("a", "First", 0, 0), ("b", "Second", 1, 1))
        self_check()
    elif sys.argv[1:]:
        sys.exit("Usage: weather.py [--self-check]")
    else:
        try:
            if os.environ.get("SHOJI_ENABLE_WEATHER") != "1":
                sys.exit("Weather integration is disabled; opt in locally first")
            CITIES = json.loads(os.environ.get("SHOJI_WEATHER_CITIES", "[]"))
            if not isinstance(CITIES, list) or len(CITIES) != 2:
                raise ValueError("Configure exactly two locations")
            for city in CITIES:
                if not isinstance(city, list) or len(city) != 4:
                    raise ValueError("Invalid city")
                if not all(isinstance(v, str) and v for v in city[:2]):
                    raise ValueError("Invalid city name")
                if not number(city[2]) or not -90 <= city[2] <= 90 or not number(city[3]) or not -180 <= city[3] <= 180:
                    raise ValueError("Invalid coordinates")
            URL = "https://api.open-meteo.com/v1/forecast?" + urlencode({
                "latitude": ",".join(str(c[2]) for c in CITIES),
                "longitude": ",".join(str(c[3]) for c in CITIES),
                "current": "temperature_2m,weather_code,is_day", "temperature_unit": "celsius",
                "timezone": "auto", "timeformat": "unixtime", "forecast_days": "1",
            })
            request = Request(URL, headers={"User-Agent": "ShojiWeather/1.0", "Accept": "application/json"})
            with urlopen(request, timeout=20) as response:
                body = response.read(131073)
            if len(body) > 131072:
                raise ValueError("Response too large")
            print(json.dumps({"cities": parse(json.loads(body))}, ensure_ascii=False), flush=True)
        except (OSError, URLError, ValueError):
            sys.exit("Weather update unavailable")
