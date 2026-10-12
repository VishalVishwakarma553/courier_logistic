# Testing & Deployment Plan

How the platform is tested before anything reaches customers, and how it goes live.

## Three environments

| Environment | Used by | Purpose |
|---|---|---|
| **Development** | Developers | Building new features |
| **Testing (staging)** | QA team and client | Trying every feature with courier test accounts before release |
| **Live (production)** | Real customers | The actual platform |

Nothing goes to the live platform without passing through the testing environment first.

## Testing

| Test | When | What is checked |
|---|---|---|
| **Automatic tests** | Every code change | Prices, wallet, invoices, status changes and other core logic are checked automatically |
| **Feature testing (QA)** | Every 2-week sprint | Each new feature is tested by the QA tester on computer and mobile |
| **Courier testing** | Each courier integration | Booking, AWB, label, pickup, tracking and cancellation in the courier's test system |
| **Full re-test** | Before every release | All existing features re-checked so nothing old breaks |
| **Load test** | Before launch | Platform tested at 3× the expected number of bookings |
| **Security test** | Before launch | Checks for common security weaknesses, access control between customers |
| **Client acceptance (UAT)** | Weeks 22–23 | Client staff test real business scenarios and approve the launch |

## Deployment (releasing an update)

1. Code is checked and tested automatically.
2. It goes to the **testing environment**.
3. QA and the client check it.
4. After approval, it goes **live at night** (low traffic).
5. If anything goes wrong, the previous version is **restored within minutes**.

Customers don't see any downtime during normal updates.

## Go-live checklist

| Step | Done by |
|---|---|
| Customers, couriers and rate cards set up in the live system | Team + client |
| Live courier, SMS, WhatsApp and payment credentials entered | Client admin |
| Domain and security certificate (https) ready | Team |
| Backups and restore tested | Team |
| Monitoring and alerts switched on | Team |
| Admin and operations staff trained | Team |
| **Pilot week:** a few selected customers use the platform first | Client |
| **Full launch** to all customers | Client |
| **4 weeks of close support** after launch | Team |
