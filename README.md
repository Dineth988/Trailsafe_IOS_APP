# TrailSafe – iOS Outdoor Safety App


## App Overview

**TrailSafe** is an offline-first outdoor safety app designed for solo hikers, runners, walkers, and anyone moving through unfamiliar or poorly-lit areas.  

Unlike fitness or mapping apps, TrailSafe focuses purely on **personal safety**. It continuously tracks location offline, records trail sessions, detects risk situations on-device, and lets trusted contacts view the user’s live status through a temporary Live Share session.

### Core Pillars
1. Fully offline trail recording & storage  
2. On-device risk detection (stationary too long, leaving safe zone)  
3. Temporary Live Share with trusted contacts  

---

## MVP Features

| Feature | Description |
|---------|-------------|
| **Authentication & Onboarding** | Sign-up, login, and short onboarding flow |
| **Settings** | Face ID, daily check-in, notifications, data reset |
| **Dashboard (Home)** | Live map, quick stats, Start Trail button, always-visible SOS |
| **Live Share Backend** | Custom serverless API for sharing live location & status |
| **Push Notifications** | Weather alerts, stationary warnings, session complete, check-in reminders |
| **Face ID** | Biometric lock for sensitive safety data |
| **Trail Tracking + Safe Zone** | Offline GPS recording + circular safe-zone alerts |
| **Live Share & Contacts** | Manage trusted contacts and start temporary live sessions |
| **History & Stats** | Past sessions with distance, duration, pace, and charts |

---

## Advanced / Stretch Features
- Multiple concurrent safe zones + dedicated geofence creation screen  
- WidgetKit (Home Screen widget)  
- WeatherKit safety sheet  
- ActivityKit (Live Activity on Lock Screen / Dynamic Island)  
- CloudKit multi-device sync  

---

## Tech Stack
- **UI:** SwiftUI + MVVM  
- **Location & Maps:** Core Location, MapKit, Geofencing  
- **Storage:** Core Data (fully offline)  
- **Auth:** LocalAuthentication (Face ID / Touch ID)  
- **Notifications:** UserNotifications  
- **Backend:** Custom serverless API (Cloudflare Workers / Vercel)  
- **Extras:** WidgetKit, WeatherKit, ActivityKit, CloudKit
