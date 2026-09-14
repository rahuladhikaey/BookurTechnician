# BookurTechnician Monorepo Workspace

This repository is structured as a cross-platform multi-app monorepo containing the frontend and administration applications for **BookurTechnician**, an on-demand service marketplace for carpenters, electricians, and handymen.

## Directory Structure

```
bookurtechnician/
│
├── apps/
│   ├── customer_app/         # Native Android (Kotlin, Jetpack Compose, M3)
│   ├── technician_app/       # Flutter Technician console (Dart, Riverpod, Dio)
│   └── admin_panel/          # React/Vite admin dashboard console
│
├── packages/
│   ├── core/                 # Shared core utilities
│   ├── design_system/        # Shared color tokens, sizing and radius standards
│   ├── networking/           # Shared API clients and networking interceptors
│   ├── authentication/       # Shared secure token schemas and validation contracts
│   ├── payments/             # Shared payment gateway APIs and billing tax calculators
│   ├── maps/                 # Shared tracking metrics and ETA visual overlays
│   ├── notifications/        # Shared push notification schemas
│   ├── analytics/            # Shared navigation events analytics
│   ├── storage/              # Shared caching and local storage managers
│   └── models/               # Shared JSON schemas for bookings and requests
│
├── docs/
│   ├── architecture/         # Clean Architecture flowcharts & patterns
│   └── business_rules/       # Core guidelines for OTP, prices, and rescheduling
│
└── README.md                 # Monorepo startup manual
```

---

## Getting Started

### 1. Customer Application (Native Android)
*   **Location**: `apps/customer_app`
*   **Build**: Open `apps/customer_app` directly in **Android Studio**.
*   **Run**: Build and run on an Android device or emulator. Includes an embedded simulation panel to test live technician tracking states offline.

### 2. Technician Console (Flutter)
*   **Location**: `apps/technician_app`
*   **Setup**:
    ```bash
    cd apps/technician_app
    flutter pub get
    ```
*   **Run**: `flutter run` on an emulator or device. Features availability status toggles, incoming job accept/reject triggers, map ETAs, and server-side OTP start check simulators.

### 3. Administrator Console (Web Panel)
*   **Location**: `apps/admin_panel`
*   **Setup**:
    ```bash
    cd apps/admin_panel
    npm install
    ```
*   **Run**: `npm run dev` to start local web server. Displays live bookings timeline, KYC approvals checklist, OTP audit logs, and forwarded-service rescheduling controllers.
