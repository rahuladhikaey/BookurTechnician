# Architecture Guidelines: Clean Architecture & State Flow

Both mobile applications inside this monorepo follow the principles of **Clean Architecture** to maintain a separation of concerns, making the code testable, modular, and easy to maintain.

---

## 1. Application Layering

The codebase is split into three main layers:

```
UI (Presentation) ──> State Holders (Riverpod / ViewModels) ──> Use Cases (Domain) ──> Repositories (Data) ──> HTTP/Dio Client ──> Backend APIs
```

### A. Data Layer (`data/`)
*   **APIs / Data Sources**: Network API callers (Dio, HTTP clients).
*   **DTOs (Data Transfer Objects)**: JSON serializers and network schemas.
*   **Repository Implementations**: Fetches data from remote servers or local caches, converting DTOs into clean Domain entities.

### B. Domain Layer (`domain/`)
*   **Entities**: Pure business data classes (e.g. `Booking`, `Service`, `Technician`) with no platform-specific code.
*   **Repository Interfaces**: Defines contracts for data fetch operations.
*   **Use Cases**: Encapsulates specific business actions (e.g. `VerifyStartOtpUseCase`, `SubmitAdditionalChargesUseCase`).

### C. Presentation Layer (`presentation/` or `ui/`)
*   **Widgets / Views**: Composable views (Flutter widgets or Jetpack Compose files).
*   **State Holders**: Riverpod `StateNotifier` classes or Android lifecycle `ViewModel` classes managing screen loading/empty/error states and coordinating UI triggers.

---

## 2. Platform Implementations

### Technician Console (Flutter)
- Uses **Riverpod** for modular state management, separating loading spinners, loaded lists, and error dialog states.
- Utilizes custom **Dio Interceptors** to automatically attach authentication headers (`Bearer Token`) and refresh tokens.
- Secure token encryption is handled via `flutter_secure_storage`.

### Customer App (Native Android)
- Built entirely using **Jetpack Compose** (Material 3) and Kotlin.
- Binds reactive `StateFlow` structures inside lifecycle-aware `ViewModel` objects.
- Embedded timeline status controls simulate real-time updates from technician devices (accepting, arriving, adding material bills).
