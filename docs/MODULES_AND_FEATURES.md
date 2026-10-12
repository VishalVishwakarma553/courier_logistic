# Modules and Features List

**Deliverable #3** · Companion documents: [Architecture](ARCHITECTURE.md), [Database design](../database/DATABASE_DESIGN.md), [Courier feasibility](COURIER_FEASIBILITY.md)

This is the complete list of what the platform will contain, written so the client can check nothing is missing and nothing extra is assumed.

**How to read the tags**
- **Who:** 👤 Customer · 🛠 Admin / staff · ⚙ System (runs automatically)
- **Phase:** P0 = working demo · P1–P4 = later phases (see §4)
- **Scope:** **Asked** = in the client's requirement document · **Added** = our recommendation; the client can accept or drop it

---

## 1. Summary

| # | Module | Who | Phase | Features | Effort (dev-days) |
|---|---|---|---|---|---|
| 1 | Login & user access | 👤 🛠 | P0 | 9 | 8 |
| 2 | Customer management | 🛠 | P0–P1 | 9 | 6 |
| 3 | Courier management | 🛠 | P0–P1 | 10 | 7 |
| 4 | Rate engine & rate cards | 🛠 ⚙ | P1 | 12 | 15 |
| 5 | Shipment booking | 👤 🛠 | P0 | 14 | 12 |
| 6 | Bulk booking (Excel) | 👤 | P1 | 6 | 6 |
| 7 | AWB & shipping labels | ⚙ 👤 | P0 | 8 | 6 |
| 8 | Pickup management | ⚙ 🛠 | P1 | 8 | 5 |
| 9 | Tracking | ⚙ 👤 🛠 | P0–P2 | 12 | 10 |
| 10 | Admin control tower | 🛠 | P1 | 10 | 10 |
| 11 | Customer panel | 👤 | P0–P3 | 10 | 8 |
| 12 | Wallet & payments | 👤 🛠 | P3 | 9 | 8 |
| 13 | Billing & GST invoicing | 🛠 ⚙ | P3 | 10 | 12 |
| 14 | COD management | 🛠 👤 | P3 | 7 | 7 |
| 15 | Courier bills & profit | 🛠 | P3 | 6 | 6 |
| 16 | Reports & exports | 🛠 👤 | P3 | 11 | 8 |
| 17 | Notifications | ⚙ 🛠 | P1 | 8 | 7 |
| 18 | Support tickets | 👤 🛠 | P3 | 6 | 4 |
| 19 | International shipments | 👤 🛠 | P4 | 11 | 10 |
| 20 | System administration | 🛠 | P1 | 8 | 6 |
| 21 | Manual courier workflow | 🛠 ⚙ | P2 | 7 | 6 |
| 22 | Courier integrations (12 couriers + tracking service) | ⚙ | P0–P4 | 13 | 76 |
| 23 | Technical foundation | ⚙ | P0 | 9 | 12 |
| 24 | UI/UX design | — | P0–P1 | 5 | 10 |
| | **Total** | | | **218** | **≈ 265** |

> **About the effort numbers:** these are **build days for one developer**, without testing, project management or buffer. The full timeline (#6) adds those, and splits the work across the team, so calendar time will be much shorter than 265 days.

---

## 2. Modules in detail

### Module 1 · Login & user access — P0 · 8 days
| Feature | Who | Scope |
|---|---|---|
| Secure login with email/mobile and password | 👤 🛠 | Asked |
| Forgot / reset password (email or OTP) | 👤 🛠 | Asked |
| Roles: Super Admin, Operations, Accounts, Support, Customer | 🛠 | Asked |
| Permission settings per role, editable without a developer | 🛠 | Asked |
| Two-factor login (required for Super Admin) | 🛠 | Added |
| Customer sub-users (e.g. owner + booking staff) | 👤 | Added |
| Account lock after repeated wrong passwords | ⚙ | Added |
| Log out from all devices / session list | 👤 🛠 | Added |
| Login history | 🛠 | Added |

### Module 2 · Customer management — P0–P1 · 6 days
| Feature | Who | Scope |
|---|---|---|
| Create, edit and block customers | 🛠 | Asked |
| Company details, GSTIN, PAN, billing address | 🛠 | Asked |
| Prepaid (wallet) or credit customer, with credit limit and days | 🛠 | Asked |
| KYC document upload and verification | 🛠 | Added |
| Address book: saved pickup and delivery addresses | 👤 | Added |
| Choose which couriers/services each customer can use | 🛠 | Asked |
| Assign rate card or markup per customer | 🛠 | Asked |
| Assign an account manager | 🛠 | Added |
| Customer profile view with bookings, balance and tickets | 🛠 | Added |

### Module 3 · Courier management — P0–P1 · 7 days
| Feature | Who | Scope |
|---|---|---|
| Add a new courier company without a developer* | 🛠 | Asked |
| Add courier services (Surface, Express, etc.) | 🛠 | Asked |
| Enter API credentials securely (stored encrypted) | 🛠 | Asked |
| Enable / disable a courier or service | 🛠 | Asked |
| Shows what each courier supports automatically vs manually | 🛠 | Asked |
| Serviceable pincode upload (Excel) | 🛠 | Added |
| Status code mapping (courier code → our status) | 🛠 | Added |
| AWB number series upload (manual couriers) | 🛠 | Added |
| Register pickup addresses with couriers that need it | ⚙ | Added |
| Test connection button for credentials | 🛠 | Added |

\* *A courier **with an API** needs a one-time developer adapter (see Module 22). After that, everything is configured from this screen. A **manual** courier needs no developer at all.*

### Module 4 · Rate engine & rate cards — P1 · 15 days
| Feature | Who | Scope |
|---|---|---|
| Courier-wise purchase rates | 🛠 | Asked |
| Customer-wise selling rates | 🛠 | Asked |
| Domestic and international rates | 🛠 | Asked |
| Zones (local, state, metro, rest of India, special areas) | 🛠 | Asked |
| Weight slabs and minimum freight | 🛠 | Asked |
| Volumetric weight (L × B × H) | ⚙ | Asked |
| Fuel surcharge and other charges | 🛠 | Asked |
| COD charges | 🛠 | Asked |
| Remote area (ODA) and special handling charges | 🛠 | Asked |
| GST calculation | ⚙ | Asked |
| Profit margin per customer (markup) | 🛠 | Asked |
| Rate card upload from Excel, with start and end dates | 🛠 | Added |

### Module 5 · Shipment booking — P0 · 12 days
| Feature | Who | Scope |
|---|---|---|
| Sender and receiver details with full address | 👤 | Asked |
| Pickup and delivery pincode (city/state auto-filled) | 👤 | Asked |
| Document or parcel | 👤 | Asked |
| Actual weight and dimensions | 👤 | Asked |
| Shipment type: Prepaid, COD, To Pay, Reverse Pickup, International | 👤 | Asked |
| Invoice value and document upload (invoice, e-way bill) | 👤 | Asked |
| Special handling instructions | 👤 | Asked |
| Automatic serviceability check | ⚙ | Asked |
| Courier options with price and delivery estimate | 👤 | Asked |
| Sort options by cheapest / fastest | 👤 | Added |
| Select a courier and confirm the booking | 👤 | Asked |
| Multi-piece shipments | 👤 | Added |
| Cancel a booking before pickup (with refund) | 👤 | Added |
| Admin can book on behalf of a customer | 🛠 | Asked |

### Module 6 · Bulk booking (Excel) — P1 · 6 days
| Feature | Who | Scope |
|---|---|---|
| Download the Excel template | 👤 | Asked |
| Upload many shipments at once | 👤 | Asked |
| Row-by-row checking with an error report | ⚙ | Added |
| Courier choice rule: cheapest, fastest or preferred | 👤 | Added |
| Progress shown while processing | 👤 | Added |
| Bulk label download | 👤 | Added |

### Module 7 · AWB & shipping labels — P0 · 6 days
| Feature | Who | Scope |
|---|---|---|
| Automatic AWB through the courier API | ⚙ | Asked |
| AWB from a pre-allotted series (manual couriers) | ⚙ | Asked |
| Shipping label with barcode | ⚙ | Asked |
| Label PDF download and print (4×6 thermal and A4) | 👤 | Asked |
| Booking confirmation to the customer | ⚙ | Asked |
| Shipment saved to booking history | ⚙ | Asked |
| Pickup manifest sheet (list of shipments handed over) | 👤 🛠 | Added |
| Label with customer's logo | 👤 | Added |

### Module 8 · Pickup management — P1 · 5 days
| Feature | Who | Scope |
|---|---|---|
| Automatic pickup request to the courier | ⚙ | Asked |
| Pickup ID, date and address shown | 👤 🛠 | Asked |
| Status: pending, scheduled, picked up, failed | 👤 🛠 | Asked |
| Alert when a pickup request fails | 🛠 | Asked |
| Manual pickup request where there's no API | 🛠 | Asked |
| Customer can request a pickup | 👤 | Asked |
| Same-day shipments grouped into one pickup | ⚙ | Added |
| Reschedule a pickup | 👤 🛠 | Added |

### Module 9 · Tracking — P0–P2 · 10 days
| Feature | Who | Scope |
|---|---|---|
| All 12 tracking statuses from the requirement | ⚙ | Asked |
| Automatic updates by courier webhooks | ⚙ | Asked |
| Automatic updates by regular checking (polling) | ⚙ | Asked |
| One tracking page: enter AWB, see status and full history | 👤 | Asked |
| Track all couriers in one place | 👤 🛠 | Asked |
| Track several AWBs at once | 👤 | Added |
| Customer's shipment list with live status | 👤 | Asked |
| Expected delivery date and delay detection | ⚙ | Asked |
| Manual status correction by admin | 🛠 | Asked |
| Tracking update by Excel upload (manual couriers) | 🛠 | Added |
| Tracking service for couriers without a tracking API | ⚙ | Added |
| Failed-delivery (NDR) handling: customer chooses re-attempt or return | 👤 🛠 | Added |

### Module 10 · Admin control tower — P1 · 10 days
| Feature | Who | Scope |
|---|---|---|
| Totals: all bookings, today's bookings | 🛠 | Asked |
| Pickup pending, picked up, in transit, out for delivery, delivered | 🛠 | Asked |
| Delivery exceptions, RTO, COD shipments | 🛠 | Asked |
| Courier-wise booking report | 🛠 | Asked |
| Customer-wise booking report | 🛠 | Asked |
| Pending pickup alerts | 🛠 | Asked |
| Delayed shipment alerts | 🛠 | Asked |
| Search by AWB, customer name, mobile, courier, date, status | 🛠 | Asked |
| Shipment detail page with full history and courier API logs | 🛠 | Asked |
| Click any number to see the shipments behind it | 🛠 | Added |

### Module 11 · Customer panel — P0–P3 · 8 days
| Feature | Who | Scope |
|---|---|---|
| Dashboard: today's bookings, in transit, delivered, balance | 👤 | Added |
| Book new shipments | 👤 | Asked |
| Create pickup requests | 👤 | Asked |
| Download AWB and labels | 👤 | Asked |
| Live tracking | 👤 | Asked |
| Previous bookings with filters | 👤 | Asked |
| Download invoices | 👤 | Asked |
| COD details and settlement status | 👤 | Asked |
| Wallet balance, ledger and payment history | 👤 | Asked |
| Raise support tickets | 👤 | Asked |

### Module 12 · Wallet & payments — P3 · 8 days
| Feature | Who | Scope |
|---|---|---|
| Wallet recharge online (Razorpay / Cashfree) | 👤 | Asked |
| Automatic deduction on booking | ⚙ | Asked |
| Automatic refund on cancellation or failed booking | ⚙ | Added |
| Offline payment entry by admin (NEFT, cheque, cash) | 🛠 | Asked |
| Credit limit check for credit customers | ⚙ | Asked |
| Ledger statement with download | 👤 🛠 | Asked |
| Low balance alert | ⚙ | Added |
| Manual adjustment with reason (admin only) | 🛠 | Added |
| Payment history | 👤 | Asked |

### Module 13 · Billing & GST invoicing — P3 · 12 days
| Feature | Who | Scope |
|---|---|---|
| Customer-wise billing | 🛠 | Asked |
| Automatic invoice generation per billing cycle | ⚙ | Asked |
| GST calculation (CGST + SGST or IGST) | ⚙ | Asked |
| Invoice PDF with GST details | ⚙ | Asked |
| Credit customer management | 🛠 | Asked |
| Payment entries against invoices | 🛠 | Asked |
| Outstanding report and ageing | 🛠 | Asked |
| Credit notes (corrections) | 🛠 | Added |
| Payment reminders by email/WhatsApp | ⚙ | Added |
| GST e-invoice (IRN) — only if the client's turnover requires it | ⚙ | Added (+4 days) |

### Module 14 · COD management — P3 · 7 days
| Feature | Who | Scope |
|---|---|---|
| COD amount and status on every COD shipment | 👤 🛠 | Asked |
| Upload courier COD remittance file | 🛠 | Asked |
| Automatic matching of remittance to shipments | ⚙ | Asked |
| Unmatched or short-paid COD flagged | 🛠 | Added |
| COD payout to customers, with UTR | 🛠 | Asked |
| Customer view of COD settlement | 👤 | Asked |
| COD reports | 🛠 | Asked |

### Module 15 · Courier bills & profit — P3 · 6 days
| Feature | Who | Scope |
|---|---|---|
| Courier purchase bills entry/upload | 🛠 | Asked |
| Match bill lines to shipments | ⚙ | Added |
| Weight difference (courier charged more) flagged | 🛠 | Added |
| Customer selling bills | 🛠 | Asked |
| Profit per shipment, customer and courier | 🛠 | Asked |
| Profit and loss report | 🛠 | Asked |

### Module 16 · Reports & exports — P3 · 8 days
| Feature | Who | Scope |
|---|---|---|
| Booking report | 🛠 👤 | Asked |
| Courier-wise report | 🛠 | Asked |
| Customer-wise report | 🛠 | Asked |
| Delivery performance (on-time %, RTO %) per courier | 🛠 | Added |
| COD report | 🛠 👤 | Asked |
| Outstanding report | 🛠 | Asked |
| GST report | 🛠 | Added |
| Profit and loss report | 🛠 | Asked |
| Excel export | 🛠 👤 | Asked |
| PDF export | 🛠 👤 | Asked |
| Large exports prepared in the background | ⚙ | Added |

### Module 17 · Notifications — P1 · 7 days
| Feature | Who | Scope |
|---|---|---|
| SMS notifications | ⚙ | Asked |
| WhatsApp notifications | ⚙ | Asked |
| Email notifications | ⚙ | Asked |
| Events: booking, AWB, pickup, in transit, out for delivery, delivered | ⚙ | Asked |
| Message templates editable by admin | 🛠 | Added |
| Customer chooses which notifications to send | 👤 | Added |
| Sent / delivered / failed log | 🛠 | Added |
| Internal alerts to staff (failed pickups, delays) | ⚙ | Added |

### Module 18 · Support tickets — P3 · 4 days
| Feature | Who | Scope |
|---|---|---|
| Raise a ticket or complaint, linked to a shipment | 👤 | Asked |
| Categories (delay, damage, weight dispute, billing) | 👤 | Added |
| Assign to staff | 🛠 | Added |
| Conversation on the ticket with attachments | 👤 🛠 | Added |
| Status: open, in progress, resolved, closed | 👤 🛠 | Added |
| Internal staff-only notes | 🛠 | Added |

### Module 19 · International shipments — P4 · 10 days
| Feature | Who | Scope |
|---|---|---|
| Origin and destination country | 👤 | Asked |
| International service availability | ⚙ | Asked |
| Actual and volumetric weight | 👤 ⚙ | Asked |
| Item list with declared value | 👤 | Asked |
| HS codes | 👤 | Asked |
| Commercial invoice generation | ⚙ | Asked |
| Customs documents upload | 👤 | Asked |
| International shipping charges | ⚙ | Asked |
| International AWB | ⚙ | Asked |
| Customs clearance status | ⚙ | Asked |
| International tracking and delivery confirmation | ⚙ | Asked |

### Module 20 · System administration — P1 · 6 days
| Feature | Who | Scope |
|---|---|---|
| Users and permissions | 🛠 | Asked |
| Platform settings (company details, invoice prefix, label size) | 🛠 | Added |
| Courier API failure log | 🛠 | Asked |
| Webhook log | 🛠 | Asked |
| Background job monitor with retry | 🛠 | Added |
| Audit log (who changed what) | 🛠 | Added |
| Manual booking and tracking correction | 🛠 | Asked |
| Data backup and recovery (managed) | ⚙ | Asked |

### Module 21 · Manual courier workflow — P2 · 6 days
Used by every courier, or courier feature, that has no API. Built once.
| Feature | Who | Scope |
|---|---|---|
| Serviceable pincode list from Excel | 🛠 | Asked |
| AWB allotted from series | ⚙ | Asked |
| Our own label | ⚙ | Asked |
| Pickup task list for operations staff | 🛠 | Asked |
| Tracking update by form or Excel | 🛠 | Asked |
| Clear "manual" badge where a step isn't automatic | 👤 🛠 | Asked |
| Low AWB stock alert | ⚙ | Added |

### Module 22 · Courier integrations — P0–P4 · 76 days
| Courier | Phase | Expected level | Days |
|---|---|---|---|
| Delhivery | P0 | Fully automatic | 6 |
| Blue Dart | P2 | Fully automatic | 8 |
| SkyKing | P2 | Likely automatic | 6 |
| Madhur | P2 | Likely automatic | 6 |
| Shree Maruti | P2 | Partly automatic | 4 |
| The Professional Couriers | P2 | Partly automatic | 4 |
| Shree Anjani | P2 | Mostly manual | 2 |
| DHL Express | P4 | Fully automatic | 8 |
| FedEx | P4 | Fully automatic | 10 |
| UPS | P4 | Fully automatic | 8 |
| Aramex | P4 | Fully automatic | 7 |
| Skynet | P4 | Partly automatic | 4 |
| Tracking service (TrackingMore / AfterShip) | P2 | — | 3 |

### Module 23 · Technical foundation — P0 · 12 days
Not visible to users, but required for everything else: project setup, database and migrations, AWS hosting, automatic deployment (CI/CD), background job system, file storage, error monitoring, security setup, courier adapter framework.

### Module 24 · UI/UX design — P0–P1 · 10 days
Screen designs for customer panel, admin panel and tracking page; mobile-friendly layouts; design system (colours, buttons, forms); PWA install support; label and invoice templates.

---

## 3. What is NOT included (unless the client asks)
To avoid misunderstandings, these are **outside the current scope**:
- Native Android / iOS apps (the platform works on mobile browsers and can be installed as a PWA)
- Customer-facing public API for booking from customers' own websites/ERPs (*can be added in a later phase*)
- Integrations with e-commerce platforms (Shopify, WooCommerce, Amazon)
- Courier rider / delivery-boy app
- Warehouse management or inventory
- Full accounting software (Tally export can be discussed)
- Courier contracts, rate negotiation and courier account opening (done by the client)
- Third-party fees: SMS, WhatsApp, payment gateway, tracking service, AWS hosting

---

## 4. Phases at a glance
| Phase | Delivers |
|---|---|
| **P0 · Working demo** | Login, customer setup, booking, Delhivery AWB + label, tracking page, basic customer panel |
| **P1 · Core operations** | Rate engine, bulk booking, pickups, admin control tower, notifications, system admin |
| **P2 · Domestic couriers** | Blue Dart, regional couriers, manual courier workflow, tracking service |
| **P3 · Money** | Wallet, payments, invoicing, COD, courier bills, reports, support |
| **P4 · International** | DHL, FedEx, UPS, Aramex, Skynet, customs and commercial invoice |

---

## 5. Questions for the client
1. Please mark any **"Added"** feature you don't want. Removing them reduces cost and time.
2. Is anything from **§3 (not included)** actually needed now?
3. Should failed-delivery (NDR) handling be included in phase 2? It reduces returns significantly.
4. Is GST e-invoicing (IRN) required for the client's turnover?
