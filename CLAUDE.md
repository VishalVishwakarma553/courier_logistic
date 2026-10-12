# Courier ERP: Project Context

Read this first in any new conversation about this project. It summarises everything decided so far.

## 1. What this project is

A client wants a **Multi-Courier Booking, Tracking & ERP platform** for India. The original requirement document, in Hinglish, is [`../client_requirement.md`](../client_requirement.md).

- Customers log in, enter shipment details, compare couriers by price and delivery time, book, and get an AWB and label automatically.
- Pickup, tracking, notifications, billing, wallet and COD should be as automatic as possible.
- **Domestic couriers:** Shree Anjani, Shree Maruti, Delhivery, The Professional Couriers, SkyKing, Madhur, Blue Dart.
- **International couriers:** DHL Express, FedEx, Aramex, UPS, Skynet.
- Where a courier has no API, the system must **show the limitation clearly and offer a manual fallback** (client requirement §15).
- The client first wants a **working demo**: login, booking, AWB, tracking.

Before development starts, the client asked for **12 deliverables** (client_requirement.md §16). **All 12 are complete.** No application code has been written yet.

## 2. About the user and how to work with them

- The user is building this proposal for their company to send to the client, and is learning as they go.
- **Write in plain, simple language.** The user found the dense technical docs (architecture, database) hard to follow.
- **Keep each document to what its title promises.** For example, the timeline was cut down to dates only, with no risks, team options or calculations. Don't add extra sections unless asked.
- The user **cannot share private claude.ai artifact links** with the client. Always deliver a **standalone `.html` file** in `courier-erp/docs/` (include doctype, head, and a Mermaid CDN script if there are diagrams), plus a `.md` copy.
- The user writes in English and Hinglish. Reply in English.

## 3. Technical decisions (agreed)

| Area | Decision |
|---|---|
| Architecture | **Modular monolith** plus separate worker processes (services: web, api, worker, scheduler) |
| Frontend | **Next.js** (React, TypeScript), one PWA with customer, admin and public tracking areas |
| Backend | **NestJS** (TypeScript). Laravel + MySQL was noted as an alternative because the client mentioned PHP/MySQL. |
| Database | **PostgreSQL 16+** |
| Queues / cache | **Redis + BullMQ** |
| Files | AWS S3 |
| Hosting | **AWS Mumbai (ap-south-1)**: ECS Fargate, RDS Multi-AZ, ElastiCache, CloudFront + WAF, fixed outbound IP for courier whitelisting |
| Courier integration | **Adapter pattern**: one `CourierAdapter` interface per courier, with capability flags and a `ManualAdapter` for couriers without an API |
| Key flows | Booking holds the request up to 10 s for the AWB, otherwise it continues async. Failed AWB → auto refund. Tracking by webhooks plus adaptive polling. Statuses never move backwards. |
| Statuses | 18 normalised shipment statuses; each courier's codes are mapped through `courier_status_mappings` |
| Shipment type | The client's "Prepaid / COD / To Pay / Reverse / International" is split into `payment_mode`, `direction` and `is_international` |

## 4. Deliverables: status and files

Every document is in `courier-erp/docs/` as `.html` (for viewing and sending) plus `.md` (source), unless noted.

| # | Deliverable | Files | Key content |
|---|---|---|---|
| 1 | System architecture | `ARCHITECTURE.md`, `system-architecture.html` | 5 Mermaid diagrams, services, adapter interface, flows, queues, security, AWS deployment |
| 2 | Database design | `../database/schema.sql`, `../database/DATABASE_DESIGN.md`, `../database/erd.eraser`, `database-design.html` | 60 tables (5 partitioned monthly). The schema was validated on PGlite (PG17). `erd.eraser` is Eraser.io diagram-as-code with 104 relationships. |
| 3 | Modules & features | `MODULES_AND_FEATURES.md`, `modules-and-features.html` | 24 modules, 218 features (134 asked by the client, 57 added by us as optional), ≈ 265 developer-days for one developer. The HTML has an Asked/Added filter. |
| 4 + 5 | Courier API feasibility + credentials list | `COURIER_FEASIBILITY.md`, `courier-feasibility.html` | See §5 below |
| 6 | Timeline | `TIMELINE.md`, `timeline.html` | Simplified to dates only (see §6) |
| 7 | Development cost | `DEVELOPMENT_COST.md`, `development-cost.html` (editable calculator) | ₹46,12,500 team + 10% contingency = **₹50,73,750** + 18% GST = **₹59,87,025**. Generic market rates; the user will modify them later. |
| 8 | Hosting & maintenance | `HOSTING_AND_MAINTENANCE.md`, `hosting-and-maintenance.html` (editable) | At 30,000 shipments a month: hosting ₹58,600 + SMS/WhatsApp/tracking ₹48,000 + maintenance ₹70,000 = **₹1.77 lakh/month**, ₹21.2 lakh/year excl. GST |
| 9 | Testing & deployment | `TESTING_AND_DEPLOYMENT.md`, `testing-and-deployment.html` | 3 environments, 7 test types, night releases with rollback, go-live checklist with a pilot week |
| 10 | Code & DB ownership | `OWNERSHIP.md`, `ownership.html` | Client owns everything; code and AWS in the client's own accounts from day 1; no lock-in, no licence fees, NDA |
| 11 | Admin access & documentation | `HANDOVER_DOCUMENTATION.md`, `handover-documentation.html` | Access list, 9 guides, 5 recorded training sessions |
| 12 | Payment plan | `PAYMENT_PLAN.md`, `payment-plan.html` | Advance 15%, M1 10%, M2 15%, M3 15%, M4 10%, M5 10%, M6 15%, M7 5%, M8 5% of ₹50,73,750 + GST; due within 7 days of approval |

## 5. Courier feasibility summary

| Group | Couriers | Meaning |
|---|---|---|
| Fully automatic | Delhivery, Blue Dart, DHL, FedEx, UPS, Aramex | Public APIs for everything |
| Likely automatic | SkyKing, Madhur | APIs exist but are given privately to business clients (ClickPost lists full integration) |
| Partly automatic | Shree Maruti, Professional, Skynet | Tracking via third-party services is confirmed; a booking API is not confirmed |
| Mostly manual | Shree Anjani | No API found; manual workflow (AWB series, our own labels, staff pickup tasks, Excel/tracking-service updates) |

- **Recommended order:** Delhivery first (the demo) → manual workflow → Blue Dart → SkyKing/Madhur → the others → international.
- **FedEx** needs label certification, which takes 1–2 weeks.
- The report includes **10 questions to send every courier**.

## 6. Timeline (assumptions: start Monday 2 Nov 2026; 3 developers + QA + part-time designer/PM)

| Milestone | Week | Date |
|---|---|---|
| M1 Design sign-off | 2 | 13 Nov 2026 |
| M2 Working demo | 6 | 11 Dec 2026 |
| M3 Core operations | 12 | 22 Jan 2027 |
| M4 Domestic couriers | 16 | 19 Feb 2027 |
| M5 Billing & reports | 21 | 26 Mar 2027 |
| M6 **Platform launch (shipping within India)** | 23 | 9 Apr 2027 |
| M7 **International shipping added** | 28 | 14 May 2027 |
| M8 Handover | 30 | 28 May 2027 |

Total: 30 weeks, about 7 months. The user found "International live" confusing, so it was renamed to "International shipping added".

## 7. Assumptions that may change

- Start date of 2 Nov 2026. If it changes, update the timeline and the payment plan dates.
- Generic Indian market rates in the cost documents. The user will replace them with real ones.
- 30,000 shipments a month for running costs. The DB scaling plan assumed 10,000 a day.
- Regional courier API availability is unconfirmed until the couriers reply.

## 8. Open questions for the client (from the documents)

- Expected shipment volume.
- Whether GST e-invoicing (IRN) applies.
- Whether COD payouts are net of freight.
- The billing cycle for credit customers.
- Whether customers need sub-users.
- Data retention periods.
- Existing AWS account and domain.
- Whether customers need a booking API.
- Which "Added" features to keep.
- Whether failed-delivery (NDR) handling should be in phase 2.

## 9. Tools (in `courier-erp/tools/`)

Run `npm install` there once.

- `npm run pages` regenerates the #9–#12 HTML pages from their `.md` files (`md2page.mjs`).
- `npm run modules` regenerates `modules-and-features.html` from `MODULES_AND_FEATURES.md` (`gen-modules.mjs`).
- `npm run validate-schema` loads `schema.sql` into PGlite and runs integrity smoke tests.
- The other HTML pages (#1, #2, #4–#8) were written by hand. Edit the HTML directly and keep the `.md` in sync.

## 10. Possible next steps

- One index page linking all 12 documents, to send as a single package.
- Combine everything into one proposal PDF.
- Walk the user through any document in simple terms.
- After the client approves: start the Phase 0 working demo (project setup + Delhivery integration).
