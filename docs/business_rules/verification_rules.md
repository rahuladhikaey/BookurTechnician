# BookurTechnician Business Rules Specifications

To maintain platform safety, transaction security, and pricing consistency, the customer and technician applications must strictly adhere to the following business rules:

---

## Rule 1: Server-Calculated Price Authority
*   **Definition**: The frontend must never calculate the final invoice total or determine the cost of items locally.
*   **Workflow**:
    1.  Customer adds services to the cart or technician requests add-on materials.
    2.  The app sends item lists, user coordinates, and coupons to the server:
        `POST /bookings/calculate-price`
    3.  The backend server computes base rates, visit/service charges, tax percentages, and coupon discount logic.
    4.  The server returns the final price breakdown to the client for display.

---

## Rule 2: Server-Side Arrival OTP Verification
*   **Definition**: The technician cannot start service work without validating a customer-specific OTP code on the server.
*   **Workflow**:
    1.  When the technician arrives, the customer screen displays a 4-digit code (e.g. `4821`).
    2.  The technician inputs this code in their console app, triggering:
        `POST /bookings/{bookingId}/verify-start-otp`
    3.  The backend validates the code.
    4.  Only after the server responds `OTP_VERIFIED` will the status of both apps advance to `SERVICE_STARTED`. The app must never validate OTPs locally.

---

## Rule 3: Additional Work Approvals & Payments
*   **Definition**: All spare parts, additional labor, or materials found necessary during repairs must be approved and paid by the customer online before work starts.
*   **Workflow**:
    1.  Technician submits an add-on request: service type, quantity, reason, and price.
    2.  Customer receives a popup alert on their screen showing item details and reason.
    3.  Customer clicks **Approve & Pay**, executing an online transaction.
    4.  Backend validates the transaction and flags the add-on as `PAID`.
    5.  Technician is notified that work on the additional item is allowed.

---

## Rule 4: Rescheduling & Next-Day Forward Requests
*   **Definition**: If a job cannot be completed on the scheduled day, the technician must submit a formal rescheduling request with reasons.
*   **Workflow**:
    1.  Technician submits a forward request: delay reason (e.g., part unavailable), detailed explanation, and proposed completion date.
    2.  The booking status moves to `FORWARDED`.
    3.  A dedicated alert appears on the customer's home/booking tracker screen showing the rescheduling proposal details.
    4.  The customer has the final decision to **Approve Reschedule** (updates booking schedule date and resumes active status) or **Decline Request** (routes to admin dispute).
