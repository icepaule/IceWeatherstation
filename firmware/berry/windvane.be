#-
IceWeatherstation - Berry-Skript-Entwurf
==========================================
ENTWURFSSTATUS: Ungetestet auf echter Hardware (siehe docs/tasmota-config.md).
Nutzt ausschliesslich dokumentierte Tasmota-Berry-APIs (tasmota.read_sensors(),
tasmota.add_cron(), tasmota.add_driver(), Driver.web_sensor()) - trotzdem vor
dem produktiven Einsatz gegen die dann installierte Tasmota-Version pruefen:
https://tasmota.github.io/docs/Berry/

Aufgaben dieses Skripts:
 1. Windfahne (GPIO34, ADC1) -> Himmelsrichtung per Lookup-Tabelle
 2. Regenmenge aus Counter1-Pulsen (0.2794 mm/Kippe), taeglicher Reset um Mitternacht
 3. Windgeschwindigkeit aus Counter2-Pulsen (1 Klick/s = 2.4 km/h)
 4. Eigene Zeilen im Tasmota-Web-UI (Startseite) fuer Regenmenge/Wind/Richtung
-#

import string
import json

# TODO nach Aufbau kalibrieren: rohe ADC-Werte (0-4095) je Richtung real messen
# (SparkFun-Datenblattwerte sind laut mehreren Quellen in der Praxis ungenau).
# Werte hier sind Platzhalter zur Orientierung, KEINE verifizierten Messwerte.
var VANE_TABLE = [
  [3890, "N"],
  [3420, "NNE"],
  [3620, "NE"],
  [2200, "ENE"],
  [2400, "E"],
  [1600, "ESE"],
  [1800, "SE"],
  [1100, "SSE"],
  [1300, "S"],
  [2900, "SSW"],
  [2600, "SW"],
  [3000, "WSW"],
  [3300, "W"],
  [3700, "WNW"],
  [3500, "NW"],
  [3800, "NNW"]
]

class IceWeather : Driver
  var rain_mm, wind_kmh, wind_dir
  var last_counter2

  def init()
    self.rain_mm = 0.0
    self.wind_kmh = 0.0
    self.wind_dir = "-"
    self.last_counter2 = 0
    tasmota.add_cron("0 0 0 * * *", / -> self.reset_rain(), "daily_rain_reset")
  end

  # liest die von Tasmota selbst berechnete Sensor-JSON aus (dokumentierter Weg,
  # robuster als eine rohe ADC-Leseroutine nachzubauen)
  def read_json()
    try
      return json.load(tasmota.read_sensors())
    except .. as e
      return nil
    end
  end

  def reset_rain()
    self.rain_mm = 0.0
  end

  def closest_direction(raw)
    var best_dir = "-"
    var best_diff = 99999
    for entry : VANE_TABLE
      var diff = raw - entry[0]
      if diff < 0
        diff = -diff
      end
      if diff < best_diff
        best_diff = diff
        best_dir = entry[1]
      end
    end
    return best_dir
  end

  def every_second()
    var js = self.read_json()
    if js == nil
      return
    end

    # Regen: Counter1-Pulse seit letztem Reset x 0.2794 mm
    if js.find("COUNTER") != nil && js["COUNTER"].find("C1") != nil
      self.rain_mm = js["COUNTER"]["C1"] * 0.2794
    end

    # Wind: Delta von Counter2 in diesem Tick x 2.4 km/h (1 Klick/s = 1.492 mph)
    if js.find("COUNTER") != nil && js["COUNTER"].find("C2") != nil
      var c2 = js["COUNTER"]["C2"]
      var delta = c2 - self.last_counter2
      if delta < 0
        delta = 0  # Counter-Reset abgefangen
      end
      self.wind_kmh = delta * 2.4
      self.last_counter2 = c2
    end

    # Windfahne: rohen ADC-Wert (GPIO34, Analog-Kanal A1) gegen Lookup-Tabelle
    if js.find("ANALOG") != nil && js["ANALOG"].find("A1") != nil
      self.wind_dir = self.closest_direction(js["ANALOG"]["A1"])
    end
  end

  # Haengt eigene Zeilen an die Sensor-Tabelle der Tasmota-Startseite an
  # (dokumentierter Weg fuer eigene Werte im Standard-Web-UI, kein voller
  # Seiten-Override noetig)
  def web_sensor()
    tasmota.web_send_decimal(
      string.format("{s}Regen heute{m}%.2f mm{e}", self.rain_mm))
    tasmota.web_send_decimal(
      string.format("{s}Windgeschwindigkeit{m}%.1f km/h{e}", self.wind_kmh))
    tasmota.web_send_decimal(
      string.format("{s}Windrichtung{m}%s{e}", self.wind_dir))
  end
end

iceweather = IceWeather()
tasmota.add_driver(iceweather)
