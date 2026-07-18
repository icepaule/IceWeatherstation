# Tasmota-Firmware-Konfiguration

> ⚠️ **Entwurfsstatus:** Diese Konfiguration ist noch nicht auf echter Hardware getestet (Teile wurden erst bestellt). Sie basiert auf offiziell dokumentierten Tasmota-Features und den Erfahrungen aus der bestehenden [Luft1-Station](https://tasmota.github.io/docs/) (baugleicher AS3935-Sensortyp, dort seit längerem stabil im Einsatz). Vor dem finalen Flashen der zweiten Station: Werte anhand der ersten, real aufgebauten Station verifizieren und diese Doku aktualisieren.

## Firmware-Basis

Kein fertiges Community-Template nötig — alle benötigten Bausteine sind in Standard-Tasmota (ESP32-Build) enthalten:

| Anforderung | Tasmota-Feature |
|---|---|
| BME280 (I2C) | Nativer Sensor-Treiber, autodetect |
| AS3935 (I2C) | Nativer Sensor-Treiber |
| DS18B20 (1-Wire) | Nativer Sensor-Treiber |
| Regen-/Windpulse | `Counter1` / `Counter2` |
| dBA-Sensor (analog, linear) | `AdcParam`-Bereichsumrechnung (Typ 6, "Range") |
| Windfahne (Potentiometer → 8 Richtungen) | Rules oder Berry-Skript (kein nativer Support) |
| Eigenes Web-UI | Berry `webserver`-Hooks |

## 1. Grundkonfiguration (Web-UI: *Konfiguration* → *Konfiguriere Modul*)

Empfohlen: Die GPIO-Zuordnung **über die Tasmota-Web-Oberfläche** vornehmen (Modul-Konfigurationsseite), nicht per handgeschriebenem `Template`-JSON — die Web-UI verhindert falsch nummerierte GPIO-Komponenten-IDs, die sich zwischen Tasmota-Versionen ändern können.

**Alternative: per Serial-Konsole (verifiziert für Tasmota 15.5.0(release-tasmota32)-3.3.8, 2026-06-22).** Statt der Web-UI kann jedes `GPIO<pin>`-Kommando direkt den numerischen Funktionswert setzen — praktisch fürs Erstflashen ohne WLAN. Die Werte wurden nicht geraten, sondern aus der `/md`-Seite dieses konkreten Builds ausgelesen (das Options-Array enthält die realen numerischen IDs):

```
GPIO21 640    // I2C SDA1 (BME280 + AS3935)
GPIO22 608    // I2C SCL1 (BME280 + AS3935)
GPIO25 4672   // AS3935 IRQ
GPIO4 1312    // DS18x20 (DS18B20-Sonde)
GPIO27 352    // Counter1 (Regenmesser)
GPIO14 353    // Counter2 (Anemometer)
GPIO34 4704   // ADC Input1 (Windfahne)
GPIO35 4864   // ADC Range1 (dBA-Sensor SEN0232)
```

⚠️ Diese Werte gelten nur für exakt diesen Firmware-Build — bei anderer Tasmota-Version vor Gebrauch per `GPIO<pin>` (ohne Wert) den aktuellen Zustand gegenprüfen bzw. neu aus `/md` auslesen. Der `/md`- und `/cn`-Pfad ist ab Tasmota ≥15 ohne WebPassword standardmäßig für Referer-lose Requests gesperrt (`HTP: Referer '' denied. Use 'SO128 1' for HTTP API`) — für den einmaligen Auslese-Zugriff testweise `SetOption128 1` setzen, danach wieder auf `0` zurücksetzen (Standard-Absicherung bleibt so erhalten).

Pinbelegung (siehe auch [wiring.md](wiring.md)):

| GPIO | Komponente |
|---|---|
| 21 | I2C SDA |
| 22 | I2C SCL |
| 25 | **AS3935** (eigene GPIO-Komponente, kein generischer Interrupt) |
| 4 | DS18B20 (1-Wire) |
| 27 | Counter1 (Regenmesser) |
| 14 | Counter2 (Anemometer) |
| 34 | ADC Input (Windfahne, Rohwert 0–4095) |
| 35 | ADC Input **Range** (dBA-Sensor SEN0232, siehe Abschnitt 3) |

> Tasmota verlangt für den AS3935 eine eigene GPIO-Rolle „AS3935" in der Modul-Konfiguration (nicht „Interrupt"). Zusätzlich müssen an der AS3935-Platine die Pins **CS und MISO auf GND**, **SI auf VCC** gelegt werden, falls die Platine diese SPI-Pins herausführt (bei I2C-Betrieb ungenutzt, aber nicht offen lassen) — [Quelle: Tasmota AS3935-Doku](https://tasmota.github.io/docs/AS3935/).

## 2. Regenmesser & Anemometer (Counter)

Tasmota zählt Pulse an `Counter1`/`Counter2` automatisch. Umrechnungsfaktoren (aus dem SparkFun-Hookup-Guide):

- **Regen:** 1 Kippe = 0,2794 mm
- **Wind:** 1 Klick/Sekunde = 1,492 mph ≈ 2,4 km/h

```
CounterType1 0        // Pulszähler, kein PWM
CounterDebounce 10     // ms, gegen Kontaktprellen am Reed-Kontakt
```

Die Umrechnung Pulse→mm bzw. Pulse/Zeit→km/h ist **nicht linear per `AdcParam` abbildbar** (zeitbasiert), deshalb im Berry-Skript berechnet — siehe [firmware/berry/autoexec.be](../firmware/berry/autoexec.be).

## 3. dBA-Sensor (SEN0232) via AdcParam (Range-Typ)

DFRobot-Formel laut Datenblatt: **dB = Vout(V) × 50** (0,6V → 30 dBA, 2,6V → 130 dBA) — exakt linear, ideal für Tasmotas native ADC-Bereichsumrechnung.

⚠️ **Zwei Fallen, live an Tasmota 15.5.0(release-tasmota32)-3.3.8 verifiziert und korrigiert (2026-07-18):**

1. **`AdcParam<N>` zählt nach GPIO-Reihenfolge, nicht nach Pin-Nummer.** Die Kanalnummer `N` entspricht der Position unter allen ADC-Rollen-Pins, aufsteigend nach GPIO-Nummer sortiert — **nicht** der GPIO-Nummer selbst. Bei diesem Projekt: GPIO34 (Windfahne, „ADC Input") ist Kanal **1**, GPIO35 (dBA, „ADC Range") ist Kanal **2** → der richtige Befehl ist `AdcParam2`, nicht `AdcParam1`! Zur Kontrolle: Der Echo-Antwort-Wert an erster Stelle im Array ist die tatsächliche GPIO-Nummer, z.B. `{"AdcParam2":[35,...]}` bestätigt Pin 35.
2. **Die Schwellwerte sind KEINE Millivolt, sondern ein 0–4095-Pseudo-ADC-Wert** (aus kalibrierter mV-Messung zurückgerechnet, siehe Tasmota-Quellcode `xsns_02_analog.ino`). 0,6V/2,6V müssen erst umgerechnet werden: `mV / 3300 × 4095`.

```
600mV  → 600/3300×4095  ≈ 745
2600mV → 2600/3300×4095 ≈ 3226

AdcParam2 6,745,3226,300,1300   // Kanal 2 = GPIO35; Pseudo-ADC 745–3226 (≈0,6–2,6V) -> Output 30,0-130,0 dBA (x0.1)
```

Ergebnis nach Korrektur: `Status 10` zeigt einen plausiblen Wert um `Range1: 500–600` (= 50–60 dBA, normaler Innenraum-Umgebungspegel), statt vorher fälschlich `35` (3,5 dBA, unmöglich niedrig — Anzeichen, dass etwas an der Umrechnung nicht stimmt).

Allgemein: mit `Status 10` immer gegenprüfen, welcher Analog-Kanal (`Range1`, `Range2`, …) tatsächlich den dBA-Wert zeigt, und mit `AdcParam<N>` (ohne Werte) den aktuell gespeicherten Zustand samt zugehöriger GPIO-Nummer abfragen, bevor man kalibriert.

## 4. Windfahne (Potentiometer → Richtung)

Keine native Tasmota-Umrechnung vorhanden. Zwei Optionen:

1. **Klassische Rules** mit ADC-Schwellwert-Vergleichen (`ON Analog#A1>x DO ... ENDON`) — einfacher, aber unübersichtlich bei 8 Richtungen mit Übergangsbereichen
2. **Berry-Skript mit Lookup-Tabelle** (empfohlen) — übersichtlicher, einfacher zu kalibrieren. Siehe [firmware/berry/autoexec.be](../firmware/berry/autoexec.be)

Die Datenblatt-Spannungswerte der SparkFun-Windfahne sind laut mehreren Quellen in der Praxis ungenau — **nach dem Aufbau mit einer Wasserwaage/Kompass real durchmessen und die Lookup-Tabelle anpassen.**

⚠️ **Fallstrick, live gefunden (2026-07-18):** Der Rohwert (`A1` im Status-10-JSON, `GPIO_ADC_INPUT`-Typ) verschwindet komplett aus der JSON-Ausgabe, sobald `AdcParam<Kanal>` den **4. Parameter ungleich 0** stehen hat (das ist Tasmotas interner Umschalter für einen "Direct Mode", der eigentlich für Dimmer/Licht-Steuerung gedacht ist, nicht für uns relevant). Falls `A1` nicht in `Status 10` auftaucht, obwohl GPIO korrekt auf „ADC Input" steht: `AdcParam<Kanal>` (Kanalnummer nach GPIO-Reihenfolge zählen, siehe Abschnitt 3) mit 4. Wert explizit auf 0 zurücksetzen, z.B. `AdcParam1 6,0,0,0,0`.

## 5. AS3935 (Blitzsensor)

Verifizierte Befehle laut [Tasmota AS3935-Dokumentation](https://tasmota.github.io/docs/AS3935/):

```
AS3935setgain Outdoors   // Outdoor-Verstärkung statt Indoors
AS3935autonf 1           // automatische Störgeräusch-Kalibrierung
AS3935disturber 1        // Disturber-Erkennung aktiv
AS3935autodisturber 1    // automatische Disturber-Unterdrückung
AS3935settings           // aktuelle Konfiguration zur Kontrolle anzeigen
```

Erfahrungswert aus der Luft1-Station: `Outdoors`-Modus ist bei Freiluft-Montage entscheidend gegen Fehlalarme (`Indoors`-Modus hat deutlich höhere, für den Außeneinsatz zu empfindliche Verstärkung). I2C-Adresse ist bei diesem Sensor-Typ fix `0x03` (kein Konfigurationsschritt nötig). Bei anhaltenden Fehlalarmen zusätzlich `AS3935setnf` (Noise-Floor-Level 0–7) manuell nachjustieren.

## 6. OLED-Display (Hailege 0,96" SSD1306, 128×64, I2C, 4-Pin)

Kein eigener Sensor-GPIO nötig — das Display hängt als dritter Teilnehmer am selben I2C-Bus wie BME280 und AS3935 (siehe [wiring.md](wiring.md)). Braucht aber einen zusätzlichen **virtuellen Marker-Pin** (s.u.).

⚠️ **Wichtige Änderung ggü. älteren Tasmota-Anleitungen (live an Tasmota 15.5.0 verifiziert, 2026-07-18):**

1. **Der klassische `DisplayModel 2`/SSD1306-Treiber ist im Standard-`tasmota32.bin` gar nicht enthalten** — Display-Support ist ein eigenes Firmware-Feature-Build (`tasmota32-display.bin`). Umstieg per OTA, **ohne** die Sensor-Konfiguration zu verlieren (Settings bleiben auf dem separaten Flash-Dateisystem erhalten):
   ```
   OtaUrl http://ota.tasmota.com/tasmota32/release/tasmota32-display.bin
   Upgrade 1
   ```
   Läuft über den ESP32-eigenen SafeBoot-Zwischenschritt (kurzzeitig `Version 15.5.0(release-safeboot)` im Log, normal), danach automatischer Neustart in `(release-display)`. Laut Tasmota-Quellcode entfernt dieser Build nur Emulation/Domoticz/Home-Assistant/Energy-Monitoring — AS3935 und Berry bleiben erhalten.
2. **Der alte SSD1306-Treiber selbst wurde in aktuellem Tasmota komplett entfernt** und durch das neue, generische **uDisplay**-System ersetzt (`DisplayModel` ist jetzt immer **17**, unabhängig vom Displaytyp). Ein `DisplayModel 2`-Versuch wird stillschweigend auf `0` zurückgesetzt (Command scheint erfolgreich, wirkt aber nicht — keine Fehlermeldung!).

### Einrichtung (uDisplay)

1. Einen **ungenutzten** GPIO auf die Rolle **„Option A3"** setzen — rein virtueller Marker ohne physische Funktion, signalisiert Tasmota nur "uDisplay starten". In diesem Projekt: GPIO32 (frei, siehe [wiring.md](wiring.md)).
   ```
   GPIO32 6210   // "Option A3" — Basiswert "Option A1"=6208 + Instanz-Offset 2, gleiches Zählschema wie Counter1/2
   ```
2. Den SSD1306-Display-Descriptor hinterlegen — offizielle Datei [`SSD1306_128x64_display.ini`](https://github.com/arendst/Tasmota/blob/development/tasmota/displaydesc/SSD1306_128x64_display.ini) aus dem Tasmota-Repo, als **einzeiliger** String in `Rule3` gespeichert (Rule3 bewusst **nicht aktivieren** — dient hier nur als Datenspeicher für den Descriptor, nicht als ausführende Regel):
   ```
   Rule3 :H,SSD1306,128,64,1,I2C,3c,*,*,* :S,0,2,1,0,30,20 :I AE D5,80 A8,3F D3,00 40 8D,14 20,00 A1 C8 DA,12 81,9F D9,F1 DB,40 A4 A6 AF :o,AE :O,AF :A,00,10,40,00,00 :i,A6,A7
   ```
   ⚠️ Adresse `3c` im Descriptor selbst prüfen/anpassen, falls das eigene Board auf `0x3D` läuft (per `I2CScan` verifizieren, wie beim AS3935-Adressabgleich).
3. Display-Modell aktivieren und Neustart (nötig, damit der Treiber greift):
   ```
   DisplayModel 17
   Restart 1
   ```
4. Nach dem Neustart sollte das Boot-Log `DSP: SSD1306 initialized` zeigen. Test:
   ```
   DisplayText [x0y0f1]Wetterstation
   ```

### Live-Daten automatisch anzeigen

**Erster Ansatz (überholt):** Eine einfache Tasmota-Rule (`ON Tele-DS18B20#Temperature DO DisplayText ... ENDON`) reicht für einzelne Werte, aber nicht für rollierende 24h-Fenster (Regenmenge, Luftdruck-Trend) — Rules haben keinen eigenen Zustand/Speicher über die Zeit. Das finale Dashboard läuft daher komplett über [firmware/berry/autoexec.be](../firmware/berry/autoexec.be) (Berry-Skript), **Rule1 ist deaktiviert** (`Rule1 0`).

Das Skript aktualisiert alle 10 Sekunden per `tasmota.add_cron("*/10 * * * * *", ...)` drei Zeilen:

```
Zeile 1: <RSSI>dBm <IP>              (oder "No-WiFi" falls WLAN nicht verbunden)
Zeile 2: <Wind m/s>M <Richtung>° <Regen 24h>L
Zeile 3: <Temperatur>C<Luftdruck ganzzahlig, ohne Einheit> <Trend U/D>
```

⚠️ **ESP32 kann keine eigene Versorgungsspannung messen** (anders als ESP8266 mit `ESP.getVcc()` — keine interne Referenz zum Vergleich vorhanden, siehe [ESP32-Forum-Diskussion](https://esp32.com/viewtopic.php?t=3221)). Zeile 1 zeigt deshalb WLAN-Signalstärke statt einer erfundenen Spannungsangabe. Falls später ein Spannungsteiler an einem freien ADC-Pin (GPIO33/36/39) verbaut wird, lässt sich echte Spannungsmessung nachrüsten.

⚠️ **Font des Displays kann keine Sonderzeichen** (live getestet 2026-07-18: `°`-Zeichen erscheint als Kästchen). Das Skript hat deshalb zwei Schalter am Dateianfang:
```berry
var SHOW_DEGREE_SYMBOL = false  # testweise auf true stellen und visuell prüfen
var SHOW_TREND_ARROWS = false   # dito — Pfeile ↑/↓ vs. Buchstaben U/D
```
Nach Änderung: Datei erneut über *Konsole → Verwalte Dateisystem* hochladen (exakt `autoexec.be`) + `Restart 1`.

⚠️ Für den dBA-Sensor (`ANALOG#Range1`) empfiehlt sich `AdcParam` **ohne** die künstliche ×10-Skalierung (`AdcParam2 6,745,3226,30,130` statt `...,300,1300`) — sonst zeigt das Display "596" statt "60" an. Details zur Umrechnung: Abschnitt 3 oben.

⚠️ **Berry kennt keine Listen-Multiplikation** (`[0.0] * 24` schlägt fehl mit `attribute_error`) — Ringpuffer stattdessen per Schleife befüllen (siehe `zero_list()` im Skript).

Regenmenge/Luftdruck-Trend nutzen ein rollierendes 24-Stunden-Ringpuffer-Fenster (`tasmota.rtc()`/`tasmota.time_dump()` für die aktuelle Kalenderstunde) statt eines Mitternacht-Resets — überlebt aber **keinen Neustart** (Historie liegt im RAM, nicht in `persist`, um Flash-Verschleiß durch stündliche Schreibzugriffe zu vermeiden). Nach einem Neustart füllt sich das 24h-Fenster graduell wieder auf.

## Konfigurationsablauf

```mermaid
flowchart TD
    A[Tasmota flashen] --> B[WLAN + Grundkonfiguration]
    B --> C[Modul-GPIOs zuweisen]
    C --> D[I2C-Scan: BME280 + AS3935 erkannt?]
    D -->|nein| D1[Verkabelung/Adressen prüfen]
    D1 --> D
    D -->|ja| E[DS18B20 erkannt?]
    E -->|nein| E1[Pull-up/Verkabelung prüfen]
    E1 --> E
    E -->|ja| F[Counter1/2 Testpulse manuell auslösen]
    F --> G[AdcParam dBA-Sensor kalibrieren]
    G --> H[Berry-Skript für Windfahne laden]
    H --> I[AS3935 auf Outdoor + Testauslösung]
    I --> J[WebSensor-Anzeige aufräumen]
    J --> K[Konfiguration exportieren/sichern]
```

## 7. Status-LED (WLAN/MQTT-Link, optional)

Externe LED (z.B. aus einem Elegoo-Sensor-Kit) + Vorwiderstand (330Ω) an einem freien GPIO, hier **GPIO2**:

```
GPIO2 544      // "LedLink" (Basiswert "LedLink1", gleiches Zählschema wie Counter1/2)
LedState 7     // s.u. — GPIO-Rolle allein reicht NICHT aus
```

Verkabelung: GPIO → Vorwiderstand → LED-Anode (langes Beinchen), LED-Kathode (kurzes Beinchen) → GND. Bei Common-Kathode-RGB-Modulen (z.B. Elegoo SMD-RGB/RGB-LED, 4 Pins: R/G/B/GND) reicht ein einzelner Farbkanal für diesen Zweck — die anderen beiden Pins bleiben unbeschaltet.

⚠️ **Fallstrick, live gefunden (2026-07-18):** Die GPIO-Rollenzuweisung („LedLink") allein reicht nicht — ohne zusätzliches `LedState` bleibt die LED aus. `LedState` ist eine Bitmaske 0–7 (`enum LedStateOptions` im Tasmota-Quellcode: 1=Power, 2/4=MQTT-Sub/Pub-Aktivität, kombinierbar), **kein** einfacher "AN sobald WLAN+MQTT verbunden"-Schalter — eine erste Recherche deutete fälschlich auf einen (nicht existierenden) Wert 8 hin, der von `CmndLedState` aber hart auf `< MAX_LED_OPTION` (=8, also nur 0–7 gültig) begrenzt wird.

Live-Verhalten bei `LedState 7`: LED **blinkt rhythmisch bei jeder MQTT-Aktivität** (Senden/Empfangen), kein dauerhaftes Leuchten im verbundenen Zustand — zeigt damit laufende Netzwerkaktivität statt eines reinen Verbunden/Getrennt-Zustands. Für dieses Projekt genau so gewünscht (bestätigt 2026-07-18).

## 8. Zeitzone (Europe/Berlin, Sommerzeit)

⚠️ **Fallstrick, live gefunden (2026-07-18):** `TimeStd`/`TimeDst` waren bereits korrekt mit den EU-DST-Standardregeln vorbelegt (letzter Sonntag März/Oktober), trotzdem zeigte die Lokalzeit nur UTC+1 statt der im Sommer korrekten UTC+2 (CEST) — betraf nicht nur die Anzeige, sondern auch **jede zeitbasierte Logik im Berry-Skript** (24h-Ringpuffer für Regen/Luftdruck-Trend, Nachtruhe-Fenster). Ursache: `Timezone` stand nicht auf `99` (= "nutze TimeStd/TimeDst-Regeln"), sondern auf einem festen Offset ohne Sommerzeit-Umstellung. Fix:

```
Timezone 99
```

Danach `Status 7` prüfen — `"Timezone":99` und die Lokalzeit muss der tatsächlichen Sommer-/Winterzeit entsprechen (Sunrise/Sunset-Werte in der gleichen Antwort sind ein guter Plausibilitäts-Check).

## 9. Nachtruhe (Display + Status-LED 22:00–08:00 aus)

Realisiert in [firmware/berry/autoexec.be](../firmware/berry/autoexec.be) über `QUIET_START_HOUR`/`QUIET_END_HOUR` (Standard 22/8) — schaltet `DisplayDimmer` und `LedState` stündlich neu (`tasmota.add_cron("0 0 * * * *", ...)`), damit ein Neustart mitten in der Nachtruhe sich selbst korrigiert.

⚠️ **Fallstrick, live gefunden (2026-07-18):** Ein direkter Check beim Booten (in `init()`) griff auf `tasmota.rtc()['local']` zu, **bevor** NTP synchronisiert war (Epoch nahe 0 = 1970) — das lieferte Stunde 0 und löste fälschlich sofort Nachtruhe aus (Display/LED gingen nach jedem Neustart kurz aus, unabhängig von der echten Uhrzeit). Fix: `tasmota.set_timer(15000, ...)` für den ersten Check, zusätzlich Plausibilitätsprüfung (`epoch < 1000000000` → NTP noch nicht bereit → erneut in 15s versuchen).

## 10. MQTT + Home Assistant

MQTT-Zugangsdaten sind projektintern, **nicht** in diesem öffentlichen Repo dokumentiert (siehe Betriebs-Notizen). Wichtig für die HA-Anbindung:

- `SetOption19 1` aktiviert Tasmotas **eigenes** Discovery-Format unter `tasmota/discovery/<MAC>/config` — das ist **nicht** das generische `homeassistant/<component>/.../config`-Schema, das die Standard-„MQTT"-Integration in Home Assistant erwartet. Für automatische Entity-Erstellung braucht es die **dedizierte "Tasmota"-Integration** in HA (separat von der generischen MQTT-Integration, aber auf derselben MQTT-Verbindung aufbauend).
- Home Assistant erstellt Entities aus jedem Feld der periodischen `tele/.../SENSOR`-JSON automatisch (z.B. `sensor.tasmota_ds18b20_temperature`, `sensor.tasmota_counter_c1`, `sensor.tasmota_as3935_distance_2`). Eigene Berechnungswerte (Windgeschwindigkeit/-richtung, Regenmenge 24h) existieren nur im Berry-Skript-Speicher fürs OLED — damit sie ebenfalls per MQTT/HA sichtbar werden, müssen sie explizit in die SENSOR-JSON eingespeist werden.
- Dafür in der Berry-`Driver`-Klasse eine `json_append()`-Methode ergänzen (analog zu `web_sensor()`, aber für MQTT statt Web-UI):
  ```berry
  def json_append()
    tasmota.response_append(string.format(',"IceWeather":{"WindSpeed":%.2f,"WindDir":%d,"Rain24h":%.2f}',
      self.wind_ms, dir, self.rain_24h()))
  end
  ```
  Erzeugt automatisch `sensor.tasmota_iceweather_windspeed` usw. in HA, ohne HA-seitige Template-Sensoren duplizieren zu müssen.

Ergebnis im Home-Assistant-Dashboard `lovelace-wetter` (Tab „Aktuell"): eigener Kasten „🏠 IceWeatherstation (lokal, nicht online)" mit grünem Rahmen, klar von der Online-Wetterquelle (DWD/API oben im Dashboard) unterschieden.

Weiter mit dem [Setup-Guide](setup-guide.md) für die komplette Schritt-für-Schritt-Anleitung inklusive Home-Assistant-Einbindung.
