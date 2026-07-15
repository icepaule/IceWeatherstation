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

1. GPIO35 in *Konfiguriere Modul* auf **„ADC Input Range"** stellen (GPIO34/Windfahne bleibt auf normalem „ADC Input", Rohwert)
2. Danach den Range-Befehl setzen (Syntax verifiziert gegen [Tasmota ADC-Dokumentation](https://tasmota.github.io/docs/ADC/), Stand v15.5.0):

```
AdcParam1 6,600,2600,300,1300   // Typ 6=linear Range; ADCin 0,6-2,6V(mV) -> Output 30,0-130,0 dBA (x0.1)
```

`AdcParam1` bezieht sich auf den **ersten** ADC-Pin, der im Modul auf „Range" gestellt ist — falls das nicht GPIO35 ist (z.B. weil in der Modul-Konfiguration eine andere Reihenfolge entsteht), mit `Status 10` prüfen, welcher Analog-Kanal (`A1`, `A2`, …) tatsächlich den dBA-Wert zeigt.

## 4. Windfahne (Potentiometer → Richtung)

Keine native Tasmota-Umrechnung vorhanden. Zwei Optionen:

1. **Klassische Rules** mit ADC-Schwellwert-Vergleichen (`ON Analog#A1>x DO ... ENDON`) — einfacher, aber unübersichtlich bei 8 Richtungen mit Übergangsbereichen
2. **Berry-Skript mit Lookup-Tabelle** (empfohlen) — übersichtlicher, einfacher zu kalibrieren. Siehe [firmware/berry/autoexec.be](../firmware/berry/autoexec.be)

Die Datenblatt-Spannungswerte der SparkFun-Windfahne sind laut mehreren Quellen in der Praxis ungenau — **nach dem Aufbau mit einer Wasserwaage/Kompass real durchmessen und die Lookup-Tabelle anpassen.**

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

Weiter mit dem [Setup-Guide](setup-guide.md) für die komplette Schritt-für-Schritt-Anleitung inklusive Home-Assistant-Einbindung.
