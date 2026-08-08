#-
IceWeatherstation - autoexec-stephan.be
==========================================
Reduzierte Variante fuer Stephans Geraet: BME280, DS18B20, Windfahne,
Anemometer, Regenmesser, OLED, Status-LED. KEIN AS3935 (Blitzsensor), KEIN
SEN0232 (dBA-Sensor), KEIN MQTT (Geraet laeuft ohne Home Assistant) - deshalb
hier bewusst ohne "import mqtt" und ohne die Solartracker-Kreuz-MQTT-
Regenunterdrueckung des Originalgeraets (kein Solartracker im selben Schuppen).

WICHTIG: Diese Datei muss auf dem Geraet exakt "autoexec.be" heissen und per
Tasmota-Weboberflaeche (Konsole -> Datei-Manager / "Verwalte Dateisystem")
hochgeladen werden - nur unter diesem exakten Namen fuehrt Tasmota sie
automatisch bei jedem Boot aus.

Zeilenformat OLED:
 Zeile 1: "<RSSI>dBm <IP>" bzw. "No-WiFi" falls WLAN nicht verbunden
 Zeile 2: "<Windgeschw. m/s>M <Windrichtung Grad>° <Regenmenge 24h>L"
 Zeile 3: "<Temperatur>C <Luftdruck ganzzahlig> <Trend U/D/-> <Feuchte>%"
 Zeile 4: "Regen Stunde: <X>L"
-#

import string
import json
import persist
import math

# Windfahnen-Kalibrierungstabelle: roher ADC-Wert (0-4095, GPIO34/Analog A1)
# -> Windrichtung in Grad (0=Nord, im Uhrzeigersinn).
# TODO nach Aufbau kalibrieren: rohe ADC-Werte real durchmessen (Kompass!).
# Werte hier sind Platzhalter zur Orientierung, KEINE verifizierten Messwerte -
# identisch zur Tabelle des Originalgeraets (gleicher Sensortyp SEN-15901).
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

# Ob das Display-Font Sonderzeichen darstellen kann - nach dem ersten Flashen
# visuell am echten Display pruefen (beim Originalgeraet: Kaestchen statt "°").
var SHOW_DEGREE_SYMBOL = false
var SHOW_TREND_ARROWS = false

# Nachtruhe: Display+LED nur in diesem Stundenfenster aktiv (24h-Format)
var QUIET_START_HOUR = 22
var QUIET_END_HOUR = 8

# CO2-Kategorie-Schwellen (ppm) fuer die MQ135-Anzeige im Web-UI, angelehnt an
# gaengige Innenraum-Luftqualitaets-Baender (DIN EN 13779 / Pettenkofer-Stil).
var CO2_VERY_GOOD_MAX = 800
var CO2_GOOD_MAX = 1000
var CO2_NORMAL_MAX = 1400
var CO2_BAD_MAX = 2000

# MQ135-Eigenkalibrierung, IO35 (GPIO35, Rolle "ADC Range1" mit Identitaets-
# Skala "6,0,4095,0,4095", daher trotz Rollenname ein roher 0-4095-Wert unter
# ANALOG.Range1). WICHTIG (08.08.2026): Tasmotas eingebaute AdcParam-Typ-10-
# MQ-Formel (Rolle "ADC MQ") wurde getestet und ueber 5 Minuten Laufzeit live
# beobachtet - lieferte durchgehend ~2.9 statt der erwarteten 400-2000 ppm,
# unabhaengig von der Uptime (kein Kalibrierfenster wie unten). Vermutete
# Ursache: der eingebaute Treiber geht von einem anderen Spannungsteiler/
# Referenzspannungs-Aufbau aus als unserer (10 kOhm + 15 kOhm an 3,3V-ADC).
# Deshalb komplett eigene Rs/Ro/ppm-Berechnung nach demselben Verfahren wie
# auf bereits produktiv laufenden, baugleichen MQ135-Sensoren im eigenen
# Heimnetz (deren TSCRIPT als Vorlage uebernommen), aber mit unserem eigenen
# Spannungsteiler-Verhaeltnis statt deren 0,1803-Faktor.
#
# GPIO-Rollen-Layout (zweimal getauscht, 08.08.2026): ein ESP32-Board
# unterstuetzt offenbar nur EINE Instanz der Rolle "ADC Input" gleichzeitig
# (live verifiziert: eine zweite GPIO-Zuweisung auf denselben Rollencode
# ersetzt die erste, statt eine zweite Instanz zu erzeugen) - Windfahne UND
# MQ135 brauchen aber beide einen rohen 0-4095-Wert. Windfahne behaelt die
# Rolle "ADC Input1" (IO34, Schluessel "A1") - dafuer zeigt ihr Web-UI-Label
# korrekt "Windfahne (roh)". MQ135 nutzt "ADC Range1" (IO35, Schluessel
# "Range1") mit derselben Identitaets-Skala - dessen Web-UI-Label heisst
# dadurch fest einkompiliert (Custom-Firmware-Label-Patch vom Originalgeraet,
# wo diese Rolle tatsaechlich fuer den dBA-Sensor stand) irrefuehrend
# "Schallpegel...dBA", obwohl kein Schallsensor verbaut ist. Nur per
# Firmware-Neubau behebbar, nicht per Software-Befehl - bewusst so belassen,
# die echte, korrekt benannte "Luftqualitaet"-Zeile (aus diesem Skript, siehe
# web_sensor()) ist die massgebliche Anzeige.
#
# Kalibrier-Ablauf (mirrors Luft-Skript): in den ersten MQ_CAL_SECONDS nach
# jedem (Neu-)Start wird Ro kontinuierlich aus der aktuellen Rs nachgefuehrt
# (setzt saubere/normale Luft in dieser Zeit voraus!), danach eingefroren.
# Kein Neustart mitten in einer verrauchten/frisch geluefteten Kueche o.ae.,
# sonst verzerrt das die Baseline dauerhaft bis zum naechsten Neustart -
# exakt der Fallstrick, der bei Luft3 einmal zu einem impliziten 29217-ppm-
# Fehlalarm fuehrte (siehe Projektnotizen).
var MQ_VC = 5.0              # Sensor-Versorgungsspannung (Heizer an 5V)
var MQ_DIVIDER_RATIO = 0.6   # unser Spannungsteiler: 15k/(10k+15k)
var MQ_A = 116.6020682       # gaengige Community-Kurve fuer MQ135 (CO2-aehnlich),
var MQ_B = -2.769034857      # identisch zu den Konstanten auf Luft1-4
var MQ_RATIO_CLEAN_AIR = 3.6 # Rs/Ro-Verhaeltnis in sauberer Luft (Datenblatt/Community)
var MQ_CAL_SECONDS = 180     # Kalibrierfenster nach Boot, wie im Luft-Skript

# Mindestabstand zwischen zwei LED-Blitzen (siehe led_pulse() weiter unten) -
# verhindert, dass ein zu schneller Browser-Poll-Takt den Ausschalt-Timer des
# vorherigen Blitzes ueberholt und die LED dauerhaft an bleibt.
var LED_PULSE_MIN_GAP_S = 2

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
  var counters_ready
  var quiet_mode

  # MQ135-Eigenkalibrierung (siehe Konstanten oben)
  var mq_uptime_s     # Sekunden seit (Neu-)Start, nur fuer diese Berechnung
  var mq_active       # true waehrend des Kalibrierfensters (Ro wird nachgefuehrt)
  var mq_ro           # eingefrorene Referenz (Rs/Ro in sauberer Luft)
  var mq_ppm          # letzter berechneter Wert, 0.0 solange noch kalibriert wird

  # Diagnose-Zaehler (08.08.2026): zaehlt jeden web_sensor()-Aufruf, um von
  # aussen (per curl, unabhaengig vom Netzwerkpfad) pruefen zu koennen, ob
  # der Browser-Auto-Refresh der Startseite ueberhaupt Anfragen schickt -
  # Traffic-Sniffing von einem dritten Host aus sieht Unicast zwischen zwei
  # ANDEREN Geraeten im selben Switch-Segment nicht, dieser Zaehler schon.
  var web_hit_count
  var last_pulse_epoch  # tasmota.rtc()['local'] Sekunde des letzten LED-Blitzes

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
    self.quiet_mode = nil

    self.mq_uptime_s = 0
    self.mq_active = true
    self.mq_ro = 1.0
    self.mq_ppm = 0.0
    self.web_hit_count = 0
    self.last_pulse_epoch = 0

    tasmota.add_cron("*/10 * * * * *", / -> self.refresh_display(), "oled_refresh")
    tasmota.add_cron("0 0 * * * *", / -> self.check_quiet_hours(), "quiet_hours_check")
    tasmota.set_timer(15000, / -> self.check_quiet_hours(), "quiet_hours_initial")
  end

  def check_quiet_hours()
    var epoch = tasmota.rtc()['local']
    if epoch < 1000000000
      tasmota.set_timer(15000, / -> self.check_quiet_hours(), "quiet_hours_initial")
      return
    end
    var h = tasmota.time_dump(epoch)['hour']
    var should_be_quiet = (h >= QUIET_START_HOUR) || (h < QUIET_END_HOUR)
    if should_be_quiet != self.quiet_mode
      if should_be_quiet
        tasmota.cmd("DisplayDimmer 0")
        tasmota.cmd("LedPower1 0")
      else
        tasmota.cmd("DisplayDimmer 100")
      end
      self.quiet_mode = should_be_quiet
    end
  end

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

  def check_hour_rollover(pressure)
    var epoch = tasmota.rtc()['local']
    if epoch < 1000000000
      return
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
      persist.dirty()
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
        delta1 = 0
      end
      if delta1 > 0
        var now = tasmota.rtc()['local']
        var h = tasmota.time_dump(now)['hour']
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
        delta2 = 0
      end
      self.wind_ms = delta2 * 0.6667
      self.last_counter2 = c2
    end

    # Windfahne: rohen ADC-Wert (GPIO34, Rolle "ADC Input1") gegen Lookup-Tabelle.
    # Stand 08.08.2026: zurueckgetauscht auf "ADC Input1"/"A1" (statt "ADC Range1"),
    # damit die Windfahne im Web-UI wieder korrekt "Windfahne (roh)" heisst statt
    # der fest einkompilierten Fehlbezeichnung "Schallpegel...dBA", die am
    # Rollennamen "ADC Range" haengt (Custom-Firmware-Patch vom Originalgeraet,
    # dort war "Range" tatsaechlich der dBA-Sensor). MQ135 nutzt dafuer jetzt
    # "ADC Range1"/"Range1" mit Identitaets-Skala (AdcParam2 6,0,4095,0,4095) -
    # zeigt selbst weiterhin unter der falschen "Schallpegel"-Zeile, aber diese
    # Fehlbezeichnung liesse sich ohnehin nur per Firmware-Neubau beheben, nicht
    # per Software-Befehl.
    if js.find("ANALOG") != nil && js["ANALOG"].find("A1") != nil
      self.wind_dir_deg = self.closest_direction(js["ANALOG"]["A1"])
    end

    # MQ135-Eigenkalibrierung (GPIO35, Rolle "ADC Range1", roher 0-4095-Wert
    # unter "Range1" dank Identitaets-Skala - siehe Konstanten/Kommentar am
    # Dateianfang)
    if js.find("ANALOG") != nil && js["ANALOG"].find("Range1") != nil
      var raw = js["ANALOG"]["Range1"]
      var v_adc = raw / 4095.0 * 3.3
      var v_out = v_adc / MQ_DIVIDER_RATIO
      if v_out < 0.05
        v_out = 0.05
      end
      var rs = (MQ_VC - v_out) / v_out
      self.mq_uptime_s += 1
      if self.mq_active
        self.mq_ro = rs / MQ_RATIO_CLEAN_AIR
      end
      if self.mq_uptime_s > MQ_CAL_SECONDS
        self.mq_active = false
      end
      if !self.mq_active
        var ratio = rs / self.mq_ro
        self.mq_ppm = MQ_A * math.pow(ratio, MQ_B)
      end
    end
  end

  def rain_this_hour()
    var epoch = tasmota.rtc()['local']
    if epoch < 1000000000
      return 0.0
    end
    var h = tasmota.time_dump(epoch)['hour']
    return persist.rain_hourly[h]
  end

  # Ordnet einen MQ135-ppm-Wert einer der 5 CO2-Kategorien zu (Text, keine
  # Tasmota-Standardfarbe verfuegbar fuer einzelne Web-UI-Zeilen).
  def co2_category(ppm)
    if ppm < CO2_VERY_GOOD_MAX
      return "Sehr gut"
    elif ppm < CO2_GOOD_MAX
      return "Gut"
    elif ppm < CO2_NORMAL_MAX
      return "Normal"
    elif ppm < CO2_BAD_MAX
      return "Schlecht"
    else
      return "Kritisch"
    end
  end

  def refresh_display()
    if self.quiet_mode
      return
    end

    var js = self.read_json()

    var line1
    if tasmota.wifi('up')
      line1 = string.format("%ddBm %s", tasmota.wifi('rssi'), tasmota.wifi('ip'))
    else
      line1 = "No-WiFi"
    end

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

    # Temperatur bewusst vom DS18B20 statt vom BME280 (Strahlungswaerme-Effekt,
    # siehe docs/tasmota-config.md Abschnitt 14 des Originalgeraets) - gilt
    # analog, falls das BME280-Breakout ebenfalls an der Gehaeusewand sitzt.
    var line3 = "Sensor fehlt"
    if js != nil && js.find("DS18B20") != nil && js.find("BME280") != nil
      var temp = js["DS18B20"].find("Temperature")
      var pressure = js["BME280"].find("Pressure")
      var humidity = js["BME280"].find("Humidity")
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
        var hum_str = "-"
        if humidity != nil
          hum_str = string.format("%d%%", int(humidity + 0.5))
        end
        line3 = string.format("%.1fC %d %s %s", temp, int(pressure + 0.5), trend_str, hum_str)
      end
    end

    var line4 = string.format("Regen Stunde: %.1fL", self.rain_this_hour())

    tasmota.cmd(string.format("DisplayText [x0y0f1]%s", line1))
    tasmota.cmd(string.format("DisplayText [x0y16f1]%s", line2))
    tasmota.cmd(string.format("DisplayText [x0y32f1]%s", line3))
    tasmota.cmd(string.format("DisplayText [x0y48f1]%s", line4))
  end

  # Status-LED kurz aufblitzen lassen (WLAN-Datentransfer-Anzeige, analog zum
  # Originalgeraet). WICHTIG (08.08.2026): Das Originalgeraet nutzt Tasmotas
  # eingebautes LedState 7 ("blinkt bei jeder MQTT-Aktivitaet") - das braucht
  # zwingend einen verbundenen MQTT-Broker, den dieses Geraet absichtlich
  # nicht hat (siehe Projektentscheidung oben im Datei-Kopf). Tasmotas Berry-
  # API bietet keinen Hook fuer generischen WLAN-Traffic (kein Byte-Zaehler,
  # kein "Paket empfangen"-Event - siehe Tasmota-Berry-Doku). Deshalb hier
  # stattdessen manuell an web_sensor() gekoppelt, das bei jedem Abruf der
  # Sensor-Tabelle laeuft - insbesondere beim AJAX-Poll, den die Tasmota-
  # Startseite alle ~2,3s ausfuehrt, solange jemand die Seite offen hat.
  # Ergebnis: LED blinkt, wenn gerade echter HTTP-Traffic zum/vom Geraet
  # laeuft (Browser-Tab offen) - funktional aehnlich zum Original, aber nicht
  # 1:1 identisch (kein Blinken bei reiner Hintergrund-Telemetrie ohne
  # Betrachter, dafuer aber auch kein MQTT-Overhead noetig).
  # FALLSTRICK 1 (08.08.2026, live gefunden): der Browser muss der AKTIVE
  # (fokussierte) Tab sein - die meisten Browser drosseln JS-Timer in
  # Hintergrund-Tabs stark, dann wirkt es so, als wuerde die LED gar nicht
  # blinken, obwohl der Mechanismus laeuft. Ein Reload mit aktivem Tab behebt
  # das. Puls-Dauer bewusst auf 400ms gesetzt (statt anfangs 150ms) - bei
  # 150ms war der Blitz selbst per gezieltem Sofort-Check per curl nur in
  # 1 von 3 Versuchen sicher zu erwischen, also zu knapp fuers menschliche Auge.
  #
  # FALLSTRICK 2 (08.08.2026, live gefunden): mit einem Diagnose-Zaehler
  # (web_hit_count, siehe web_sensor()) verifiziert, dass der reale Poll-Takt
  # eher bei <1s liegt statt der angenommenen 2,3s. Ohne Drosselung ueberholt
  # dann fast jeder neue Aufruf den 400ms-Ausschalt-Timer des vorherigen, bevor
  # der ueberhaupt feuert (Tasmota ersetzt einen benannten Timer beim erneuten
  # Setzen) - die LED blieb dadurch dauerhaft an statt sichtbar zu blinken.
  # Fix: Puls hoechstens alle MQ_... nein, LED_PULSE_MIN_GAP_S Sekunden
  # zulassen (Sekundenraster ueber tasmota.rtc(), unabhaengig vom tatsaechlichen
  # Poll-Takt) - dadurch bleibt zwischen zwei Pulsen immer genug Luft, damit
  # der vorherige sauber ausblendet, bevor der naechste startet.
  def led_pulse()
    if self.quiet_mode
      return
    end
    var now = tasmota.rtc()['local']
    if now - self.last_pulse_epoch < LED_PULSE_MIN_GAP_S
      return
    end
    self.last_pulse_epoch = now
    tasmota.cmd("LedPower1 1")
    tasmota.set_timer(400, / -> tasmota.cmd("LedPower1 0"), "led_pulse_off")
  end

  # Eigene Zeilen auf der Tasmota-Startseite (Web-UI)
  def web_sensor()
    self.web_hit_count += 1
    self.led_pulse()
    tasmota.web_send_decimal(
      string.format("{s}Diagnose: Seitenaufrufe{m}%d{e}", self.web_hit_count))
    tasmota.web_send_decimal(
      string.format("{s}Regen (24h){m}%.2f mm{e}", self.rain_24h()))
    tasmota.web_send_decimal(
      string.format("{s}Windgeschwindigkeit{m}%.2f m/s{e}", self.wind_ms))
    if self.wind_dir_deg >= 0
      tasmota.web_send_decimal(
        string.format("{s}Windrichtung{m}%d°{e}", int(self.wind_dir_deg + 0.5)))
    end

    if self.mq_active
      var remain = MQ_CAL_SECONDS - self.mq_uptime_s
      if remain < 0
        remain = 0
      end
      tasmota.web_send_decimal(
        string.format("{s}Luftqualitaet (CO2-aehnlich){m}Kalibriere.. (noch %ds){e}", remain))
    else
      tasmota.web_send_decimal(
        string.format("{s}Luftqualitaet (CO2-aehnlich){m}%s (%.0f ppm){e}", self.co2_category(self.mq_ppm), self.mq_ppm))
    end
  end
end

iceweather = IceWeather()
tasmota.add_driver(iceweather)
