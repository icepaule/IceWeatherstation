# Verkabelungskonzept

## Pin-Belegung (ESP32-WROOM-32U DevKitC V4)

| Funktion | GPIO | Typ | Hinweis |
|---|---|---|---|
| BME280 SDA | 21 | I2C | gemeinsamer Bus mit AS3935 |
| BME280 SCL | 22 | I2C | gemeinsamer Bus mit AS3935 |
| AS3935 SDA | 21 | I2C | gemeinsamer Bus mit BME280 |
| AS3935 SCL | 22 | I2C | gemeinsamer Bus mit BME280 |
| AS3935 IRQ | 25 | Interrupt | Blitzereignis-Trigger |
| DS18B20 | 4 | 1-Wire | 4,7 kΩ Pull-up gegen 3,3V |
| Regenmesser (SEN-15901) | 27 | Interrupt (Counter1) | Reed-Kontakt, Kippwaage |
| Anemometer (SEN-15901) | 14 | Interrupt (Counter2) | Reed-Kontakt |
| Windfahne (SEN-15901) | 34 | ADC1 | Spannungsteiler/Potentiometer |
| dBA-Sensor (SEN0232) | 35 | ADC1 | analoger Ausgang, 0,6–2,6V |

**Warum genau diese Pins:**
- I2C-Bus (BME280 + AS3935) bewusst auf 21/22 — Tasmota-Standardbelegung, spart Konfigurationsaufwand
- Alle ADC-Pins bewusst auf **ADC1** (GPIO32–39) — ADC2 ist bei aktivem WLAN auf dem ESP32 nicht zuverlässig nutzbar
- Rain/Wind auf getrennte Interrupt-fähige GPIOs, da beide unabhängig voneinander und potenziell gleichzeitig Pulse liefern

## Blockschaltbild

```mermaid
graph LR
    ESP32["ESP32-WROOM-32U<br/>DevKitC V4"]

    subgraph I2C-Bus [I2C-Bus – GPIO21/22]
        BME280["BME280<br/>Temp / Feuchte / Druck"]
        AS3935["AS3935<br/>Blitzsensor"]
    end

    DS18B20["DS18B20<br/>wasserdichte Temp-Sonde"]
    RAIN["Regenmesser<br/>SEN-15901"]
    ANEMO["Anemometer<br/>SEN-15901"]
    VANE["Windfahne<br/>SEN-15901"]
    DBA["SEN0232<br/>dBA-Sensor"]
    ANT["Externe WLAN-Antenne<br/>via U.FL"]

    ESP32 -->|SDA/SCL GPIO21/22| BME280
    ESP32 -->|SDA/SCL GPIO21/22| AS3935
    ESP32 -->|IRQ GPIO25| AS3935
    ESP32 -->|1-Wire GPIO4| DS18B20
    ESP32 -->|Interrupt GPIO27| RAIN
    ESP32 -->|Interrupt GPIO14| ANEMO
    ESP32 -->|ADC1 GPIO34| VANE
    ESP32 -->|ADC1 GPIO35| DBA
    ESP32 -.->|U.FL/IPEX| ANT
```

## Stromversorgung

```mermaid
graph TD
    MAINS["5V-Zuleitung<br/>(wetterfestes Kabel)"]
    USB["USB-Netzteil / USB-Buchse<br/>im Gehäuse"]
    ESP32V["ESP32 5V-Pin"]
    LDO["Onboard-LDO<br/>(auf DevKitC-Board)"]
    V33["3,3V-Schiene"]

    MAINS --> USB --> ESP32V --> LDO --> V33
    V33 --> BME280V["BME280"]
    V33 --> AS3935V["AS3935"]
    V33 --> DS18B20V["DS18B20"]
    V33 --> DBAV["SEN0232"]
```

**Hinweis Stromversorgung:** AS3935 und SEN0232 ziehen kontinuierlich Strom (kein reines Low-Power-Projekt). Bei der Solar-Alternative (siehe [bom.md](bom.md)) den Akku entsprechend großzügig dimensionieren.

## Verkabelungs-Reihenfolge (empfohlen)

1. Erst auf dem Breadboard alle Sensoren einzeln gegen den ESP32 testen (I2C-Scan für BME280/AS3935, `OneWire`-Scan für DS18B20, ADC-Rohwerte für Windfahne/dBA), **bevor** final ins Gehäuse verlötet/verklemmt wird
2. I2C-Bus zuerst (BME280 + AS3935) — beide Adressen per `I2CScan`-Kommando in Tasmota gegenprüfen (AS3935-Klone laufen oft auf Adresse `0x03`)
3. Danach 1-Wire (DS18B20), dann die beiden Interrupt-Leitungen (Regen/Wind), zuletzt die ADC-Leitungen (Windfahne/dBA)
4. Erst nach erfolgreichem Einzeltest final ins IP65-Gehäuse verkabeln (Zugentlastung an jeder Kabelverschraubung nicht vergessen)

Weiter mit: [tasmota-config.md](tasmota-config.md) für die Firmware-Seite dieser Verkabelung.
