# Hosting & Maintenance Cost

**Estimated running cost: ₹1.77 lakh per month + GST (≈ ₹21.2 lakh per year + GST)**

*Generic 2026 market rates. Assumes 30,000 shipments per month (about 1,000 per day). Starts after launch.*

## 1. Hosting (AWS Mumbai) — fixed monthly

| Item | Per month |
|---|---|
| App servers | ₹13,000 |
| Database (with standby copy and backups) | ₹15,000 |
| Cache & job queues | ₹4,500 |
| Load balancer, network, fixed IP | ₹6,000 |
| File storage & CDN (labels, invoices) | ₹2,500 |
| Monitoring, logs & backups | ₹5,000 |
| Firewall & security keys | ₹2,000 |
| Testing (staging) server | ₹10,000 |
| Domain & email sending | ₹600 |
| **Hosting total** | **₹58,600** |

## 2. Messages & tracking — depends on shipments

| Item | Quantity per month | Rate | Per month |
|---|---|---|---|
| SMS (2 per shipment) | 60,000 | ₹0.20 | ₹12,000 |
| WhatsApp (3 per shipment) | 90,000 | ₹0.20 | ₹18,000 |
| Tracking service (couriers without tracking API, ~20% of shipments) | 6,000 | ₹3.00 | ₹18,000 |
| **Usage total** | | | **₹48,000** |

## 3. Maintenance & support — fixed monthly

| Item | Per month |
|---|---|
| Maintenance & support (bug fixes, security updates, server monitoring, courier API changes, small changes up to ~40 hours/month) | ₹70,000 |

## Total

| | Per month | Per year |
|---|---|---|
| Hosting | ₹58,600 | ₹7,03,200 |
| Messages & tracking | ₹48,000 | ₹5,76,000 |
| Maintenance & support | ₹70,000 | ₹8,40,000 |
| **Total (excluding GST)** | **₹1,76,600** | **₹21,19,200** |
| GST (18%) | ₹31,788 | ₹3,81,456 |
| **Total including GST** | **₹2,08,388** | **₹25,00,656** |

*Not included: payment gateway fees (about 2% per online payment, usually passed on to customers) and courier charges. During development, only the testing server is needed (about ₹12,000 per month).*
