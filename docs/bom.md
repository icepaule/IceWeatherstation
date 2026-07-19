# Teileliste (BOM)

Für **zwei baugleiche Geräte**. Wo nichts anderes vermerkt ist, gilt die Menge pro Gerät (also ×2 bestellen).

> Preise sind Momentaufnahmen (Stand 2026-07-15) und können abweichen — vor der Bestellung selbst prüfen. Amazon-Wunschlisten zeigen beim Einfügen automatisch die aktuellen Preise an, deshalb sind hier bewusst nicht überall feste Preise hinterlegt.

## Kernkomponenten

| # | Bauteil | Modell | Menge | Bezugsquelle | Hinweis |
|---|---|---|---|---|---|
| 1 | Mikrocontroller | ESP32-WROOM-**32U**/32UE DevKitC V4, USB-C, externe Antenne (U.FL/IPEX) | 2× | Amazon.de / AZ-Delivery / AliExpress, Suche „ESP32-WROOM-32U DevKitC external antenna“ | **Bewusst 32U/32UE statt Standard-32E** — Standardmodul hat nur PCB-Antenne, keine externe Buchse |
| 2 | WLAN-Antenne | 2,4 GHz 3 dBi Antenne + U.FL/IPEX-zu-SMA-Pigtail | 2× | Amazon.de, Suche „U.FL IPEX SMA Pigtail 2.4GHz Antenne ESP32“ | Nicht direkt an Metallteilen montieren, freie Sichtlinie im Gehäuse |
| 3 | Temp/Feuchte/Druck | Bosch **BME280** I2C-Breakout (z.B. AZDelivery GY-BME280) | 2× | Amazon.de / AZ-Delivery | SDA→GPIO21, SCL→GPIO22 |
| 3b | Wetterschutz BME280 | TFA Dostmann Schutzhülle für Sender, weiß, 10,2×9,5×17,5cm | 2× | [Amazon.de](https://www.amazon.de), 12,99€/Stk. (Stand 2026-07-19) | Schützt vor Niederschlag/Sonneneinstrahlung bei guter Luftzirkulation — unter dem Hauptgehäuse montiert, damit BME280 nicht durch Eigenerwärmung des Gehäuses verfälschte Werte liefert |
| 4 | Zusatz-Temperatur | **DS18B20** Edelstahl-Sonde, wasserdicht, 1m Kabel | 2× | Amazon.de / AZ-Delivery „DS18B20 waterproof“ | GPIO4, 4,7 kΩ Pull-up gegen 3,3V nötig |
| 5 | Wind/Regen/Windrichtung | **SparkFun Weather Meter Kit SEN-15901** | 2× | [DigiKey](https://www.digikey.de/de/products/detail/sparkfun-electronics/SEN-15901/11570533) oder [Mouser.de](https://www.mouser.de) | Auf Amazon.de/eBay nicht sinnvoll verfügbar (nicht lieferbar bzw. deutlich überteuert). RJ11-Steckkabel. Lieferzeit vor Bestellung prüfen |
| 6 | Blitzsensor (Franklin) | **AS3935** / CJMCU-3935-Modul | 2× (ggf. 1× wenn ein Modul aus einem Vorgängerprojekt wiederverwendet wird) | AliExpress / Amazon.de „CJMCU-3935 AS3935“ | Läuft zuverlässig per **I2C** (abweichend von manchen Herstellerhinweisen, die nur SPI empfehlen — bei diesem Klon in der Praxis bewährt). EMI-empfindlich: sauberes Netzteil, kein Steckbrett, Antenne freihalten |
| 7 | Schallpegel (dBA, kalibriert) | DFRobot Gravity **SEN0232** (teils als „V2.0” verkauft), 30–130 dBA, ±1,5 dB, A-bewertet | 2× | Europäischer Distributor (z.B. Botland, DigiKey) — **nicht** über Amazon.de bestellen | ⚠️ Auf Amazon.de kursiert ein ähnlich benanntes, aber **unkalibriertes** „Analog Sound Sensor”-Modul — das ist **nicht** dasselbe Bauteil. Analog, nicht I2C. Die im Handel oft als „V2.0” gelabelte Variante ist laut [DFRobot-Wiki](https://wiki.dfrobot.com/sen0232/) hard- und softwareseitig identisch zur SEN0232 (kein eigenes Datenblatt, keine geänderte Formel/Pinbelegung) — Doku in diesem Repo gilt unverändert |
| 7b | Wetterschutz Mikrofon | 25mm-Elektroinstallationsrohr + 90°-Bogen, M20 IP68-Kabelverschraubung, Schaumstoff-Windschutz | 2× | Baumarkt (Rohr/Bogen) + Elektrofachhandel (Kabelverschraubung) + Amazon.de (Windschutzschaum) | Details: [enclosure.md](enclosure.md) |

## Gehäuse, Montage, Strom

| # | Bauteil | Menge | Hinweis |
|---|---|---|---|
| 8 | Elektronik-Gehäuse, Polycarbonat/ABS, ~200×120×75mm, IP65 | 2× | Reicht für ESP32 + BME280 + AS3935 + dBA-Modul + Klemmleisten |
| 9 | Kabelverschraubungen IP68, M12/M16/M20/M25 gemischt | 1× Sortiment (deckt beide Geräte) | Je eine Verschraubung für: Wetterkabel-Bündel, DS18B20-Sonde, Stromkabel; fürs Mikrofon separate belüftete Lösung (siehe 7b) |
| 10 | Mast/Rohrhalterung, Aluminium, U-Bolzen | 2× | Windfahne/Anemometer brauchen freien, ungestörten Luftstrom |
| 11 | Stromversorgung: wetterfeste 5V/USB-Zuleitung | 2× | Zuverlässiger als Solar, insbesondere wegen kontinuierlicher Last durch AS3935 + dBA-Sensor |
| 11b | *Alternative:* Solar (6V/1W-Panel + TP4056-Lademodul + 18650-Zelle) | optional | Nur wenn kein Kabelweg möglich — kein Low-Power-Projekt, Akku großzügig dimensionieren |

## Kleinteile

| # | Bauteil | Menge | Hinweis |
|---|---|---|---|
| 12 | Widerstands-Sortiment (u.a. 4,7 kΩ) | 1× Sortiment | Für DS18B20-Pullup |
| 13 | Schraub-/Verbindungsklemmen, Dupont-Kabel, Schrumpfschlauch | 1× Sortiment | Saubere, wartbare Verkabelung im IP65-Gehäuse |
| 14 | Silikagel-Beutel, wiederverwendbar | 1× Packung | Gegen Kondenswasser im geschlossenen Gehäuse |
| 15 | SSD1306 OLED 0,96" I2C (optional) | 2× | Alternative/Ergänzung zum Web-UI — direkt ablesbar ohne Browser, siehe [setup-guide.md](setup-guide.md) |

## Erweiterungssensoren (geplant, 2026-07-19)

Alle nativ von Tasmota unterstützt, kein Custom-Treiber nötig. **Keiner davon gehört ins TFA-Dostmann-Schutzgehäuse** (Punkt 3b) — das ist speziell fürs Blocken von Sonne/Regen bei gleichzeitig freier Luftzirkulation für den BME280 gebaut; Sensoren, die selbst freie Sicht zum Himmel brauchen (Licht/UV), würden dort ja genau das verlieren, wovor das Gehäuse schützt.

| # | Bauteil | Modell | Menge | Bezugsquelle | Hinweis |
|---|---|---|---|---|---|
| 16 | Helligkeit (Lux) | **BH1750** I2C-Breakout | 2× | Amazon.de / AZ-Delivery | I2C, teilt sich den bestehenden Bus (GPIO21/22) — braucht freie Sicht zum Himmel, NICHT im Schutzgehäuse (Punkt 3b) montieren |
| 17 | UV-Index | **VEML6070** I2C-Breakout | 2× | Amazon.de / AliExpress | I2C, gleicher Bus — ebenfalls freie Sicht zum Himmel nötig, NICHT im Schutzgehäuse |
| 18 | Feinstaub (PM2,5/PM10) | **PMS5003** oder **PMS7003** | 2× | Amazon.de / AZ-Delivery | UART (2 GPIOs, z.B. GPIO16/17), braucht **eigenes** belüftetes Gehäuse mit Lüfter-Ansaugung — andere Bauform als der BME280-Strahlungsschutz, nicht kombinierbar |
| 19 | Gassensor (Luftqualität) | **MQ135** (bereits vorhanden, 2× im Bestand) | 2× vorhanden | — | Siehe Hinweis unten — braucht 5V + Spannungsteiler, teils drinnen/teils draußen sinnvoll |

### MQ135-Hinweise (2× bereits vorhanden)

⚠️ **MQ135 braucht zwingend Luftaustausch mit der zu messenden Umgebung** — das Sensorelement (beheiztes SnO₂) reagiert chemisch mit der umgebenden Luft. In einem **vollständig geschlossenen** Gehäuse misst er nur die eingeschlossene Luft darin, nicht die Außenluft.

Sinnvolle Aufteilung für die zwei vorhandenen Module:
- **Ein MQ135 im geschlossenen Hauptgehäuse** — hier bewusst *ohne* Außenluftkontakt, als interner Sicherheits-/Ausgasungs-Detektor (erkennt z.B. eine überhitzende Batterie/Verkabelung) — genau dafür ist ein geschlossenes Gehäuse hier richtig, da die Innenraumluft selbst überwacht werden soll
- **Der zweite MQ135 extern** für echte Außenluftqualität — braucht eigenes belüftetes UND wettergeschütztes Gehäuse (Feuchtigkeit/Regen schadet dem Sensorelement dauerhaft, anders als beim BME280 aber ohne dessen einfache "nur Luft, kein Wasser"-Anforderung — MQ-Sensoren vertragen dauerhafte Nässe generell schlecht)

⚠️ **Hardware-Details:**
- Heizer braucht **5V** (nicht 3,3V) — separate 5V-Versorgung, nicht vom ESP32-3,3V-Pin
- Analogausgang kann laut Datenblatt **über 3,3V** ansteigen — zwingend Spannungsteiler vor dem ESP32-ADC-Pin nötig (z.B. 10 kΩ + 15 kΩ), sonst Risiko für den ADC-Eingang
- Kontinuierlicher Heizer-Stromverbrauch **~150–200 mA pro Modul** (2× ≈ 300–400 mA zusätzlich einplanen — Netzteil-Dimensionierung prüfen, kein Low-Power-Sensor)
- **24–48h Einbrennzeit** nötig, bevor Messwerte einigermaßen stabil sind; nach jedem Stromausfall erneut 3–5 Minuten Aufwärmzeit
- Tasmota unterstützt MQ135 nativ über den generischen `ADC`-Gassensor-Typ (`AdcParam` mit `ANALOG_MQ_TYPE`), Kalibrierung gegen bekannte Frischluft nötig
- Grundsätzlich eher als Innenraum-Luftqualitätssensor konzipiert — bei Außeneinsatz (Temperatur-/Feuchte-Schwankungen) mit reduzierter Genauigkeit rechnen

## Warum SparkFun statt MISOL-Fertigsensorik?

Kurzfassung: MISOL-Sets sind für den eigenen Funk-Empfänger gebaut, nicht für direkten GPIO-Anschluss. Details und Alternativwege: [misol-compatibility.md](misol-compatibility.md).

## Quellen

- [SparkFun Weather Meter Kit SEN-15901 Hookup Guide](https://learn.sparkfun.com/tutorials/weather-meter-hookup-guide)
- [Original-Datenblatt Shenzhen Fine Offset Electronics (RJ11-Pinbelegung)](https://cdn.sparkfun.com/assets/d/1/e/0/6/DS-15901-Weather_Meter.pdf) — Quelle für die RJ11-Pin-Tabelle in [wiring.md](wiring.md)
- [DFRobot Gravity SEN0232 Wiki](https://wiki.dfrobot.com/Gravity_Analog_Sound_Level_Meter_SKU_SEN0232)
- [Bosch BME280 Datenblatt](https://www.bosch-sensortec.com/products/environmental-sensors/humidity-sensors-bme280/)
- [AS3935 Datenblatt (AMS/TE)](https://look.ams-osram.com/m/6ff54cea1cf87dc2/original/AS3935-Franklin-Lightning-Sensor-IC.pdf)
