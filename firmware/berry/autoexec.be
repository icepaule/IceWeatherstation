#-
IceWeatherstation - autoexec.be
==========================================
WICHTIG: Diese Datei muss exakt "autoexec.be" heissen und per Tasmota-
Weboberflaeche (Konsole -> Datei-Manager / "Verwalte Dateisystem") auf den
internen Flash-Speicher des ESP32 hochgeladen werden - nur unter diesem
exakten Namen fuehrt Tasmota die Datei automatisch bei jedem Boot aus.

ENTWURFSSTATUS: Ungetestet auf echter Hardware (siehe docs/tasmota-config.md).
Nutzt ausschliesslich dokumentierte Tasmota-Berry-APIs (tasmota.read_sensors(),
tasmota.add_cron(), tasmota.add_driver(), tasmota.wifi(), tasmota.rtc(),
tasmota.time_dump(), tasmota.cmd()) - trotzdem vor dem produktiven Einsatz
gegen die dann installierte Tasmota-Version pruefen:
https://tasmota.github.io/docs/Berry/

Aufgaben dieses Skripts:
 1. Windfahne (GPIO34, ADC1) -> Windrichtung in Grad per Lookup-Tabelle
 2. Regenmenge der letzten 24h (rollierendes Stunden-Ringpuffer-Fenster aus
    Counter1-Deltas, kein Reset um Mitternacht mehr noetig)
 3. Windgeschwindigkeit in m/s aus Counter2-Deltas (1 Klick/s = 2.4 km/h = 0.667 m/s)
 4. Luftdruck-Trend der letzten 24h (Vergleich mit BME280-Druck von vor 24h,
    ebenfalls per Stunden-Ringpuffer)
 5. OLED-Dashboard (3 Zeilen, alle 10s aktualisiert) + eigene Zeilen im
    Tasmota-Web-UI (Startseite)

Zeilenformat OLED (auf Nutzerwunsch):
 Zeile 1: "<RSSI>dBm <IP>" bzw. "No-WiFi" falls WLAN nicht verbunden
          (ESP32 kann seine Versorgungsspannung NICHT ohne Zusatz-Hardware
          messen - anders als ESP8266 mit ESP.getVcc() - deshalb WLAN-
          Signalstaerke statt "Volt" als Kopfzeilen-Info)
 Zeile 2: "<Windgeschw. m/s>M <Windrichtung Grad>° <Regenmenge 24h>L"
 Zeile 3: "<Temperatur>C<Luftdruck ganzzahlig> <Trend-Pfeil/U/D>"
          ("°" durch "C" ersetzt - Display-Font kann das Grad-Zeichen laut
          Live-Test am echten Geraet 2026-07-18 nicht darstellen)
-#

import string
import json

# Windfahnen-Kalibrierungstabelle: roher ADC-Wert (0-4095, GPIO34/Analog A1)
# -> Windrichtung in Grad (0=Nord, im Uhrzeigersinn).
# TODO nach Aufbau kalibrieren: rohe ADC-Werte real durchmessen (Kompass!),
# SparkFun-Datenblattwerte sind laut mehreren Quellen in der Praxis ungenau.
# Werte hier sind Platzhalter zur Orientierung, KEINE verifizierten Messwerte.
var VANE_TABLE = [
  [3890, 0],
  [3420, 22.5],
  [3620, 45],
  [2200, 67.5],
  [2400, 90],
  [1600, 112.5],
  [1800, 135],
  [1100, 157.5],
  [1300, 180],
  [2900, 202.5],
  [2600, 225],
  [3000, 247.5],
  [3300, 270],
  [3700, 292.5],
  [3500, 315],
  [3800, 337.5]
]

# Ob das aktuelle Display-Font die Sonderzeichen darstellen kann - nach dem
# ersten Flashen visuell am echten Display pruefen. Falls "°" oder die Pfeile
# als Kaestchen/Muell erscheinen, hier auf false umstellen (kein Neu-Flashen
# noetig, nur diese Zeilen aendern und autoexec.be neu hochladen).
var SHOW_DEGREE_SYMBOL = false  # live am Display getestet 2026-07-18: Font zeigt Kaestchen statt "°"
var SHOW_TREND_ARROWS = false   # gleiches Basis-Font wie beim Grad-Zeichen, vorsorglich deaktiviert

# Berry (Tasmota) kennt keine Python-artige Listen-Multiplikation ([0.0]*24) -
# deshalb ueber eine Schleife befuellen.
def zero_list(n)
  var l = []
  var i = 0
  while i < n
    l.push(0.0)
    i += 1
  end
  return l
end

class IceWeather : Driver
  var rain_hourly          # 24 Slots, mm Regen je Kalenderstunde (rollierend)
  var pressure_hourly       # 24 Slots, BME280-Druck-Schnappschuss je Kalenderstunde
  var last_hour
  var pressure_trend        # -1 fallend, 0 gleich/unbekannt, 1 steigend
  var wind_ms, wind_dir_deg
  var last_counter1, last_counter2

  def init()
    self.rain_hourly = zero_list(24)
    self.pressure_hourly = zero_list(24)
    self.last_hour = -1
    self.pressure_trend = 0
    self.wind_ms = 0.0
    self.wind_dir_deg = -1
    self.last_counter1 = 0
    self.last_counter2 = 0
    tasmota.add_cron("*/10 * * * * *", / -> self.refresh_display(), "oled_refresh")
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

  def closest_direction(raw)
    var best_dir = -1
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

  # Bei Stundenwechsel: Regen-Ringpuffer-Slot fuer die neue Stunde leeren,
  # Luftdruck-Trend gegen den 24h alten Schnappschuss im selben Slot
  # bestimmen, BEVOR der neue Druckwert den Slot ueberschreibt.
  def check_hour_rollover(pressure)
    var h = tasmota.time_dump(tasmota.rtc()['local'])['hour']
    if h != self.last_hour
      self.rain_hourly[h] = 0.0
      if pressure != nil && pressure > 0
        var old = self.pressure_hourly[h]
        if old != nil && old > 0
          if pressure > old
            self.pressure_trend = 1
          elif pressure < old
            self.pressure_trend = -1
          else
            self.pressure_trend = 0
          end
        end
        self.pressure_hourly[h] = pressure
      end
      self.last_hour = h
    end
  end

  def rain_24h()
    var total = 0.0
    for v : self.rain_hourly
      total += v
    end
    return total
  end

  def every_second()
    var js = self.read_json()
    if js == nil
      return
    end

    var pressure = nil
    if js.find("BME280") != nil
      pressure = js["BME280"].find("Pressure")
    end
    self.check_hour_rollover(pressure)

    # Regen: Counter1-Delta seit letztem Tick x 0.2794 mm, in aktuellen Stunden-Slot
    if js.find("COUNTER") != nil && js["COUNTER"].find("C1") != nil
      var c1 = js["COUNTER"]["C1"]
      var delta1 = c1 - self.last_counter1
      if delta1 < 0
        delta1 = 0  # Counter-Reset (z.B. nach Neustart) abgefangen
      end
      var h = tasmota.time_dump(tasmota.rtc()['local'])['hour']
      self.rain_hourly[h] += delta1 * 0.2794
      self.last_counter1 = c1
    end

    # Wind: Delta von Counter2 in diesem Tick, 1 Klick/s = 2.4 km/h = 0.6667 m/s
    if js.find("COUNTER") != nil && js["COUNTER"].find("C2") != nil
      var c2 = js["COUNTER"]["C2"]
      var delta2 = c2 - self.last_counter2
      if delta2 < 0
        delta2 = 0  # Counter-Reset abgefangen
      end
      self.wind_ms = delta2 * 0.6667
      self.last_counter2 = c2
    end

    # Windfahne: rohen ADC-Wert (GPIO34, Analog-Kanal A1) gegen Lookup-Tabelle
    if js.find("ANALOG") != nil && js["ANALOG"].find("A1") != nil
      self.wind_dir_deg = self.closest_direction(js["ANALOG"]["A1"])
    end
  end

  def refresh_display()
    # Zeile 1: WLAN-Signalstaerke + IP (ESP32 kann keine eigene Versorgungs-
    # spannung ohne Zusatz-Hardware messen, deshalb RSSI statt "Volt")
    var line1
    if tasmota.wifi('up')
      line1 = string.format("%ddBm %s", tasmota.wifi('rssi'), tasmota.wifi('ip'))
    else
      line1 = "No-WiFi"
    end

    # Zeile 2: Windgeschwindigkeit (m/s) + Windrichtung (Grad) + Regen 24h (L)
    var dir_str = "-"
    if self.wind_dir_deg >= 0
      var deg_unit = ""
      if SHOW_DEGREE_SYMBOL
        deg_unit = "°"
      end
      dir_str = string.format("%d%s", int(self.wind_dir_deg + 0.5), deg_unit)
    end
    var line2 = string.format("%dM %s %dL",
      int(self.wind_ms + 0.5), dir_str, int(self.rain_24h() + 0.5))

    # Zeile 3: Temperatur (1 Nachkommastelle) + Luftdruck (ganzzahlig) + Trend
    var line3 = "BME280 fehlt"
    var js = self.read_json()
    if js != nil && js.find("BME280") != nil
      var temp = js["BME280"].find("Temperature")
      var pressure = js["BME280"].find("Pressure")
      if temp != nil && pressure != nil
        var trend_str = "-"
        if SHOW_TREND_ARROWS
          if self.pressure_trend > 0
            trend_str = "↑"
          elif self.pressure_trend < 0
            trend_str = "↓"
          end
        else
          if self.pressure_trend > 0
            trend_str = "U"
          elif self.pressure_trend < 0
            trend_str = "D"
          end
        end
        line3 = string.format("%.1fC%d %s", temp, int(pressure + 0.5), trend_str)
      end
    end

    tasmota.cmd(string.format("DisplayText [x0y0f1]%s", line1))
    tasmota.cmd(string.format("DisplayText [x0y16f1]%s", line2))
    tasmota.cmd(string.format("DisplayText [x0y32f1]%s", line3))
  end

  # Haengt eigene Zeilen an die Sensor-Tabelle der Tasmota-Startseite an
  # (dokumentierter Weg fuer eigene Werte im Standard-Web-UI, kein voller
  # Seiten-Override noetig)
  def web_sensor()
    tasmota.web_send_decimal(
      string.format("{s}Regen (24h){m}%.2f mm{e}", self.rain_24h()))
    tasmota.web_send_decimal(
      string.format("{s}Windgeschwindigkeit{m}%.2f m/s{e}", self.wind_ms))
    if self.wind_dir_deg >= 0
      tasmota.web_send_decimal(
        string.format("{s}Windrichtung{m}%d°{e}", int(self.wind_dir_deg + 0.5)))
    end
  end
end

iceweather = IceWeather()
tasmota.add_driver(iceweather)
