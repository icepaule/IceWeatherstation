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
 6. Nachtruhe: OLED (DisplayDimmer) und Status-LED (LedState) 22:00-08:00 aus,
    damit nachts niemand vom Leuchten gestoert wird - stuendlich neu geprueft
    (selbstkorrigierend nach einem Neustart mitten in der Nachtruhe)

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
import persist

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

# Nachtruhe: Display+LED nur in diesem Stundenfenster aktiv (24h-Format,
# QUIET_START=22 bedeutet ab 22:00 Uhr aus, QUIET_END=8 bedeutet ab 08:00 Uhr an)
var QUIET_START_HOUR = 22
var QUIET_END_HOUR = 8

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
  var wind_ms, wind_dir_deg
  var last_counter1, last_counter2
  var counters_ready     # false bis der erste Tick nach dem (Neu-)Start die
                          # Counter-Basiswerte gesetzt hat - verhindert einen
                          # falschen Regen-Ausschlag direkt nach einem Neustart
  var quiet_mode        # true = Nachtruhe aktiv (Display+LED aus)

  # Regen-/Druck-Ringpuffer ueberleben einen Neustart nur, wenn sie explizit
  # persistiert werden (RAM-Variablen sind sonst nach jedem Reboot leer) -
  # ohne das wuerde jeder Neustart bis zu 24h Regen-Historie loeschen.
  #
  # WICHTIG (live gefunden 2026-07-19): "persist.foo = self.bar" mit self.bar
  # als Liste erzeugt KEINE gemeinsame Referenz - Aenderungen an self.bar
  # tauchten NICHT in persist.foo auf, persist.save() schrieb dadurch immer
  # die alte/leere Kopie. Fix: rain_hourly/pressure_hourly/last_hour/
  # pressure_trend werden NICHT mehr in self gehalten, sondern ausschliesslich
  # direkt ueber persist.rain_hourly usw. gelesen/geschrieben - persist ist
  # damit die einzige Quelle der Wahrheit, keine zweite Kopie kann divergieren.
  # persist.dirty() ist zusaetzlich noetig, weil In-Place-Aenderungen an
  # Listen von persist nicht automatisch erkannt werden.
  def init()
    if persist.find("rain_hourly", nil) == nil
      persist.rain_hourly = zero_list(24)
    end
    if persist.find("pressure_hourly", nil) == nil
      persist.pressure_hourly = zero_list(24)
    end
    if persist.find("rain_last_hour", nil) == nil
      persist.rain_last_hour = -1
    end
    if persist.find("pressure_trend", nil) == nil
      persist.pressure_trend = 0
    end
    persist.save()

    self.wind_ms = 0.0
    self.wind_dir_deg = -1
    self.last_counter1 = 0
    self.last_counter2 = 0
    self.counters_ready = false
    self.quiet_mode = nil   # unbekannt -> erzwingt sofortige Anwendung beim ersten (gueltigen) Check
    tasmota.add_cron("*/10 * * * * *", / -> self.refresh_display(), "oled_refresh")
    tasmota.add_cron("0 0 * * * *", / -> self.check_quiet_hours(), "quiet_hours_check")
    # NICHT sofort in init() pruefen: die Systemzeit ist beim Booten noch nicht
    # per NTP synchronisiert (Epoch ~0/1970), das wuerde faelschlich Stunde=0
    # liefern und sofort Nachtruhe ausloesen. Stattdessen verzoegert pruefen
    # und bei Bedarf so lange wiederholen, bis eine plausible Zeit vorliegt.
    tasmota.set_timer(15000, / -> self.check_quiet_hours(), "quiet_hours_initial")
  end

  # Nachtruhe 22:00-08:00: OLED dimmen + Status-LED abschalten, damit niemand
  # gestoert wird. Stuendlich neu geprueft (nicht nur einmalig zu Bootzeit),
  # damit ein Neustart mitten in der Nachtruhe sich selbst korrigiert.
  def check_quiet_hours()
    var epoch = tasmota.rtc()['local']
    if epoch < 1000000000   # NTP noch nicht synchronisiert (Epoch nahe 0/1970) - in 15s erneut versuchen
      tasmota.set_timer(15000, / -> self.check_quiet_hours(), "quiet_hours_initial")
      return
    end
    var h = tasmota.time_dump(epoch)['hour']
    var should_be_quiet = (h >= QUIET_START_HOUR) || (h < QUIET_END_HOUR)
    if should_be_quiet != self.quiet_mode
      if should_be_quiet
        tasmota.cmd("DisplayDimmer 0")
        tasmota.cmd("LedState 0")
      else
        tasmota.cmd("DisplayDimmer 100")
        tasmota.cmd("LedState 7")
      end
      self.quiet_mode = should_be_quiet
    end
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
    var epoch = tasmota.rtc()['local']
    if epoch < 1000000000
      return   # NTP noch nicht synchronisiert (Epoch nahe 0/1970) - erst warten,
               # sonst wuerde die falsche Stunde faelschlich einen Rollover
               # ausloesen und den falschen Ringpuffer-Slot leeren (live gefunden!)
    end
    var h = tasmota.time_dump(epoch)['hour']
    if h != persist.rain_last_hour
      persist.rain_hourly[h] = 0.0
      if pressure != nil && pressure > 0
        var old = persist.pressure_hourly[h]
        if old != nil && old > 0
          if pressure > old
            persist.pressure_trend = 1
          elif pressure < old
            persist.pressure_trend = -1
          else
            persist.pressure_trend = 0
          end
        end
        persist.pressure_hourly[h] = pressure
      end
      persist.rain_last_hour = h
      persist.dirty()   # rain_hourly/pressure_hourly wurden in-place geaendert
      persist.save()
    end
  end

  def rain_24h()
    var total = 0.0
    for v : persist.rain_hourly
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

    # Erster Tick nach (Neu-)Start: nur die Counter-Basiswerte uebernehmen,
    # OHNE ein Delta zu berechnen - sonst wuerde der komplette seit dem
    # letzten Neustart aufgelaufene Counter-Stand faelschlich als Regen/Wind
    # in der aktuellen Sekunde gezaehlt (Tasmota-Counter ueberleben manche
    # Neustarts via RTC-Speicher, unser eigenes last_counter1/2 aber nicht).
    if !self.counters_ready
      if js.find("COUNTER") != nil
        if js["COUNTER"].find("C1") != nil
          self.last_counter1 = js["COUNTER"]["C1"]
        end
        if js["COUNTER"].find("C2") != nil
          self.last_counter2 = js["COUNTER"]["C2"]
        end
        self.counters_ready = true
      end
      return
    end

    # Regen: Counter1-Delta seit letztem Tick x 0.2794 mm, in aktuellen Stunden-Slot
    if js.find("COUNTER") != nil && js["COUNTER"].find("C1") != nil
      var c1 = js["COUNTER"]["C1"]
      var delta1 = c1 - self.last_counter1
      if delta1 < 0
        delta1 = 0  # Counter-Reset abgefangen
      end
      if delta1 > 0
        var h = tasmota.time_dump(tasmota.rtc()['local'])['hour']
        persist.rain_hourly[h] += delta1 * 0.2794
        persist.dirty()
        persist.save()
      end
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
    if self.quiet_mode
      return   # Nachtruhe: Display ist gedimmt/aus, kein unnoetiger I2C-Traffic
    end

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
          if persist.pressure_trend > 0
            trend_str = "↑"
          elif persist.pressure_trend < 0
            trend_str = "↓"
          end
        else
          if persist.pressure_trend > 0
            trend_str = "U"
          elif persist.pressure_trend < 0
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

  # Haengt eigene Werte (Wind, Regen 24h) in die periodische MQTT-Sensor-JSON
  # (tele/.../SENSOR) ein - dadurch von Tasmotas MQTT-Discovery automatisch
  # als eigene Home-Assistant-Entitaeten erkannt, ohne HA-seitige Templates.
  def json_append()
    var dir = -1
    if self.wind_dir_deg >= 0
      dir = int(self.wind_dir_deg + 0.5)
    end
    tasmota.response_append(
      string.format(',"IceWeather":{"WindSpeed":%.2f,"WindDir":%d,"Rain24h":%.2f}',
        self.wind_ms, dir, self.rain_24h()))
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
