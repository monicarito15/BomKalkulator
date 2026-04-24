# BomKalkulator

Norwegian toll calculator for iOS. Enter an origin and destination, and the app shows every toll station on your route with real-time prices — so you know the cost before you drive.

---

## Features

- Toll pricing from NVDB data
- Multiple alternative routes (up to 3) via OSRM and MapKit
- Directional toll filtering — only charges the correct direction (nordgående/sørgående)
- Rush hour surcharge detection using per-station times from NVDB (falls back to 06:30–09:00 and 15:00–17:00)
- Timesregel support — stations in the same group within 60 min: free (Første passering) or most expensive only (Dyreste passering)
- Vehicle type support: car and motorcycle
- Fuel type support: petrol, diesel, and electric — electric vehicles receive a 50% discount on the AutoPASS rate (Norwegian law minimum); petrol and diesel pay the standard AutoPASS rate
- 24-hour price cache with offline fallback and estimated price indicator
- Search history stored locally on device
- Recent address suggestions
- Nearby toll stations browser
- One-tap navigation via Apple Maps or Google Maps
- Dark mode support

---

## Pricing

- **Free:** 10 route searches per month
- **Unlimited:** 19 kr one-time purchase (StoreKit 2)

---

## Requirements

- iOS 18.5 or later
- Xcode 16 or later

---

## Setup

1. Clone the repository and open `toll-app.xcodeproj` in Xcode.
2. Build and run (Cmd+R).

On first launch the app downloads approximately 500 toll stations from NVDB and saves them locally. An internet connection is required for this initial load and for real-time pricing.

---

## Architecture

MVVM with SwiftUI and async/await throughout. No Combine.

```
Views
├── TravelView
├── MapView
├── CalculatorView
├── TollSummaryBarView
├── TollPassedListView
├── HistoryView
├── FromDirectionsView
├── ToDirectionsView
└── SettingsView

ViewModels
├── MapViewModel          — route calculation, toll detection, directional filtering
├── FeeViewModel          — pricing, cache, API calls
├── TollStorageViewModel  — toll data (SwiftData)
├── FeeStorageViewModel   — price cache (SwiftData)
└── SearchAddressViewModel — address autocomplete, recent searches

Services
├── TollService           — NVDB API
├── OSRMService           — OpenStreetMap routing (alternative routes)
└── LocationManager       — Core Location

Store
├── PurchaseManager       — StoreKit 2, free limit, monthly reset
└── PaywallView
```

---

## External APIs

**NVDB** (`nvdbapiles.atlas.vegvesen.no`)
Toll station locations and pricing data. Returns UTM coordinates (SRID 5973), converted to WGS84 via ArcGIS SDK. Updated monthly. No API key required.

**OSRM** (`router.project-osrm.org`)
OpenStreetMap-based routing. Returns up to 3 real alternative routes. Falls back to MapKit if unavailable. No API key required.

---

## Price Calculation Flow

```
User submits route
    → OSRM + MapKit calculate alternative polylines
    → Perpendicular distance check for each toll station (50m threshold)
    → Directional filter (nordgående/sørgående/østgående/vestgående)
    → Prices calculated from NVDB toll data (takst, rushtidstakst)
    → Stations with Operatør_Id 100120 (Vegamot) or 100149 (Ranheim) multiplied by 1.12 to correct outdated NVDB data
    → Timesregel applied per passeringsgruppe
    → Results cached for 24 hours
```

---

## Known Limitations

- NVDB prices are the AutoPASS rates (no additional AutoPASS discount is applied).
- Trondheim (Vegamot AS, operator 100120) and Ranheim (operator 100149) use a hardcoded 1.12× price correction — NVDB not updated since Feb 2024. Remove when NVDB is updated.
- Prices are based on NVDB data and may not reflect the latest AutoPASS rates. A disclaimer is shown in the route details sheet.
- First launch requires internet to download the toll station database.

---

## Planned Features

- **Timesregel notifications** — after passing a toll with an hourly-rule, send a push notification with a countdown timer: "Return before HH:MM and this toll is free." Requires CoreLocation geofencing + UserNotifications framework.

---

## License

MIT License — Copyright (c) 2026 Carolina Mera
