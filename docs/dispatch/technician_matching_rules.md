# BookurTechnician — Technician Eligibility & Smart Ranking Rules

## 1. 10 Mandatory Eligibility Conditions
Before any technician can be ranked or receive a booking offer, `evaluateTechnicianEligibility()` in `backend/node-core-service/src/services/automaticDispatchEngine.js` enforces all 10 mandatory checks:

| # | Condition | Enforcement Rule | Exclusion Reason Code |
|---|---|---|---|
| 1 | **Account Verified** | `kyc_status` must be `'VERIFIED'` or `'APPROVED'` | `KYC_NOT_VERIFIED` |
| 2 | **Account Active** | `account_status === 'Active'` and `is_active !== false` | `ACCOUNT_INACTIVE` |
| 3 | **Not Suspended** | `is_suspended === false` and `is_cod_suspended === false` | `TECHNICIAN_SUSPENDED` |
| 4 | **Onboarding Completed** | `onboarding_completed !== false` | `ONBOARDING_INCOMPLETE` |
| 5 | **Required Service Skill** | Verified active entry in `technician_service_skills` / `technician_services` / `skills` matching requested `serviceId` or `category` | `SKILL_AND_CATEGORY_MISMATCH` |
| 6 | **Supports Service Location** | Distance `<= currentRadiusKm` AND `<= technician.service_radius_km` (default 15 km) | `OUTSIDE_SEARCH_RADIUS_<N>KM` |
| 7 | **Available at Date & Time** | Instant: `is_online === true` and `availability_status === 'AVAILABLE'`. Scheduled: appointment window falls within `technician_availability` working hours (`start_time`–`end_time`) and outside `unavailable_from`–`unavailable_until` | `TECHNICIAN_OFFLINE` / `OUTSIDE_WORKING_HOURS` |
| 8 | **No Conflicting Active Booking** | Zero active ongoing jobs (for instant) and zero overlapping scheduled appointments in `bookings` | `ACTIVE_ONGOING_BOOKING_<ID>` / `OVERLAPPING_TIME_SLOT_WITH_<ID>` |
| 9 | **Valid Recent GPS Coordinates** | Non-zero `latitude` `[-90,90]` & `longitude` `[-180,180]` updated within `gpsFreshnessThresholdSeconds` | `INVALID_OR_MISSING_GPS_COORDINATES` / `STALE_GPS_COORDINATES` |
| 10 | **Registered Valid FCM Token** | Non-empty device token that is not synthetic (`fake_`, `mock_`, `dummy_`, `synthetic_`, `tech_fcm_`, `fcm_` rejected) | `NO_VALID_FCM_TOKEN` |

---

## 2. Progressive Radial Search Policy
Search radius expands sequentially when no eligible technician accepts within the current tier:
- **Tier 1 (Initial Radius):** `3 km`
- **Tier 2 (Second Radius):** `5 km`
- **Tier 3 (Third Radius):** `10 km`
- **Tier 4 (Maximum Radius):** `15 km`

All radius tiers are configurable at runtime by Admin via `PUT /api/v1/admin/dispatch/config`.

---

## 3. Multi-Factor Smart Ranking Formula
Eligible technicians are scored on a `[0.0000, 1.0000]` scale using Admin-configurable weights:

$$\text{Score} = 0.35 \cdot S_{\text{ETA/Dist}} + 0.25 \cdot S_{\text{Skill}} + 0.20 \cdot S_{\text{Avail}} + 0.10 \cdot S_{\text{Rating}} + 0.10 \cdot S_{\text{Reliability}}$$

Where:
- $S_{\text{ETA/Dist}} = \max\left(0, 1 - \frac{\text{distanceKm}}{\text{maxRadiusKm}}\right)$ (35% weight)
- $S_{\text{Skill}} = 1.00$ for exact verified `service_id` match, $0.95$ for service name match, $0.85$ for category match (25% weight)
- $S_{\text{Avail}} = 1.00$ when free in the requested window (20% weight)
- $S_{\text{Rating}} = \frac{\text{rating}}{5.0}$ (10% weight)
- $S_{\text{Reliability}} = \frac{\text{acceptanceRate}}{100.0}$ (10% weight)

Every offer stores both `ranking_score` and the full JSON `ranking_reasons` breakdown in `dispatch_offers` for auditability.

