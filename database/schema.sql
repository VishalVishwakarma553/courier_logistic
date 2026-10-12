-- =====================================================================
-- Multi-Courier Booking, Tracking & ERP Platform
-- PostgreSQL schema (target: PostgreSQL 16+)
--
-- Conventions
--   * PKs: BIGINT identity (INT/SMALLINT for small master tables).
--     High-volume log tables are range-partitioned by month and use BIGSERIAL.
--   * Money: NUMERIC(14,2). Never float.
--   * Weight: integer grams. Dimensions: centimetres NUMERIC(7,2).
--   * Time: TIMESTAMPTZ (stored UTC, displayed IST).
--   * Status columns use Postgres ENUMs (values can be appended with
--     ALTER TYPE ... ADD VALUE without downtime).
--   * Shipment addresses are SNAPSHOTS (copied at booking time), never FKs to
--     the address book, so editing an address never rewrites history.
--   * Ledger and tracking tables are append-only.
-- See DATABASE_DESIGN.md for rationale, scaling plan and module mapping.
-- =====================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS pg_trgm;    -- fuzzy search on names
CREATE EXTENSION IF NOT EXISTS citext;     -- case-insensitive emails

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------
-- ENUM TYPES
-- ---------------------------------------------------------------------
CREATE TYPE record_status        AS ENUM ('active', 'inactive', 'blocked');
CREATE TYPE customer_status      AS ENUM ('pending_kyc', 'active', 'blocked', 'closed');
CREATE TYPE billing_type         AS ENUM ('prepaid', 'credit');
CREATE TYPE role_scope           AS ENUM ('staff', 'customer');
CREATE TYPE courier_scope        AS ENUM ('domestic', 'international', 'both');
CREATE TYPE integration_mode     AS ENUM ('api', 'manual', 'hybrid');
CREATE TYPE api_environment      AS ENUM ('sandbox', 'production');
CREATE TYPE address_type         AS ENUM ('pickup', 'consignee', 'return', 'billing');
CREATE TYPE address_role         AS ENUM ('sender', 'receiver', 'return');

-- Client's "Prepaid, COD, To Pay, Reverse Pickup, International" is split into
-- three independent attributes: payment_mode, direction, is_international.
CREATE TYPE payment_mode         AS ENUM ('prepaid', 'cod', 'to_pay');
CREATE TYPE shipment_direction   AS ENUM ('forward', 'reverse');
CREATE TYPE shipment_category    AS ENUM ('document', 'parcel');

-- Normalised status: every courier's codes are mapped onto these.
CREATE TYPE shipment_status AS ENUM (
  'draft',
  'booking_confirmed',
  'booking_failed',
  'manifested',          -- AWB generated
  'pickup_scheduled',
  'picked_up',
  'in_transit',
  'arrived_at_hub',
  'customs_clearance',   -- international only
  'out_for_delivery',
  'delivered',
  'delivery_failed',
  'exception',           -- shipment hold / damaged / address issue
  'rto_initiated',
  'rto_in_transit',
  'returned_to_sender',
  'cancelled',
  'lost'
);

CREATE TYPE pickup_status        AS ENUM ('pending', 'scheduled', 'picked_up', 'failed', 'cancelled');
CREATE TYPE cod_status           AS ENUM ('not_applicable', 'pending', 'collected', 'remitted_by_courier', 'paid_to_customer');
CREATE TYPE tracking_source      AS ENUM ('webhook', 'poll', 'manual', 'system');
CREATE TYPE rate_card_type       AS ENUM ('purchase', 'selling');
CREATE TYPE ledger_entry_type    AS ENUM ('debit', 'credit');
CREATE TYPE payment_status       AS ENUM ('created', 'pending', 'success', 'failed', 'refunded');
CREATE TYPE invoice_status       AS ENUM ('draft', 'issued', 'partially_paid', 'paid', 'cancelled');
CREATE TYPE job_status           AS ENUM ('queued', 'processing', 'completed', 'failed', 'partially_completed');
CREATE TYPE notification_channel AS ENUM ('sms', 'whatsapp', 'email');
CREATE TYPE notification_status  AS ENUM ('queued', 'sent', 'delivered', 'read', 'failed');
CREATE TYPE ticket_status        AS ENUM ('open', 'in_progress', 'waiting_on_customer', 'resolved', 'closed');

-- =====================================================================
-- 1. MASTER DATA
-- =====================================================================
CREATE TABLE countries (
  iso2           CHAR(2) PRIMARY KEY,
  iso3           CHAR(3) NOT NULL UNIQUE,
  name           TEXT    NOT NULL,
  dial_code      VARCHAR(6),
  currency_code  CHAR(3),
  is_active      BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE states (
  id              SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  country_iso2    CHAR(2) NOT NULL REFERENCES countries(iso2),
  code            VARCHAR(10) NOT NULL,
  name            TEXT NOT NULL,
  gst_state_code  CHAR(2),                 -- used for CGST/SGST vs IGST
  UNIQUE (country_iso2, code)
);

CREATE TABLE pincodes (
  pincode    CHAR(6) PRIMARY KEY,
  city       TEXT NOT NULL,
  district   TEXT,
  state_id   SMALLINT NOT NULL REFERENCES states(id),
  is_metro   BOOLEAN NOT NULL DEFAULT false,
  region     VARCHAR(30) NOT NULL DEFAULT 'standard'   -- 'north_east', 'j_and_k', 'island', ...
);
CREATE INDEX ix_pincodes_state ON pincodes(state_id);

CREATE TABLE hs_codes (
  code         VARCHAR(12) PRIMARY KEY,
  description  TEXT NOT NULL
);

-- =====================================================================
-- 2. IDENTITY & ACCESS (RBAC)
-- =====================================================================
CREATE TABLE roles (
  id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code        VARCHAR(50) NOT NULL UNIQUE,     -- super_admin, ops_manager, accounts, customer_admin, customer_operator
  name        TEXT NOT NULL,
  scope       role_scope NOT NULL,
  is_system   BOOLEAN NOT NULL DEFAULT false,  -- system roles cannot be deleted
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE permissions (
  id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code         VARCHAR(100) NOT NULL UNIQUE,   -- e.g. 'shipment.create', 'rate_card.manage'
  module       VARCHAR(50)  NOT NULL,
  description  TEXT
);

CREATE TABLE role_permissions (
  role_id        INT NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  permission_id  INT NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
  PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE users (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id         BIGINT,                  -- NULL = internal staff; FK added below
  role_id             INT NOT NULL REFERENCES roles(id),
  name                TEXT NOT NULL,
  email               CITEXT NOT NULL UNIQUE,
  mobile              VARCHAR(15),
  password_hash       TEXT NOT NULL,           -- argon2id / bcrypt
  status              record_status NOT NULL DEFAULT 'active',
  mfa_enabled         BOOLEAN NOT NULL DEFAULT false,
  mfa_secret_enc      BYTEA,
  failed_login_count  SMALLINT NOT NULL DEFAULT 0,
  locked_until        TIMESTAMPTZ,
  last_login_at       TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_users_customer ON users(customer_id);

CREATE TABLE user_sessions (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id             BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash  CHAR(64) NOT NULL UNIQUE,  -- SHA-256 of the refresh token
  ip_address          INET,
  user_agent          TEXT,
  expires_at          TIMESTAMPTZ NOT NULL,
  revoked_at          TIMESTAMPTZ,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_user_sessions_user ON user_sessions(user_id);

-- =====================================================================
-- 3. CUSTOMERS
-- =====================================================================
CREATE TABLE customers (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code                VARCHAR(20) NOT NULL UNIQUE,     -- e.g. CUST000123
  company_name        TEXT NOT NULL,
  contact_name        TEXT,
  email               CITEXT,
  mobile              VARCHAR(15),
  billing_type        billing_type NOT NULL DEFAULT 'prepaid',
  credit_limit        NUMERIC(14,2) NOT NULL DEFAULT 0,
  credit_days         SMALLINT NOT NULL DEFAULT 0,
  billing_cycle       VARCHAR(20) NOT NULL DEFAULT 'monthly',  -- weekly / fortnightly / monthly
  gstin               VARCHAR(15),
  pan                 VARCHAR(10),
  billing_line1       TEXT,
  billing_line2       TEXT,
  billing_city        TEXT,
  billing_state_id    SMALLINT REFERENCES states(id),
  billing_pincode     VARCHAR(10),
  billing_country     CHAR(2) NOT NULL DEFAULT 'IN' REFERENCES countries(iso2),
  status              customer_status NOT NULL DEFAULT 'pending_kyc',
  account_manager_id  BIGINT REFERENCES users(id),
  settings            JSONB NOT NULL DEFAULT '{}'::jsonb,  -- label size, default service, etc.
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_customers_name_trgm ON customers USING gin (company_name gin_trgm_ops);

ALTER TABLE users
  ADD CONSTRAINT fk_users_customer FOREIGN KEY (customer_id) REFERENCES customers(id);

-- Saved address book (pickup points, frequent consignees)
CREATE TABLE customer_addresses (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id   BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  address_type  address_type NOT NULL,
  label         VARCHAR(60),                   -- "Main Warehouse"
  contact_name  TEXT NOT NULL,
  mobile        VARCHAR(15) NOT NULL,
  email         CITEXT,
  line1         TEXT NOT NULL,
  line2         TEXT,
  landmark      TEXT,
  city          TEXT NOT NULL,
  state_name    TEXT NOT NULL,
  pincode       VARCHAR(10) NOT NULL,
  country_iso2  CHAR(2) NOT NULL DEFAULT 'IN' REFERENCES countries(iso2),
  gstin         VARCHAR(15),
  is_default    BOOLEAN NOT NULL DEFAULT false,
  is_active     BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_customer_addresses_customer ON customer_addresses(customer_id, address_type);

-- =====================================================================
-- 4. FILES (S3 object references: labels, invoices, KYC, uploads)
-- =====================================================================
CREATE TABLE files (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  storage_key      TEXT NOT NULL UNIQUE,       -- S3 key; never store file bytes in DB
  original_name    TEXT,
  mime_type        VARCHAR(100) NOT NULL,
  size_bytes       BIGINT NOT NULL,
  checksum_sha256  CHAR(64),
  category         VARCHAR(40) NOT NULL,       -- label, invoice, commercial_invoice, kyc, bulk_upload, ...
  customer_id      BIGINT REFERENCES customers(id),   -- owner, for access checks
  uploaded_by      BIGINT REFERENCES users(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE customer_documents (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  doc_type     VARCHAR(40) NOT NULL,           -- gst_certificate, pan, agreement, ...
  doc_number   VARCHAR(60),
  file_id      BIGINT NOT NULL REFERENCES files(id),
  verified_by  BIGINT REFERENCES users(id),
  verified_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================================================================
-- 5. COURIERS & INTEGRATION CONFIG
-- =====================================================================
CREATE TABLE couriers (
  id                INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  code              VARCHAR(30) NOT NULL UNIQUE,    -- 'delhivery', 'bluedart', 'dhl_express'
  name              TEXT NOT NULL,
  scope             courier_scope NOT NULL,
  adapter_key       VARCHAR(50) NOT NULL,           -- which code adapter handles it ('delhivery_v1', 'manual')
  integration_mode  integration_mode NOT NULL DEFAULT 'manual',
  -- what the integration supports, shown in UI and used for fallbacks:
  -- {"serviceability":true,"awb":true,"label":true,"pickup":true,"tracking_webhook":false,"tracking_poll":true,"cancel":true}
  capabilities      JSONB NOT NULL DEFAULT '{}'::jsonb,
  tracking_url_tpl  TEXT,                           -- public tracking link template with {awb}
  logo_file_id      BIGINT REFERENCES files(id),
  status            record_status NOT NULL DEFAULT 'active',
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE courier_services (
  id                   INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id           INT NOT NULL REFERENCES couriers(id),
  code                 VARCHAR(40) NOT NULL,      -- courier's product code: 'SURFACE', 'EXPRESS', 'APEX'
  name                 TEXT NOT NULL,             -- shown to customers
  is_international     BOOLEAN NOT NULL DEFAULT false,
  supports_cod         BOOLEAN NOT NULL DEFAULT false,
  supports_reverse     BOOLEAN NOT NULL DEFAULT false,
  supports_document    BOOLEAN NOT NULL DEFAULT true,
  supports_parcel      BOOLEAN NOT NULL DEFAULT true,
  max_weight_g         INT,
  max_cod_amount       NUMERIC(14,2),
  volumetric_divisor   INT NOT NULL DEFAULT 5000, -- L*B*H(cm) / divisor = kg
  status               record_status NOT NULL DEFAULT 'active',
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (courier_id, code)
);

-- Secrets are encrypted in the application (AES-256-GCM, key in KMS).
-- Non-secret settings (customer code, area code, client name) go in config.
CREATE TABLE courier_credentials (
  id                 INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id         INT NOT NULL REFERENCES couriers(id),
  environment        api_environment NOT NULL,
  config             JSONB NOT NULL DEFAULT '{}'::jsonb,
  secret_ciphertext  BYTEA NOT NULL,            -- nonce + ciphertext + auth tag
  key_id             VARCHAR(100) NOT NULL,     -- which KMS key / version encrypted it (for rotation)
  is_active          BOOLEAN NOT NULL DEFAULT true,
  updated_by         BIGINT REFERENCES users(id),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_courier_credentials_active
  ON courier_credentials(courier_id, environment) WHERE is_active;

-- Some couriers (e.g. Delhivery) need pickup locations pre-registered on their side.
CREATE TABLE courier_pickup_locations (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id           INT NOT NULL REFERENCES couriers(id),
  customer_address_id  BIGINT NOT NULL REFERENCES customer_addresses(id),
  courier_location_ref VARCHAR(100) NOT NULL,   -- warehouse name / code at the courier
  status               record_status NOT NULL DEFAULT 'active',
  registered_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (courier_id, customer_address_id)
);

-- Serviceable pincodes. Filled by API sync or Excel upload (manual couriers).
-- ~19k pincodes x N services; fits comfortably, hot rows cached in Redis.
CREATE TABLE courier_serviceability (
  courier_service_id  INT NOT NULL REFERENCES courier_services(id) ON DELETE CASCADE,
  pincode             VARCHAR(10) NOT NULL,
  is_pickup           BOOLEAN NOT NULL DEFAULT false,
  is_delivery         BOOLEAN NOT NULL DEFAULT true,
  cod_allowed         BOOLEAN NOT NULL DEFAULT false,
  prepaid_allowed     BOOLEAN NOT NULL DEFAULT true,
  reverse_allowed     BOOLEAN NOT NULL DEFAULT false,
  is_oda              BOOLEAN NOT NULL DEFAULT false,   -- out-of-delivery-area (extra charge)
  tat_days            SMALLINT,                         -- indicative; API TAT preferred when available
  source              VARCHAR(10) NOT NULL DEFAULT 'upload' CHECK (source IN ('api', 'upload', 'manual')),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (courier_service_id, pincode)
);
CREATE INDEX ix_serviceability_pincode ON courier_serviceability(pincode);

-- Courier status code -> normalised status
CREATE TABLE courier_status_mappings (
  courier_id           INT NOT NULL REFERENCES couriers(id) ON DELETE CASCADE,
  courier_status_code  VARCHAR(60) NOT NULL,
  normalized_status    shipment_status NOT NULL,
  description          TEXT,
  PRIMARY KEY (courier_id, courier_status_code)
);

-- =====================================================================
-- 6. RATE ENGINE
-- Pricing resolution (per customer + service):
--   1. customer_courier_services.selling_rate_card_id (customer-specific card)
--   2. else purchase cost + customer markup (markup_percent / markup_flat)
--   3. else default selling card (rate_cards.customer_id IS NULL)
-- =====================================================================
CREATE TABLE zones (
  id                INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id        INT REFERENCES couriers(id),   -- NULL = platform default zone set
  code              VARCHAR(30) NOT NULL,          -- 'A_LOCAL', 'B_STATE', 'C_METRO', 'D_ROI', 'E_SPECIAL', 'INTL_Z1'
  name              TEXT NOT NULL,
  is_international  BOOLEAN NOT NULL DEFAULT false,
  UNIQUE NULLS NOT DISTINCT (courier_id, code)
);

-- Evaluated in priority order by the rate engine; first match wins.
CREATE TABLE zone_rules (
  id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  zone_id    INT NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
  priority   SMALLINT NOT NULL,
  rule_type  VARCHAR(30) NOT NULL CHECK (rule_type IN
               ('same_city', 'same_state', 'metro_to_metro', 'dest_region', 'pincode_list', 'rest')),
  params     JSONB NOT NULL DEFAULT '{}'::jsonb   -- e.g. {"regions":["north_east","j_and_k"]}
);
CREATE INDEX ix_zone_rules_zone ON zone_rules(zone_id, priority);

CREATE TABLE zone_countries (
  zone_id       INT NOT NULL REFERENCES zones(id) ON DELETE CASCADE,
  country_iso2  CHAR(2) NOT NULL REFERENCES countries(iso2),
  PRIMARY KEY (zone_id, country_iso2)
);

CREATE TABLE rate_cards (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name                TEXT NOT NULL,
  card_type           rate_card_type NOT NULL,
  courier_service_id  INT NOT NULL REFERENCES courier_services(id),
  customer_id         BIGINT REFERENCES customers(id),   -- only for customer-specific selling cards
  currency            CHAR(3) NOT NULL DEFAULT 'INR',
  valid_from          DATE NOT NULL,
  valid_to            DATE,
  status              VARCHAR(10) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'active', 'archived')),
  created_by          BIGINT REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (card_type = 'selling' OR customer_id IS NULL),
  CHECK (valid_to IS NULL OR valid_to >= valid_from)
);
CREATE INDEX ix_rate_cards_lookup ON rate_cards(courier_service_id, card_type, customer_id, valid_from DESC)
  WHERE status = 'active';

-- Weight slabs, e.g. 0-500g = 40, then +30 per additional 500g
CREATE TABLE rate_card_slabs (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rate_card_id        BIGINT NOT NULL REFERENCES rate_cards(id) ON DELETE CASCADE,
  zone_id             INT NOT NULL REFERENCES zones(id),
  category            shipment_category,               -- NULL = applies to both
  weight_from_g       INT NOT NULL,
  weight_to_g         INT NOT NULL,
  base_rate           NUMERIC(12,2) NOT NULL,
  additional_unit_g   INT,                             -- NULL = flat slab
  additional_rate     NUMERIC(12,2),
  CHECK (weight_to_g > weight_from_g),
  CHECK ((additional_unit_g IS NULL) = (additional_rate IS NULL))
);
CREATE INDEX ix_rate_slabs_lookup ON rate_card_slabs(rate_card_id, zone_id, weight_from_g);

-- Surcharges: fuel, COD, ODA, RTO, handling, docket, insurance, minimum freight...
CREATE TABLE rate_card_charges (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  rate_card_id  BIGINT NOT NULL REFERENCES rate_cards(id) ON DELETE CASCADE,
  charge_code   VARCHAR(30) NOT NULL,
  calc_method   VARCHAR(20) NOT NULL CHECK (calc_method IN ('flat', 'percent', 'per_kg', 'percent_or_min')),
  calc_base     VARCHAR(20) NOT NULL DEFAULT 'freight'
                  CHECK (calc_base IN ('freight', 'invoice_value', 'cod_amount', 'weight')),
  value         NUMERIC(12,4) NOT NULL,
  min_amount    NUMERIC(12,2),
  max_amount    NUMERIC(12,2),
  conditions    JSONB NOT NULL DEFAULT '{}'::jsonb,   -- e.g. {"only_if":"is_oda"}
  UNIQUE (rate_card_id, charge_code)
);

-- Which services each customer may use, and how they are priced
CREATE TABLE customer_courier_services (
  customer_id           BIGINT NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
  courier_service_id    INT NOT NULL REFERENCES courier_services(id),
  is_enabled            BOOLEAN NOT NULL DEFAULT true,
  selling_rate_card_id  BIGINT REFERENCES rate_cards(id),
  markup_percent        NUMERIC(6,2),
  markup_flat           NUMERIC(12,2),
  display_priority      SMALLINT NOT NULL DEFAULT 100,
  PRIMARY KEY (customer_id, courier_service_id)
);

CREATE TABLE tax_rates (
  id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          VARCHAR(40) NOT NULL,           -- 'GST 18% courier services'
  sac_code      VARCHAR(10) NOT NULL,           -- 996812
  rate_percent  NUMERIC(5,2) NOT NULL,
  valid_from    DATE NOT NULL,
  valid_to      DATE
);

-- =====================================================================
-- 7. BOOKINGS, PICKUPS, SHIPMENTS
-- =====================================================================
CREATE TABLE bulk_uploads (
  id                    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id           BIGINT NOT NULL REFERENCES customers(id),
  uploaded_by           BIGINT NOT NULL REFERENCES users(id),
  file_id               BIGINT NOT NULL REFERENCES files(id),
  status                job_status NOT NULL DEFAULT 'queued',
  total_rows            INT NOT NULL DEFAULT 0,
  success_rows          INT NOT NULL DEFAULT 0,
  failed_rows           INT NOT NULL DEFAULT 0,
  error_report_file_id  BIGINT REFERENCES files(id),
  started_at            TIMESTAMPTZ,
  completed_at          TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_bulk_uploads_customer ON bulk_uploads(customer_id, created_at DESC);

CREATE TABLE pickup_requests (
  id                   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id          BIGINT NOT NULL REFERENCES customers(id),
  courier_id           INT NOT NULL REFERENCES couriers(id),
  customer_address_id  BIGINT REFERENCES customer_addresses(id),
  pickup_address       JSONB NOT NULL,          -- snapshot
  pickup_date          DATE NOT NULL,
  slot_from            TIME,
  slot_to              TIME,
  expected_packages    INT NOT NULL DEFAULT 1,
  courier_pickup_ref   VARCHAR(80),             -- pickup ID returned by courier
  status               pickup_status NOT NULL DEFAULT 'pending',
  is_manual            BOOLEAN NOT NULL DEFAULT false,
  attempts             SMALLINT NOT NULL DEFAULT 0,
  failure_reason       TEXT,
  created_by           BIGINT REFERENCES users(id),
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_pickups_status_date ON pickup_requests(status, pickup_date);
CREATE INDEX ix_pickups_customer ON pickup_requests(customer_id, pickup_date DESC);
CREATE UNIQUE INDEX ux_pickups_courier_ref ON pickup_requests(courier_id, courier_pickup_ref)
  WHERE courier_pickup_ref IS NOT NULL;

CREATE TABLE shipments (
  id                       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_ref              VARCHAR(20) NOT NULL UNIQUE,     -- our own reference, e.g. BK2610120000123
  customer_id              BIGINT NOT NULL REFERENCES customers(id),
  created_by               BIGINT REFERENCES users(id),
  booking_source           VARCHAR(10) NOT NULL DEFAULT 'web' CHECK (booking_source IN ('web', 'bulk', 'admin', 'api')),
  bulk_upload_id           BIGINT REFERENCES bulk_uploads(id),
  idempotency_key          VARCHAR(64),                     -- duplicate-booking protection

  courier_id               INT NOT NULL REFERENCES couriers(id),
  courier_service_id       INT NOT NULL REFERENCES courier_services(id),
  awb_number               VARCHAR(40),
  courier_order_ref        VARCHAR(80),

  payment_mode             payment_mode NOT NULL,
  direction                shipment_direction NOT NULL DEFAULT 'forward',
  is_international         BOOLEAN NOT NULL DEFAULT false,
  category                 shipment_category NOT NULL,

  -- denormalised from addresses for fast routing / filtering
  origin_pincode           VARCHAR(10) NOT NULL,
  dest_pincode             VARCHAR(10) NOT NULL,
  origin_country           CHAR(2) NOT NULL DEFAULT 'IN' REFERENCES countries(iso2),
  dest_country             CHAR(2) NOT NULL DEFAULT 'IN' REFERENCES countries(iso2),
  zone_id                  INT REFERENCES zones(id),

  piece_count              SMALLINT NOT NULL DEFAULT 1 CHECK (piece_count > 0),
  declared_weight_g        INT NOT NULL CHECK (declared_weight_g > 0),
  length_cm                NUMERIC(7,2),
  width_cm                 NUMERIC(7,2),
  height_cm                NUMERIC(7,2),
  volumetric_weight_g      INT,
  chargeable_weight_g      INT NOT NULL,                    -- max(actual, volumetric), rounded per rules
  courier_billed_weight_g  INT,                             -- from courier bill; used for weight disputes

  invoice_number           VARCHAR(50),
  invoice_value            NUMERIC(14,2) NOT NULL DEFAULT 0,
  currency                 CHAR(3) NOT NULL DEFAULT 'INR',
  cod_amount               NUMERIC(14,2) NOT NULL DEFAULT 0,
  cod_status               cod_status NOT NULL DEFAULT 'not_applicable',
  ewaybill_number          VARCHAR(20),
  special_instructions     TEXT,
  handling_flags           TEXT[] NOT NULL DEFAULT '{}',    -- {fragile, liquid, ...}

  -- price snapshot at booking (line items in shipment_charges)
  sell_amount              NUMERIC(14,2) NOT NULL DEFAULT 0,   -- before tax
  tax_amount               NUMERIC(14,2) NOT NULL DEFAULT 0,
  sell_total               NUMERIC(14,2) NOT NULL DEFAULT 0,
  cost_amount              NUMERIC(14,2) NOT NULL DEFAULT 0,   -- INTERNAL purchase cost: never in customer APIs

  status                   shipment_status NOT NULL DEFAULT 'draft',
  status_reason            TEXT,
  status_updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  is_delayed               BOOLEAN NOT NULL DEFAULT false,

  pickup_request_id        BIGINT REFERENCES pickup_requests(id),
  label_file_id            BIGINT REFERENCES files(id),
  invoice_id               BIGINT,                          -- FK added in billing section

  expected_delivery_date   DATE,
  manifested_at            TIMESTAMPTZ,
  picked_up_at             TIMESTAMPTZ,
  delivered_at             TIMESTAMPTZ,
  rto_initiated_at         TIMESTAMPTZ,
  cancelled_at             TIMESTAMPTZ,

  last_tracking_sync_at    TIMESTAMPTZ,
  next_tracking_sync_at    TIMESTAMPTZ,                     -- polling scheduler reads this

  version                  INT NOT NULL DEFAULT 1,          -- optimistic locking
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

  CHECK (payment_mode <> 'cod' OR cod_amount > 0),
  CHECK (sell_total = sell_amount + tax_amount)
);

-- Integrity
CREATE UNIQUE INDEX ux_shipments_courier_awb ON shipments(courier_id, awb_number) WHERE awb_number IS NOT NULL;
CREATE UNIQUE INDEX ux_shipments_idempotency ON shipments(customer_id, idempotency_key) WHERE idempotency_key IS NOT NULL;
-- Lookups
CREATE INDEX ix_shipments_awb              ON shipments(awb_number);               -- public tracking page
CREATE INDEX ix_shipments_customer_created ON shipments(customer_id, created_at DESC);
CREATE INDEX ix_shipments_courier_created  ON shipments(courier_id, created_at DESC);
CREATE INDEX ix_shipments_status           ON shipments(status, status_updated_at);
CREATE INDEX ix_shipments_created          ON shipments(created_at DESC);
CREATE INDEX ix_shipments_pickup           ON shipments(pickup_request_id) WHERE pickup_request_id IS NOT NULL;
-- Work queues (partial indexes stay small because terminal shipments drop out)
CREATE INDEX ix_shipments_poll_due ON shipments(next_tracking_sync_at)
  WHERE status NOT IN ('draft', 'booking_failed', 'delivered', 'returned_to_sender', 'cancelled', 'lost');
CREATE INDEX ix_shipments_cod_open ON shipments(courier_id, cod_status)
  WHERE payment_mode = 'cod' AND cod_status <> 'paid_to_customer';
CREATE INDEX ix_shipments_unbilled ON shipments(customer_id, created_at)
  WHERE invoice_id IS NULL AND status NOT IN ('draft', 'booking_failed', 'cancelled');

CREATE TABLE shipment_addresses (
  shipment_id   BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  role          address_role NOT NULL,
  name          TEXT NOT NULL,
  company       TEXT,
  mobile        VARCHAR(15) NOT NULL,
  alt_mobile    VARCHAR(15),
  email         CITEXT,
  line1         TEXT NOT NULL,
  line2         TEXT,
  landmark      TEXT,
  city          TEXT NOT NULL,
  state_name    TEXT NOT NULL,
  pincode       VARCHAR(10) NOT NULL,
  country_iso2  CHAR(2) NOT NULL DEFAULT 'IN' REFERENCES countries(iso2),
  gstin         VARCHAR(15),
  tax_id        VARCHAR(40),                   -- international consignee tax/VAT ID
  PRIMARY KEY (shipment_id, role)
);
CREATE INDEX ix_shipment_addr_mobile    ON shipment_addresses(mobile);
CREATE INDEX ix_shipment_addr_name_trgm ON shipment_addresses USING gin (name gin_trgm_ops);

-- Multi-piece shipments (MPS)
CREATE TABLE shipment_packages (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shipment_id   BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  piece_no      SMALLINT NOT NULL,
  child_awb     VARCHAR(40),
  weight_g      INT NOT NULL,
  length_cm     NUMERIC(7,2),
  width_cm      NUMERIC(7,2),
  height_cm     NUMERIC(7,2),
  UNIQUE (shipment_id, piece_no)
);

-- Contents (mandatory for international / commercial invoice)
CREATE TABLE shipment_items (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shipment_id      BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  description      TEXT NOT NULL,
  sku              VARCHAR(60),
  quantity         INT NOT NULL CHECK (quantity > 0),
  unit_value       NUMERIC(14,2) NOT NULL,
  hs_code          VARCHAR(12) REFERENCES hs_codes(code),
  origin_country   CHAR(2) REFERENCES countries(iso2),
  unit_weight_g    INT
);
CREATE INDEX ix_shipment_items_shipment ON shipment_items(shipment_id);

CREATE TABLE shipment_documents (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shipment_id  BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  doc_type     VARCHAR(40) NOT NULL,   -- label, invoice, commercial_invoice, ewaybill, kyc, pod
  file_id      BIGINT NOT NULL REFERENCES files(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_shipment_documents_shipment ON shipment_documents(shipment_id);

-- Price breakdown captured at booking; cost side stays internal
CREATE TABLE shipment_charges (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  shipment_id  BIGINT NOT NULL REFERENCES shipments(id) ON DELETE CASCADE,
  charge_code  VARCHAR(30) NOT NULL,           -- freight, fuel_surcharge, cod, oda, ...
  sell_amount  NUMERIC(14,2) NOT NULL DEFAULT 0,
  cost_amount  NUMERIC(14,2) NOT NULL DEFAULT 0,
  is_adjustment BOOLEAN NOT NULL DEFAULT false, -- added later (weight dispute, RTO)
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_shipment_charges_shipment ON shipment_charges(shipment_id);

-- Pre-allotted AWB numbers for couriers without an AWB API
CREATE TABLE courier_awb_stock (
  courier_id   INT NOT NULL REFERENCES couriers(id),
  awb_number   VARCHAR(40) NOT NULL,
  status       VARCHAR(10) NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'used', 'void')),
  shipment_id  BIGINT REFERENCES shipments(id),
  imported_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  used_at      TIMESTAMPTZ,
  PRIMARY KEY (courier_id, awb_number)
);
-- Allocate with: SELECT ... WHERE status='available' ... FOR UPDATE SKIP LOCKED LIMIT 1
CREATE INDEX ix_awb_stock_available ON courier_awb_stock(courier_id) WHERE status = 'available';

-- ---------------------------------------------------------------------
-- Tracking history: highest-volume table. Partitioned monthly by event_time.
-- Create monthly partitions with pg_partman (or a scheduled job).
-- ---------------------------------------------------------------------
CREATE TABLE tracking_events (
  id                   BIGSERIAL,
  shipment_id          BIGINT NOT NULL REFERENCES shipments(id),
  event_time           TIMESTAMPTZ NOT NULL,     -- when it happened (courier time)
  status               shipment_status NOT NULL,
  courier_status_code  VARCHAR(60),
  courier_status_text  TEXT,
  location             TEXT,
  remarks              TEXT,
  source               tracking_source NOT NULL,
  webhook_event_id     BIGINT,                   -- soft reference to webhook_events
  dedupe_hash          CHAR(64) NOT NULL,        -- sha256(awb|code|event_time|location)
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, event_time),
  UNIQUE (shipment_id, dedupe_hash, event_time) -- webhook + poll can deliver the same event
) PARTITION BY RANGE (event_time);
CREATE INDEX ix_tracking_events_shipment ON tracking_events(shipment_id, event_time DESC);
CREATE TABLE tracking_events_default PARTITION OF tracking_events DEFAULT;

-- =====================================================================
-- 8. BILLING, WALLET, COD, ACCOUNTS
-- =====================================================================

-- Gapless, per-financial-year document numbers (invoice, receipt...).
-- Increment with UPDATE ... RETURNING inside the same transaction.
CREATE TABLE number_sequences (
  series          VARCHAR(30) NOT NULL,        -- 'invoice', 'credit_note', 'payout'
  financial_year  CHAR(7) NOT NULL,            -- '2026-27'
  prefix          VARCHAR(20) NOT NULL,
  next_value      BIGINT NOT NULL DEFAULT 1,
  PRIMARY KEY (series, financial_year)
);

-- Cached balance; the ledger is the source of truth.
-- Update in the same transaction as the ledger insert, after SELECT ... FOR UPDATE.
CREATE TABLE wallets (
  customer_id            BIGINT PRIMARY KEY REFERENCES customers(id),
  balance                NUMERIC(14,2) NOT NULL DEFAULT 0,
  low_balance_threshold  NUMERIC(14,2),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only. Corrections are reversing entries, never UPDATE/DELETE.
CREATE TABLE ledger_entries (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id     BIGINT NOT NULL REFERENCES customers(id),
  entry_type      ledger_entry_type NOT NULL,
  amount          NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  balance_after   NUMERIC(14,2) NOT NULL,
  reference_type  VARCHAR(30) NOT NULL CHECK (reference_type IN
                    ('shipment', 'shipment_adjustment', 'shipment_refund', 'payment',
                     'invoice', 'cod_offset', 'manual_adjustment')),
  reference_id    BIGINT NOT NULL,
  narration       TEXT,
  created_by      BIGINT REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_ledger_customer ON ledger_entries(customer_id, created_at DESC);
-- A shipment is charged once and refunded once; a payment is credited once.
CREATE UNIQUE INDEX ux_ledger_once ON ledger_entries(reference_type, reference_id)
  WHERE reference_type IN ('shipment', 'shipment_refund', 'payment');

CREATE TABLE payments (
  id                  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id         BIGINT NOT NULL REFERENCES customers(id),
  purpose             VARCHAR(20) NOT NULL CHECK (purpose IN ('wallet_recharge', 'invoice_payment')),
  method              VARCHAR(20) NOT NULL,      -- gateway, neft, cheque, cash
  gateway             VARCHAR(20),               -- razorpay, cashfree
  gateway_order_id    VARCHAR(80),
  gateway_payment_id  VARCHAR(80),
  bank_reference      VARCHAR(80),               -- UTR / cheque no for offline
  amount              NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  status              payment_status NOT NULL DEFAULT 'created',
  gateway_payload     JSONB,
  received_at         TIMESTAMPTZ,
  recorded_by         BIGINT REFERENCES users(id),
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_payments_gateway ON payments(gateway, gateway_payment_id) WHERE gateway_payment_id IS NOT NULL;
CREATE INDEX ix_payments_customer ON payments(customer_id, created_at DESC);

CREATE TABLE invoices (
  id                      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_number          VARCHAR(30) NOT NULL UNIQUE,
  customer_id             BIGINT NOT NULL REFERENCES customers(id),
  period_from             DATE NOT NULL,
  period_to               DATE NOT NULL,
  invoice_date            DATE NOT NULL,
  due_date                DATE NOT NULL,
  place_of_supply_state   SMALLINT REFERENCES states(id),
  customer_gstin          VARCHAR(15),                 -- snapshot
  taxable_amount          NUMERIC(14,2) NOT NULL,
  cgst_amount             NUMERIC(14,2) NOT NULL DEFAULT 0,
  sgst_amount             NUMERIC(14,2) NOT NULL DEFAULT 0,
  igst_amount             NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_amount            NUMERIC(14,2) NOT NULL,
  amount_paid             NUMERIC(14,2) NOT NULL DEFAULT 0,
  status                  invoice_status NOT NULL DEFAULT 'draft',
  irn                     VARCHAR(64),                 -- GST e-invoice reference (if applicable)
  irn_ack_no              VARCHAR(30),
  irn_qr                  TEXT,
  file_id                 BIGINT REFERENCES files(id),
  created_by              BIGINT REFERENCES users(id),
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (total_amount = taxable_amount + cgst_amount + sgst_amount + igst_amount)
);
CREATE INDEX ix_invoices_customer ON invoices(customer_id, invoice_date DESC);
CREATE INDEX ix_invoices_outstanding ON invoices(due_date) WHERE status IN ('issued', 'partially_paid');

ALTER TABLE shipments
  ADD CONSTRAINT fk_shipments_invoice FOREIGN KEY (invoice_id) REFERENCES invoices(id);

CREATE TABLE invoice_lines (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id      BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,
  shipment_id     BIGINT REFERENCES shipments(id),
  description     TEXT NOT NULL,
  sac_code        VARCHAR(10) NOT NULL,
  taxable_amount  NUMERIC(14,2) NOT NULL,
  tax_rate        NUMERIC(5,2) NOT NULL,
  tax_amount      NUMERIC(14,2) NOT NULL
);
CREATE INDEX ix_invoice_lines_invoice ON invoice_lines(invoice_id);

CREATE TABLE payment_allocations (
  payment_id  BIGINT NOT NULL REFERENCES payments(id),
  invoice_id  BIGINT NOT NULL REFERENCES invoices(id),
  amount      NUMERIC(14,2) NOT NULL CHECK (amount > 0),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (payment_id, invoice_id)
);

-- Purchase side: bills received from courier companies
CREATE TABLE courier_bills (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id    INT NOT NULL REFERENCES couriers(id),
  bill_number   VARCHAR(50) NOT NULL,
  bill_date     DATE NOT NULL,
  period_from   DATE,
  period_to     DATE,
  taxable_amount NUMERIC(14,2) NOT NULL,
  tax_amount    NUMERIC(14,2) NOT NULL DEFAULT 0,
  total_amount  NUMERIC(14,2) NOT NULL,
  status        VARCHAR(20) NOT NULL DEFAULT 'pending_reconciliation'
                  CHECK (status IN ('pending_reconciliation', 'reconciled', 'disputed', 'paid')),
  file_id       BIGINT REFERENCES files(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (courier_id, bill_number)
);

CREATE TABLE courier_bill_lines (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_bill_id   BIGINT NOT NULL REFERENCES courier_bills(id) ON DELETE CASCADE,
  awb_number        VARCHAR(40) NOT NULL,
  shipment_id       BIGINT REFERENCES shipments(id),   -- NULL until matched
  billed_weight_g   INT,
  billed_amount     NUMERIC(14,2) NOT NULL,
  expected_amount   NUMERIC(14,2),
  match_status      VARCHAR(20) NOT NULL DEFAULT 'unmatched'
                      CHECK (match_status IN ('unmatched', 'matched', 'variance', 'not_found'))
);
CREATE INDEX ix_courier_bill_lines_bill ON courier_bill_lines(courier_bill_id);
CREATE INDEX ix_courier_bill_lines_awb  ON courier_bill_lines(awb_number);

-- COD money: courier -> us
CREATE TABLE cod_remittances (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  courier_id       INT NOT NULL REFERENCES couriers(id),
  remittance_ref   VARCHAR(60) NOT NULL,
  utr              VARCHAR(40),
  remittance_date  DATE NOT NULL,
  total_amount     NUMERIC(14,2) NOT NULL,
  file_id          BIGINT REFERENCES files(id),     -- courier's remittance sheet
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (courier_id, remittance_ref)
);

CREATE TABLE cod_remittance_lines (
  cod_remittance_id  BIGINT NOT NULL REFERENCES cod_remittances(id) ON DELETE CASCADE,
  shipment_id        BIGINT NOT NULL REFERENCES shipments(id),
  amount             NUMERIC(14,2) NOT NULL,
  PRIMARY KEY (cod_remittance_id, shipment_id)
);
CREATE UNIQUE INDEX ux_cod_remittance_shipment ON cod_remittance_lines(shipment_id);  -- each COD remitted once

-- COD money: us -> customer
CREATE TABLE cod_payouts (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  payout_ref      VARCHAR(30) NOT NULL UNIQUE,
  customer_id     BIGINT NOT NULL REFERENCES customers(id),
  gross_amount    NUMERIC(14,2) NOT NULL,
  deductions      NUMERIC(14,2) NOT NULL DEFAULT 0,   -- freight offset, if agreed
  net_amount      NUMERIC(14,2) NOT NULL,
  status          VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed')),
  utr             VARCHAR(40),
  paid_at         TIMESTAMPTZ,
  created_by      BIGINT REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (net_amount = gross_amount - deductions)
);
CREATE INDEX ix_cod_payouts_customer ON cod_payouts(customer_id, created_at DESC);

CREATE TABLE cod_payout_lines (
  cod_payout_id  BIGINT NOT NULL REFERENCES cod_payouts(id) ON DELETE CASCADE,
  shipment_id    BIGINT NOT NULL REFERENCES shipments(id),
  amount         NUMERIC(14,2) NOT NULL,
  PRIMARY KEY (cod_payout_id, shipment_id)
);
CREATE UNIQUE INDEX ux_cod_payout_shipment ON cod_payout_lines(shipment_id);          -- each COD paid out once

-- =====================================================================
-- 9. NOTIFICATIONS
-- =====================================================================
CREATE TABLE notification_templates (
  id                    INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  event_code            VARCHAR(40) NOT NULL,     -- booking_confirmed, out_for_delivery, delivered, ...
  channel               notification_channel NOT NULL,
  language              VARCHAR(5) NOT NULL DEFAULT 'en',
  subject               TEXT,                     -- email only
  body                  TEXT NOT NULL,            -- with {{placeholders}}
  provider_template_id  VARCHAR(80),              -- DLT template ID (SMS) / approved WhatsApp template name
  is_active             BOOLEAN NOT NULL DEFAULT true,
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (event_code, channel, language)
);

-- Per-customer opt-in/out; customer_id NULL = platform default
CREATE TABLE notification_preferences (
  id           INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  customer_id  BIGINT REFERENCES customers(id) ON DELETE CASCADE,
  event_code   VARCHAR(40) NOT NULL,
  channel      notification_channel NOT NULL,
  notify_sender    BOOLEAN NOT NULL DEFAULT true,
  notify_receiver  BOOLEAN NOT NULL DEFAULT true,
  UNIQUE NULLS NOT DISTINCT (customer_id, event_code, channel)
);

CREATE TABLE notification_logs (
  id                   BIGSERIAL,
  template_id          INT REFERENCES notification_templates(id),
  channel              notification_channel NOT NULL,
  recipient            VARCHAR(255) NOT NULL,
  shipment_id          BIGINT,
  customer_id          BIGINT,
  status               notification_status NOT NULL DEFAULT 'queued',
  provider             VARCHAR(30),
  provider_message_id  VARCHAR(120),
  error_message        TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX ix_notification_logs_shipment ON notification_logs(shipment_id);
CREATE INDEX ix_notification_logs_provider ON notification_logs(provider_message_id);  -- delivery-report callbacks
CREATE TABLE notification_logs_default PARTITION OF notification_logs DEFAULT;

-- =====================================================================
-- 10. SUPPORT
-- =====================================================================
CREATE TABLE support_tickets (
  id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ticket_no    VARCHAR(20) NOT NULL UNIQUE,
  customer_id  BIGINT NOT NULL REFERENCES customers(id),
  shipment_id  BIGINT REFERENCES shipments(id),
  category     VARCHAR(40) NOT NULL,           -- delay, damage, weight_dispute, billing, pickup, other
  subject      TEXT NOT NULL,
  priority     VARCHAR(10) NOT NULL DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  status       ticket_status NOT NULL DEFAULT 'open',
  assigned_to  BIGINT REFERENCES users(id),
  created_by   BIGINT NOT NULL REFERENCES users(id),
  resolved_at  TIMESTAMPTZ,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_tickets_customer ON support_tickets(customer_id, created_at DESC);
CREATE INDEX ix_tickets_open ON support_tickets(status, assigned_to) WHERE status NOT IN ('resolved', 'closed');

CREATE TABLE ticket_messages (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  ticket_id       BIGINT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  author_id       BIGINT NOT NULL REFERENCES users(id),
  body            TEXT NOT NULL,
  attachment_ids  BIGINT[] NOT NULL DEFAULT '{}',
  is_internal     BOOLEAN NOT NULL DEFAULT false,   -- staff-only note
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_ticket_messages_ticket ON ticket_messages(ticket_id, created_at);

-- =====================================================================
-- 11. INTEGRATION LOGS, AUDIT, SETTINGS, REPORTING
-- =====================================================================

-- Every outbound courier API call (secrets/PII masked before insert)
CREATE TABLE api_request_logs (
  id              BIGSERIAL,
  courier_id      INT,
  shipment_id     BIGINT,
  operation       VARCHAR(30) NOT NULL,     -- serviceability, create_shipment, label, pickup, track, cancel
  correlation_id  UUID,
  http_method     VARCHAR(7),
  url             TEXT,
  request_body    JSONB,
  response_status SMALLINT,
  response_body   JSONB,
  duration_ms     INT,
  success         BOOLEAN NOT NULL,
  error_message   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX ix_api_logs_shipment ON api_request_logs(shipment_id, created_at DESC);
CREATE INDEX ix_api_logs_failures ON api_request_logs(courier_id, created_at DESC) WHERE NOT success;
CREATE TABLE api_request_logs_default PARTITION OF api_request_logs DEFAULT;

-- Every inbound webhook, stored before processing (replayable)
CREATE TABLE webhook_events (
  id                 BIGSERIAL,
  courier_id         INT,
  headers            JSONB,
  payload            JSONB NOT NULL,
  signature_valid    BOOLEAN,
  processing_status  VARCHAR(12) NOT NULL DEFAULT 'received'
                       CHECK (processing_status IN ('received', 'processed', 'failed', 'ignored')),
  attempts           SMALLINT NOT NULL DEFAULT 0,
  error_message      TEXT,
  received_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  processed_at       TIMESTAMPTZ,
  PRIMARY KEY (id, received_at)
) PARTITION BY RANGE (received_at);
CREATE INDEX ix_webhook_events_pending ON webhook_events(received_at) WHERE processing_status IN ('received', 'failed');
CREATE TABLE webhook_events_default PARTITION OF webhook_events DEFAULT;

-- Who changed what (rates, credentials, customers, manual status corrections...)
CREATE TABLE audit_logs (
  id           BIGSERIAL,
  user_id      BIGINT,
  action       VARCHAR(40) NOT NULL,       -- create, update, delete, login, status_override, export
  entity_type  VARCHAR(40) NOT NULL,
  entity_id    BIGINT,
  old_values   JSONB,
  new_values   JSONB,
  ip_address   INET,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);
CREATE INDEX ix_audit_entity ON audit_logs(entity_type, entity_id, created_at DESC);
CREATE INDEX ix_audit_user   ON audit_logs(user_id, created_at DESC);
CREATE TABLE audit_logs_default PARTITION OF audit_logs DEFAULT;

CREATE TABLE system_settings (
  key         VARCHAR(80) PRIMARY KEY,
  value       JSONB NOT NULL,
  updated_by  BIGINT REFERENCES users(id),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Pre-aggregated by workers on every status change, so dashboards and
-- reports never scan the shipments table.
CREATE TABLE shipment_daily_stats (
  stat_date        DATE   NOT NULL,
  customer_id      BIGINT NOT NULL REFERENCES customers(id),
  courier_id       INT    NOT NULL REFERENCES couriers(id),
  booked           INT NOT NULL DEFAULT 0,
  picked_up        INT NOT NULL DEFAULT 0,
  delivered        INT NOT NULL DEFAULT 0,
  rto              INT NOT NULL DEFAULT 0,
  exceptions       INT NOT NULL DEFAULT 0,
  cancelled        INT NOT NULL DEFAULT 0,
  cod_count        INT NOT NULL DEFAULT 0,
  cod_amount       NUMERIC(14,2) NOT NULL DEFAULT 0,
  revenue_amount   NUMERIC(14,2) NOT NULL DEFAULT 0,
  cost_amount      NUMERIC(14,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (stat_date, customer_id, courier_id)
);
CREATE INDEX ix_daily_stats_courier ON shipment_daily_stats(courier_id, stat_date);

-- =====================================================================
-- 12. updated_at TRIGGERS (every regular table that has the column)
-- =====================================================================
DO $$
DECLARE t TEXT;
BEGIN
  FOR t IN
    SELECT cl.relname
    FROM pg_class cl
    JOIN pg_namespace n ON n.oid = cl.relnamespace
    JOIN pg_attribute a ON a.attrelid = cl.oid AND a.attname = 'updated_at' AND NOT a.attisdropped
    WHERE n.nspname = 'public'
      AND cl.relkind IN ('r', 'p')      -- tables and partitioned parents
      AND NOT cl.relispartition         -- partitions inherit the parent's trigger
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_%s_updated_at BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION set_updated_at()',
      t, t);
  END LOOP;
END $$;
