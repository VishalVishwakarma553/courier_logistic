# Courier API Feasibility Report

**Deliverables #4 (API feasibility, courier by courier) and #5 (documentation and credentials per courier)**
Status: based on public information as of October 2026. Every item marked "confirm" must be checked with the courier's account manager once business accounts are opened.

---

## 1. The short answer

**Yes, the platform is feasible.** But not every courier can be fully automatic on day one:

- **6 couriers can be fully automatic** (booking → AWB → label → pickup → tracking): Delhivery, Blue Dart, DHL, FedEx, UPS, Aramex.
- **2 regional couriers can very likely be fully automatic**, because they give APIs to business clients, just not publicly: SkyKing, Madhur.
- **3 couriers can have automatic tracking, but booking may need to be manual** until they confirm a booking API: Shree Maruti, The Professional Couriers, Skynet.
- **1 courier will be mostly manual**: Shree Anjani. No API was found, and tracking is possible only through a third-party tracking service.

This matches the client's own requirement (§15): *"Where the courier's API doesn't support a feature, the system must clearly show that limitation and give a manual fallback."*

---

## 2. Summary table

**Legend:** ✅ Available by API · 🟡 Likely available, confirm with courier · 🔁 Through a third-party tracking service · ✋ Manual in our system

| Courier | Pincode check | Rates / ETA | Booking + AWB | Label | Pickup request | Tracking | Overall | Build effort* |
|---|---|---|---|---|---|---|---|---|
| **Delhivery** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** | 5–7 days |
| **Blue Dart** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** | 7–10 days |
| **DHL Express** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** | 7–10 days |
| **FedEx** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** (label approval needed) | 8–12 days |
| **UPS** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** | 7–10 days |
| **Aramex** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | **Fully automatic** | 6–8 days |
| **SkyKing** | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 / 🔁 | **Likely automatic** | 5–8 days |
| **Madhur** | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 | 🟡 / 🔁 | **Likely automatic** | 5–8 days |
| **Shree Maruti** | ✋ | ✋ | 🟡 / ✋ | ✋ (we print) | ✋ | 🟡 / 🔁 | **Partly automatic** | 3–5 days |
| **Professional** | ✋ | ✋ | 🟡 / ✋ | ✋ (we print) | ✋ | 🟡 / 🔁 | **Partly automatic** | 3–5 days |
| **Skynet** | ✋ | ✋ | 🟡 / ✋ | 🟡 | ✋ | 🟡 / 🔁 | **Partly automatic** | 3–5 days |
| **Shree Anjani** | ✋ | ✋ | ✋ | ✋ (we print) | ✋ | 🔁 / ✋ | **Mostly manual** | 1–2 days |

\* *Developer days for that courier only, including testing. The shared manual workflow (used by every courier that lacks an API) is built once: about 5–7 days.*

---

## 3. What "manual" actually means for the customer

Even for a manual courier, **the customer's experience stays almost the same**. The difference is on the operations side:

| Step | Automatic courier | Manual courier |
|---|---|---|
| Pincode check | Live from the courier | From a pincode list the admin uploads (Excel) |
| Price | Our rate engine (same for both) | Our rate engine (same for both) |
| AWB number | Courier API gives it instantly | Taken from a pre-allotted AWB series the courier gives us in advance |
| Label | Courier's label or ours | Our system prints the label with barcode |
| Pickup | Requested automatically | A pickup task appears for operations staff, who call or message the courier |
| Tracking | Automatic updates | Through a tracking service (TrackingMore, AfterShip...) if it covers the courier, otherwise staff update by Excel upload |

The customer still books online, gets an AWB and label immediately, and sees tracking on the same page.

---

## 4. Courier by courier

### 4.1 Delhivery: fully automatic ✅
- **How to get the API:** open a business account with Delhivery (Delhivery One). The API token is in the client panel's developer/API settings, or ask the account manager.
- **Credentials you receive:** API token; registered pickup location (warehouse) name; client name.
- **Testing:** a staging (test) environment is available.
- **Available:** pincode serviceability, shipping cost, create shipment, AWB, label (packing slip), pickup request, tracking, cancel, NDR (failed delivery) actions.
- **Notes:** each pickup address must first be registered as a "warehouse" in Delhivery. Our system can do this automatically.
- **Recommended:** build first. This is the courier for the **working demo**.

### 4.2 Blue Dart: fully automatic ✅
- **How to get the API:** open a Blue Dart customer account through sales or a branch, then register on the **Blue Dart API Gateway** portal and link your customer code.
- **Credentials you receive:** customer code, area code, login ID, license key, and a Client ID + Client Secret (used to get an access token).
- **Testing:** sandbox access through the API Gateway.
- **Available:** location finder (pincode check), transit time, waybill (AWB) generation, pickup registration, tracking, cancel.
- **Notes:** older Blue Dart services use SOAP (an older style of API), which takes slightly longer to build. COD and some products need separate activation on your account. Confirm with the account manager.

### 4.3 DHL Express: fully automatic ✅ (international)
- **How to get the API:** requires a DHL Express account number. Register at **developer.dhl.com** and request access to the **MyDHL API**.
- **Credentials you receive:** API key + API secret, DHL account number.
- **Testing:** test environment provided.
- **Available:** rates, transit time, shipment + label, pickup booking, tracking, customs documents (commercial invoice, paperless trade).
- **Notes:** international shipments need item details, HS codes and declared values. Our database already stores these.

### 4.4 FedEx: fully automatic ✅ (label approval needed)
- **How to get the API:** requires a FedEx account number. Create a project at **developer.fedex.com**.
- **Credentials you receive:** Client ID + Client Secret (OAuth), FedEx account number.
- **Testing:** sandbox provided.
- **Available:** rates, ship + label, pickup, tracking, address validation.
- **Notes:** **FedEx checks sample labels before allowing production use.** Plan 1–2 weeks for this approval. Start early.

### 4.5 UPS: fully automatic ✅
- **How to get the API:** requires a UPS account number. Create an app at **developer.ups.com**.
- **Credentials you receive:** Client ID + Client Secret (OAuth), UPS account number.
- **Testing:** test environment provided.
- **Available:** rating, shipping + label, pickup, tracking.
- **Notes:** confirm which UPS services are available for India origin through your account.

### 4.6 Aramex: fully automatic ✅
- **How to get the API:** ask your Aramex account manager for API access and documentation.
- **Credentials you receive:** username, password, account number, account PIN, account entity, account country code.
- **Testing:** test credentials provided on request.
- **Available:** rate calculator, shipment creation + label, pickup, tracking.
- **Notes:** many credential fields. All are stored encrypted in the admin panel.

### 4.7 SkyKing: likely automatic 🟡
- **What we found:** integration platforms (ClickPost) list full SkyKing integration: order creation, label, pickup, cancel, tracking by API and webhooks, delivery estimates. AfterShip also offers SkyKing tracking. This means **SkyKing gives APIs to business clients, but not publicly**.
- **How to get the API:** ask the SkyKing head office (not a local franchise) for **API documentation and credentials** for a corporate account.
- **Credentials:** confirm (usually an API key or username/password plus a client code).
- **If they refuse:** use the manual workflow for booking, and a tracking service for tracking.

### 4.8 Madhur Courier: likely automatic 🟡
- **What we found:** ClickPost lists Madhur with order creation, AWB/label, pickup, cancel, tracking and delivery estimates. **The API exists but is given privately.**
- **How to get the API:** ask Madhur's head office IT/corporate team for API access.
- **Credentials:** confirm.
- **If they refuse:** manual workflow plus a tracking service.

### 4.9 Shree Maruti: partly automatic 🟡
- **What we found:** tracking for Shree Maruti is offered by several tracking services (ClickPost, TrackingMore, Ship24). **No booking API was found publicly.**
- **Plan:** ask Shree Maruti's corporate team whether they offer a booking/AWB API. Until confirmed: **manual booking with a pre-allotted AWB series**, plus **automatic tracking through a tracking service**.

### 4.10 The Professional Couriers: partly automatic 🟡
- **What we found:** tracking is covered by ClickPost and TrackingMore. **No booking API found publicly.**
- **Plan:** same as Shree Maruti. Ask for a corporate API; meanwhile manual booking plus automatic tracking through a tracking service.

### 4.11 Skynet: partly automatic 🟡
- **What we found:** tracking is covered by AfterShip, ClickPost and TrackingMore, and ClickPost lists label generation. Order creation **does not appear** to be available through ClickPost. Some shipping software connects to Skynet with an account token issued by Skynet.
- **Plan:** ask Skynet India whether they issue an API token for booking. Until confirmed: manual booking plus automatic tracking.

### 4.12 Shree Anjani: mostly manual ✋
- **What we found:** no official API. Only third-party tracking services (TrackingMore) list Shree Anjani.
- **Plan:** full manual workflow: uploaded pincode list, pre-allotted AWB series, our own labels, pickup tasks for staff, and tracking through TrackingMore if it proves reliable, otherwise Excel updates.
- **Still ask:** the head office may have an internal system that can share data by Excel or email every day. Even a daily Excel tracking file can be imported automatically.

---

## 5. Options for couriers without a booking API

| Option | How it works | Pros | Cons |
|---|---|---|---|
| **A. Manual workflow** (built into our system) | AWB series, our labels, staff pickup tasks, Excel tracking upload | No extra cost, works for any courier | Operations staff effort |
| **B. Tracking service** (TrackingMore, AfterShip, Ship24) | We send the AWB; they return tracking updates for 1,000+ couriers | Automatic tracking even without a courier API | Monthly fee (Ship24 lists plans from about $39 per 1,000 shipments a month); data reliability varies by courier |
| **C. Shipping platform** (ClickPost and similar) | One API for 150+ couriers, including some regional ones | Fast access to regional courier APIs | Monthly fee; adds a middle layer; may need the client's own courier accounts anyway |

**Recommendation:** **A + B.** Build the manual workflow once (needed anyway as a fallback) and add one tracking service for the couriers without tracking APIs. Consider C only if SkyKing, Madhur or others refuse direct API access.

---

## 6. Recommended integration order

| Order | Couriers | Why |
|---|---|---|
| **1 · Demo** | Delhivery | Easiest, well documented, quick to get a token. Proves the full flow end to end. |
| **2** | Manual workflow + Shree Anjani | Built once, then every non-API courier works immediately. |
| **3** | Blue Dart | Second major domestic courier. |
| **4** | SkyKing, Madhur | As soon as their API credentials arrive. |
| **5** | Shree Maruti, Professional, Skynet | Tracking service connection; booking APIs if confirmed. |
| **6 · International** | DHL → Aramex → UPS → FedEx | Start FedEx label approval early, since it takes the longest. |

---

## 7. Checklist: what to ask every courier

Send this to each courier's sales or account manager when opening the business account:

1. Do you provide an **API for business customers**? Please share the documentation.
2. Which of these can be done by API: **pincode check, rate/ETA, booking + AWB, label, pickup request, tracking, cancellation, failed delivery (NDR) actions, COD remittance report**?
3. Do you send **tracking updates to our server (webhooks)**, or do we need to check (poll)? Any limit on how often we can check?
4. Do you provide **test (sandbox) credentials** before live credentials?
5. Do we need to **whitelist our server's IP address**?
6. What **label format and size** is required (4×6 thermal or A4)? Can we print our own label?
7. If there's no booking API: can you give us a **pre-allotted AWB number series**?
8. How is **COD remitted** (frequency, report format)?
9. Is there any **charge for API access**?
10. Who is our **technical contact** for integration issues?

---

## 8. Documents and credentials list (deliverable #5)

| Courier | Where the documentation comes from | Credentials to collect |
|---|---|---|
| Delhivery | Delhivery One client panel / account manager | API token, warehouse (pickup location) names, client name |
| Blue Dart | Blue Dart API Gateway portal | Customer code, area code, login ID, license key, Client ID, Client Secret |
| DHL Express | developer.dhl.com (MyDHL API) | API key, API secret, account number |
| FedEx | developer.fedex.com | Client ID, Client Secret, account number |
| UPS | developer.ups.com | Client ID, Client Secret, account number |
| Aramex | Aramex account manager | Username, password, account number, PIN, entity, country code |
| SkyKing | Head office (private) | Confirm |
| Madhur | Head office (private) | Confirm |
| Shree Maruti | Corporate team; tracking via tracking service | Confirm; AWB series if no API |
| Professional | Corporate team; tracking via tracking service | Confirm; AWB series if no API |
| Skynet | Skynet India (account token) | Confirm; AWB series if no API |
| Shree Anjani | None found | AWB series; serviceable pincode list (Excel) |
| Tracking service (if chosen) | TrackingMore / AfterShip / Ship24 | One API key |

All credentials are entered by the Super Admin in the admin panel and stored encrypted. Developers never need to see live production secrets.

---

## 9. What the client needs to do next
1. **Open business accounts** with each courier (documents: GST certificate, PAN, company registration, cancelled cheque, KYC, expected monthly volume).
2. **Send the checklist in §7** to each courier and forward the replies to us.
3. **Start with Delhivery**: its token is enough to begin the working demo.
4. **Start FedEx and DHL account opening early**, since international account approval takes the longest.
5. **Decide on a tracking service** (Option B) once the regional couriers have replied.

---

## Sources (regional couriers, checked October 2026)
Mostly third-party integration and tracking providers, so every finding must be confirmed with the courier.
- [ClickPost: SkyKing](https://www.clickpost.ai/courier-integrations/skyking) · [ClickPost: Madhur](https://www.clickpost.ai/carrier-integration/madhur-courier-services) · [ClickPost: Shree Maruti](https://clickpost.ai/carrier-integration/shree-maruti-courier-service) · [ClickPost: Professional](https://clickpost.ai/tracking-api/professional-couriers) · [ClickPost: Skynet](https://www.clickpost.ai/tracking-api/skynet)
- [AfterShip: SkyKing](https://carriers.aftership.com/skyking) · [AfterShip: Skynet India](https://www.aftership.com/integrations/carriers/skynetworldwide-in)
- [TrackingMore: Shree Anjani](https://www.trackingmore.com/shreeanjanicourier-tracking) · [TrackingMore: Professional](https://www.trackingmore.com/professional-couriers-tracking-api.html)
- [Ship24: Shree Maruti](https://ship24.com/tracking-api/shree-maruti) · [DespatchCloud: Skynet](https://documentation.despatchcloud.com/books/courier-directory/page/skynet-worldwide-express)
