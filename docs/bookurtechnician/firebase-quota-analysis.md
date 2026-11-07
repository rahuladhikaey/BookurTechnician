# Firebase Quota & Location Tracking Analysis

**Target Project:** `bookmytechnician-53d94` (Cloud Firestore, region `asia-south1`)  
**Current Plan:** Spark (Free Tier)  
**Required Plan:** Blaze (Pay-as-you-go)

---

## 1. Spark Plan Quota Limits

Google Cloud Firestore imposes hard daily caps on the free Spark tier:

| Operation | Spark Daily Free Limit | Daily Cost on Spark | Action When Limit Hit |
|---|---|---|---|
| **Document Reads** | 50,000 reads / day | ₹0 | Hard block (`HTTP 429 RESOURCE_EXHAUSTED`) |
| **Document Writes** | 20,000 writes / day | ₹0 | Hard block (`HTTP 429 RESOURCE_EXHAUSTED`) |
| **Document Deletes** | 20,000 deletes / day | ₹0 | Hard block (`HTTP 429 RESOURCE_EXHAUSTED`) |
| **Stored Data** | 1 GiB total | ₹0 | Writes rejected (`QUOTA_EXCEEDED`) |
| **Network Egress** | 10 GiB / month | ₹0 | Connection rejected |

> [!WARNING]
> On the Spark plan, when the 20,000 write limit is reached, Firebase shuts down the database API until midnight US Pacific Time (13:30 IST). During this time, **no technician can register, no skills can be saved to Firestore, and no customer can retrieve live availability**.

---

## 2. Realistic Usage Math per Technician

Let us calculate the exact Firestore write volume per technician per 8-hour shift.

### Stationary Mode (Idle waiting for jobs)
* Heartbeat interval: **3 minutes (180 seconds)**.
* Heartbeats per hour: 20 writes.
* During 4 idle hours: **80 writes**.

### Active Moving Mode (En route to customer)
* Movement distance threshold: **30 meters**.
* Minimum time threshold: **60 seconds**.
* Maximum pings per hour: 60 writes.
* During 4 transit hours: **240 writes**.

### Total Daily Writes per Active Technician
$$\text{Total Writes per Tech} = 80 + 240 + 10 \text{ (status toggles, duty, skills)} = \mathbf{330 \text{ writes/day}}$$

---

## 3. Capacity Limit on Spark Plan

$$\text{Maximum Active Technicians on Spark} = \frac{20,000 \text{ total allowed writes}}{330 \text{ writes per tech}} \approx \mathbf{60 \text{ Technicians}}$$

With 60 active technicians, the Spark plan's 20,000 write quota is **100% consumed**. Any additional test device, admin panel refresh, or customer booking will immediately trigger `HTTP 429 RESOURCE_EXHAUSTED`.

---

## 4. Why Did the Quota Exhaust Today?

1. **Pre-throttling Location Tracking:** Prior to the throttling fix, `location_tracking_service.dart` used a 15-second background heartbeat and 5m distance threshold ($240 \text{ writes/hr} \times 8 = 1,920 \text{ writes/day/device}$).
2. **Customer App Availability Polling:** The catalog screen polled availability every 10 seconds. Each read executed `listCollection('service_categories')` and `listCollection('technician_profiles')`, consuming dozens of document reads per minute.
3. **Repeated Test Suite Execution:** Automated integration scripts repeatedly executed collection scans without in-memory caching.

---

## 5. Blaze Plan Economics

Upgrading to the Blaze plan retains the **exact same free daily allowances**:
* First 50,000 reads/day: **₹0.00 (Free)**
* First 20,000 writes/day: **₹0.00 (Free)**
* First 20,000 deletes/day: **₹0.00 (Free)**
* First 1 GiB storage: **₹0.00 (Free)**

### Cost of Exceeding Quotas on Blaze:
* 100,000 extra writes: ~\$0.18 (~₹15 INR).
* 100,000 extra reads: ~\$0.06 (~₹5 INR).

For less than ₹100/month, the platform can support hundreds of technicians without ever blocking users with `HTTP 429`.

---

## 6. Action Required to Restore Database

1. Open [Firebase Console - Usage & Billing](https://console.firebase.google.com/project/bookmytechnician-53d94/usage).
2. Click **Modify Plan** and select **Blaze (Pay as you go)**.
3. Associate a billing account with Google Cloud.
4. Set a monthly budget alert (e.g. ₹500 INR) to ensure zero unexpected charges.

