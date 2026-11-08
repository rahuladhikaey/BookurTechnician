# Phase 5 — Central Service Catalog Forensic Audit

**Project:** BookurTechnician  
**Firebase Project:** `bookmytechnician-53d94`  
**Region:** `asia-south1`  
**Firebase Plan:** Spark (Free)  
**Audit Date:** November 8, 2026  

---

## 1. Executive Summary

A complete forensic audit of the **BookurTechnician** service catalog across the **Customer Flutter App**, **Technician Flutter App**, **React Admin Panel**, **Node.js Backend**, and **Cloud Firestore** revealed that **158 canonical customer services** exist across **8 primary categories** and **21 subcategories**.

Prior to Phase 5:
- Customer App (`apps/customer_app_flutter/lib/booking_provider.dart` and `services/firestore_rest_client.dart`) relied on static hardcoded fallback definitions that did not track a central `catalogVersion` or enforce `isActive` service status during checkout.
- Technician App (`apps/technician_app/lib/features/onboarding/data/skill_service.dart`) used legacy `sk_*` identifiers (such as `sk_ac_installation` and `sk_deep_cleaning_service`) that were not normalized to the canonical catalog `serviceId` (`ac_install`, `ac_deep_cleaning`), causing live availability mismatches when customers searched for `AC installation`.
- Admin Panel (`apps/admin_panel/src/features/services/ServicesManager.jsx`) lacked subcategory filtering, active/disabled status filtering, pagination, and a 1-click enable/disable toggle.

All **158 services** have been centralized into one authoritative catalog architecture (`service_categories/{categoryId}` and `services/{serviceId}`) with a monotonically increasing `catalogVersion`, canonical IDs (`canonicalServiceId`), persistent audit logging, and real-time synchronization across all platforms.

---

## 2. Category & Subcategory Inventory (8 Categories, 21 Subcategories, 158 Services)

| # | Category ID | Category Name | Subcategories | Total Services | Display Order |
|---|---|---|---|---|---|
| 1 | `cat_electrical` | Electrical Services | `sub_fan` (4), `sub_switch_socket` (3), `sub_lighting` (5), `sub_mcb_fuse` (5), `sub_elec_install` (5) | **22** | 1 |
| 2 | `cat_wiring` | Home Wiring & Projects | `sub_house_wiring` (9), `sub_board_panel` (7), `sub_power_setup` (9), `sub_safety_grounding` (5) | **30** | 2 |
| 3 | `cat_ac` | AC Services | `sub_ac_service_maint` (5), `sub_ac_repair_install` (12) | **17** | 3 |
| 4 | `cat_refrigerator` | Refrigerator Services | `sub_fridge_all` (12) | **12** | 4 |
| 5 | `cat_washing` | Washing Machine Services | `sub_wm_all` (12) | **12** | 5 |
| 6 | `cat_computer` | Laptop & Computer | `sub_laptop` (15), `sub_desktop` (8), `sub_network` (5) | **28** | 6 |
| 7 | `cat_cctv` | CCTV & Security | `sub_cctv_install` (7), `sub_cctv_repair` (8), `sub_cctv_system_setup` (7), `sub_smart_security` (6) | **28** | 7 |
| 8 | `cat_appliances` | Home Appliances | `sub_other_appliances` (9) | **9** | 8 |
| **Total** | **8 Categories** | — | **21 Subcategories** | **158 Services** | — |

---

## 3. Authoritative Schema Architecture

### 3.1 `service_categories/{categoryId}`
- `categoryId` (`string`): Canonical category key (e.g., `cat_ac`, `cat_electrical`).
- `name` (`string`): Display name (e.g., `AC Services`).
- `icon` (`string`): Material icon key (e.g., `ac_unit`, `electrical_services`).
- `imageUrl` (`string`): Verified CDN image asset URL.
- `displayOrder` (`number`): Deterministic sort order (`1..8`).
- `isActive` (`boolean`): Whether the category is visible and bookable.
- `subcategories` (`array`): Nested subcategory metadata (`id`, `name`, `displayOrder`, `isActive`).
- `catalogVersion` (`number`): Global catalog version counter.
- `createdAt` / `updatedAt` (`ISO-8601 timestamp`).

### 3.2 `services/{serviceId}`
- `serviceId` / `id` (`string`): Unique service document ID (e.g., `ac_install`, `fan_rep`).
- `canonicalServiceId` (`string`): Authoritative cross-platform key shared by Customer App, Technician App skills, and Admin Panel.
- `name` (`string`): Customer-facing title (e.g., `AC installation`).
- `categoryId` / `categoryName` (`string`): Parent category reference.
- `subcategoryId` / `subcategoryName` (`string`): Parent subcategory reference.
- `basePrice` (`number`): MRP / original price before discount (e.g., `1624`).
- `discountPrice` (`number`): Active customer offer price (e.g., `1299`).
- `bookingCharge` (`number`): Platform visitation/inspection fee.
- `advancePrepaymentPct` (`number`): Required prepayment percentage (`30%`).
- `technicianPayoutAmount` (`number`): Guaranteed partner payout share.
- `durationMinutes` (`number`): Estimated job completion time.
- `warrantyText` (`string`): Customer service warranty guarantee (`30 Days Warranty` – `180 Days Warranty`).
- `description` (`string`): Detailed scope of work.
- `icon` / `imageUrl` (`string`): Service visual representation.
- `isActive` (`boolean`): Controls whether customers can view and book the service.
- `displayOrder` (`number`): Order within subcategory.
- `usageCount` / `bookingCount` (`number`): Cumulative booking demand metrics.
- `createdAt` / `updatedAt` (`ISO-8601 timestamp`).
- `updatedBy` (`string`): Admin UID that last modified the service.

---

## 4. Canonical Skill ↔ Service Normalization

To prevent technician skill mismatches (such as the `Ram` / `BT-988363` live availability issue for `AC installation`), all legacy skill identifiers are deterministically mapped to `canonicalServiceId`:

| Legacy Skill ID / Name | Normalized `canonicalServiceId` | Canonical Service Name | Category ID |
|---|---|---|---|
| `sk_ac_installation`, `ac installation` | `ac_install` | `AC installation` | `cat_ac` |
| `sk_deep_cleaning_service`, `deep cleaning service` | `ac_deep_cleaning` | `Deep cleaning service` | `cat_ac` |
| `sk_ac_repair`, `ac repair` | `ac_repair_general` | `AC repair` | `cat_ac` |
| `sk_ac_pcb_repair`, `ac pcb repair` | `ac_pcb_repair` | `AC PCB repair` | `cat_ac` |
| `sk_ac_relocation`, `ac relocation` | `ac_relocation` | `AC relocation` | `cat_ac` |
| `sk_ac_general_servicing`, `ac general servicing` | `ac_general_service` | `AC general servicing` | `cat_ac` |
| `sk_ac_gas_charging`, `ac gas charging` | `ac_gas_charging` | `AC gas charging/refilling` | `cat_ac` |
| `sk_ac_uninstallation`, `ac uninstallation` | `ac_uninstall` | `AC uninstallation` | `cat_ac` |
| `sk_ceiling_fan_repair`, `fan repair` | `fan_rep` | `Fan repair` | `cat_electrical` |
| `sk_mcb_repair`, `mcb repair` | `mcb_rep` | `MCB repair/replacement` | `cat_electrical` |
| `sk_full_house_wiring`, `full house wiring` | `house_wiring_new` | `Full house wiring` | `cat_wiring` |

