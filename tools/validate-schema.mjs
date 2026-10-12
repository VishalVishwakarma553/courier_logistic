import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { citext } from '@electric-sql/pglite/contrib/citext';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { readFileSync } from 'node:fs';

const db = new PGlite({ extensions: { pg_trgm, citext, pgcrypto } });
const sql = readFileSync(process.argv[2], 'utf8');
console.log((await db.query('select version()')).rows[0].version);
await db.exec(sql);
console.log('schema OK');

const q = (s, p) => db.query(s, p);
const expectFail = async (label, s, p) => {
  try { await q(s, p); console.log('FAIL (no error):', label); }
  catch (e) { console.log('ok rejected:', label, '->', e.message.split('\n')[0]); }
};

const counts = await q(`select count(*) filter (where relkind='r' and not relispartition) t,
  count(*) filter (where relkind='p') p from pg_class c join pg_namespace n on n.oid=c.relnamespace where nspname='public'`);
console.log('tables', counts.rows[0]);
console.log('triggers', (await q(`select count(*) from pg_trigger where tgname like 'trg_%'`)).rows[0]);

// seed
await q(`insert into countries values ('IN','IND','India','+91','INR',true)`);
await q(`insert into states(country_iso2,code,name,gst_state_code) values ('IN','MH','Maharashtra','27')`);
await q(`insert into roles(code,name,scope,is_system) values ('super_admin','Super Admin','staff',true)`);
await q(`insert into customers(code,company_name) values ('CUST1','Acme')`);
await q(`insert into users(customer_id,role_id,name,email,password_hash) values (1,1,'A','A@x.com','h')`);
await expectFail('duplicate email (citext)', `insert into users(role_id,name,email,password_hash) values (1,'B','a@X.com','h')`);
await q(`insert into couriers(code,name,scope,adapter_key,integration_mode) values ('delhivery','Delhivery','domestic','delhivery_v1','api')`);
await q(`insert into courier_services(courier_id,code,name,supports_cod) values (1,'SURFACE','Delhivery Surface',true)`);
await q(`insert into zones(courier_id,code,name) values (null,'A_LOCAL','Local')`);
await expectFail('duplicate default zone (NULLS NOT DISTINCT)', `insert into zones(courier_id,code,name) values (null,'A_LOCAL','x')`);

const ship = `insert into shipments(booking_ref,customer_id,courier_id,courier_service_id,awb_number,payment_mode,category,
  origin_pincode,dest_pincode,declared_weight_g,chargeable_weight_g,cod_amount,sell_amount,tax_amount,sell_total,idempotency_key)
  values ($1,1,1,1,$2,$3,'parcel','400001','110001',500,500,$4,100,18,118,$5)`;
await q(ship, ['BK1', 'AWB1', 'prepaid', 0, 'k1']);
await expectFail('duplicate AWB same courier', ship, ['BK2', 'AWB1', 'prepaid', 0, 'k2']);
await expectFail('duplicate idempotency key', ship, ['BK3', 'AWB3', 'prepaid', 0, 'k1']);
await expectFail('COD without amount', ship, ['BK4', 'AWB4', 'cod', 0, 'k4']);
await expectFail('sell_total mismatch', `update shipments set tax_amount=5 where id=1`);

const ev = `insert into tracking_events(shipment_id,event_time,status,source,dedupe_hash) values (1,'2026-10-12 10:00+05:30','picked_up',$1,$2)`;
await q(ev, ['webhook', 'h'.repeat(64)]);
await expectFail('duplicate tracking event (webhook+poll)', ev, ['poll', 'h'.repeat(64)]);

const led = `insert into ledger_entries(customer_id,entry_type,amount,balance_after,reference_type,reference_id) values (1,'debit',118,-118,'shipment',1)`;
await q(led);
await expectFail('double charge for same shipment', led);

await q(`insert into notification_logs(channel,recipient) values ('sms','9999999999')`);
const before = (await q(`select updated_at from shipments where id=1`)).rows[0].updated_at;
await new Promise(r => setTimeout(r, 20));
await q(`update shipments set status='in_transit' where id=1`);
const after = (await q(`select updated_at from shipments where id=1`)).rows[0].updated_at;
console.log('updated_at trigger works:', after > before);
await q(`update notification_logs set status='sent'`);
console.log('partitioned trigger ok');
