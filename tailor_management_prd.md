# Tailor Management Software — Product & Engineering Blueprint

**Stack:** Flutter (Android / Windows / Web) · Supabase (Postgres, Auth, Storage, Realtime) · Riverpod · Clean Architecture
**Audience:** AI coding agent + project owner
**Goal:** A commercial-grade, multi-shop-ready tailoring management product.

---

## 0. How to use this document

This is the master spec. Build it in **phases** (Section 11) — do not try to one-shot the whole app. Each phase has a ready-to-paste agent prompt at the bottom. The database schema (Section 4) is the foundation; build that first and get RLS working before any UI.

---

## 1. Product overview

A point-of-sale + workflow tool for tailoring shops. The shop owner/staff manage customers, capture measurements once and reuse them forever, take orders with multiple garments, handle advance/remaining payments, and print branded customer cards + receipts on both thermal and A4 printers.

**Core value proposition:** *"Same customer walks back in → instantly pull their measurements and order history."* Everything else supports that loop.

### Primary user roles
| Role | Capabilities |
|------|-------------|
| Owner | Everything + shop settings, reports, staff management |
| Staff | Customers, measurements, orders, billing, printing |
| (Future) Multi-shop | Each shop isolated by `shop_id` via RLS |

---

## 2. Design principles

- **Single codebase, three platforms.** Use a responsive shell: bottom-nav/drawer on mobile, persistent side-rail + master-detail on Windows/Web at ≥1024px.
- **Offline-tolerant reads.** Cache customers/measurements/orders locally (Hive or Isar) so the shop keeps working if internet drops; writes queue and sync.
- **Measurements are flexible.** Never hardcode the field list — store values as JSONB driven by per-shop templates, so men/women/children + custom fields all work without schema changes.
- **Money math lives in the database**, not the UI, to avoid drift. Remaining balance is derived, never manually edited.
- **Print is a first-class feature**, not an afterthought. Design the card/receipt layouts early.

---

## 3. Architecture (Clean Architecture + Repository pattern)

```
lib/
├── main.dart
├── app.dart                      # MaterialApp.router, theme, Supabase init
├── core/
│   ├── config/                   # env, supabase keys (from --dart-define)
│   ├── constants/                # app constants, enums
│   ├── theme/                    # colors, typography, component themes
│   ├── responsive/               # R.isDesktop(context), breakpoints, layout shell
│   ├── router/                   # go_router config + guards
│   ├── errors/                   # Failure, AppException, Result<T>
│   ├── utils/                    # formatters (money, date), validators
│   └── widgets/                  # shared buttons, fields, empty/error/loading states
├── features/
│   ├── auth/
│   ├── customers/
│   ├── measurements/
│   ├── orders/
│   ├── billing/
│   ├── printing/                 # card/receipt/invoice builders (pdf)
│   ├── images/                   # design reference upload/gallery
│   ├── dashboard/
│   ├── reports/
│   ├── notifications/
│   └── settings/                 # shop profile, logo, measurement templates
└── shared/
    ├── models/                   # cross-feature DTOs if any
    └── providers/                # global providers (supabase client, current shop)
```

**Each feature folder follows the same three layers:**

```
features/customers/
├── data/
│   ├── models/                   # CustomerModel (freezed, fromJson/toJson)
│   ├── datasources/              # CustomerRemoteDataSource (Supabase calls)
│   │                             # CustomerLocalDataSource (Hive cache)
│   └── repositories/             # CustomerRepositoryImpl
├── domain/
│   ├── entities/                 # Customer (pure dart, no json)
│   ├── repositories/             # abstract CustomerRepository
│   └── usecases/                 # AddCustomer, SearchCustomers, GetCustomerHistory...
└── presentation/
    ├── providers/                # Riverpod notifiers/controllers + state
    ├── screens/
    └── widgets/
```

### State management (Riverpod)
- Use `@riverpod` code-gen (riverpod_generator) for type-safety.
- One `AsyncNotifier` per screen-level controller (e.g. `customerListControllerProvider`).
- `supabaseClientProvider` and `currentShopProvider` are global.
- Repository providers wire datasources → repository → usecases.

### Error handling
- Repositories return `Result<T>` = `Either<Failure, T>` (use `fpdart` or a small sealed `Result`).
- Datasources throw typed `AppException`; repository maps to `Failure`.
- UI consumes `AsyncValue` and renders shared loading/error/empty widgets.

---

## 4. Database schema (Supabase / PostgreSQL)

> Multi-shop ready from day one via `shop_id`. If you only ever run one shop, it still works — you just have a single shops row. **Don't skip this**, retrofitting tenancy later is painful.

### 4.1 Tables

```sql
-- ========== SHOPS & STAFF ==========
create table shops (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  logo_url    text,
  address     text,
  phone       text,
  currency    text not null default 'PKR',
  created_at  timestamptz not null default now()
);

create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  shop_id     uuid not null references shops(id) on delete cascade,
  full_name   text,
  role        text not null default 'staff' check (role in ('owner','staff')),
  created_at  timestamptz not null default now()
);

-- ========== CUSTOMERS ==========
create table customers (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  name        text not null,
  phone       text,
  address     text,
  gender      text check (gender in ('male','female','child')),
  notes       text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on customers (shop_id);
create index on customers (shop_id, phone);
-- trigram search on name/phone (run: create extension if not exists pg_trgm;)
create index customers_name_trgm on customers using gin (name gin_trgm_ops);

-- ========== MEASUREMENT TEMPLATES (custom fields per shop) ==========
create table measurement_templates (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  category    text not null check (category in ('men','women','children')),
  name        text not null,                 -- e.g. "Shalwar Kameez"
  -- fields: [{ "key":"length", "label":"Lambai", "unit":"in", "order":1 }, ...]
  fields      jsonb not null default '[]',
  is_default  boolean not null default false,
  created_at  timestamptz not null default now()
);

-- ========== MEASUREMENTS (one record per customer per garment type) ==========
create table measurements (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null references shops(id) on delete cascade,
  customer_id uuid not null references customers(id) on delete cascade,
  category    text not null check (category in ('men','women','children')),
  title       text not null,                 -- e.g. "Kameez Shalwar"
  template_id uuid references measurement_templates(id),
  -- values: { "length":"42", "chest":"40", "sleeve":"24", ... }
  values      jsonb not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index on measurements (shop_id, customer_id);

-- ========== ORDERS ==========
create table orders (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id) on delete cascade,
  customer_id   uuid not null references customers(id) on delete restrict,
  order_number  bigint not null,             -- per-shop sequential (see function)
  token_number  text,                        -- short human token e.g. "T-0421"
  order_date    date not null default current_date,
  delivery_date date,
  status        text not null default 'pending'
                check (status in ('pending','cutting','stitching','ready','delivered','cancelled')),
  total_amount  numeric(12,2) not null default 0,
  discount      numeric(12,2) not null default 0,
  notes         text,
  created_by    uuid references profiles(id),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (shop_id, order_number)
);
create index on orders (shop_id, status);
create index on orders (shop_id, delivery_date);
create index on orders (shop_id, customer_id);

-- ========== ORDER ITEMS (multiple garments per order) ==========
create table order_items (
  id              uuid primary key default gen_random_uuid(),
  order_id        uuid not null references orders(id) on delete cascade,
  dress_type      text not null,             -- e.g. "Sherwani"
  quantity        int not null default 1 check (quantity > 0),
  cloth_details   text,
  design_details  text,
  measurement_id  uuid references measurements(id),  -- which measurement to stitch by
  unit_price      numeric(12,2) not null default 0,
  notes           text
);
create index on order_items (order_id);

-- ========== PAYMENTS (advance + later installments all live here) ==========
create table payments (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id) on delete cascade,
  order_id      uuid not null references orders(id) on delete cascade,
  amount        numeric(12,2) not null check (amount >= 0),
  method        text not null default 'cash' check (method in ('cash','card','online')),
  paid_at       timestamptz not null default now(),
  note          text,
  created_by    uuid references profiles(id)
);
create index on payments (shop_id, order_id);
create index on payments (shop_id, paid_at);

-- ========== DESIGN / REFERENCE IMAGES ==========
create table order_images (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id) on delete cascade,
  order_id      uuid not null references orders(id) on delete cascade,
  storage_path  text not null,               -- path in Supabase Storage bucket
  caption       text,
  created_at    timestamptz not null default now()
);
create index on order_images (order_id);

-- ========== REMINDERS / NOTIFICATIONS ==========
create table reminders (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id) on delete cascade,
  order_id      uuid references orders(id) on delete cascade,
  type          text not null check (type in ('delivery','pending','custom')),
  remind_at     timestamptz not null,
  message       text,
  is_done       boolean not null default false,
  created_at    timestamptz not null default now()
);
create index on reminders (shop_id, remind_at) where is_done = false;
```

### 4.2 Derived balance (don't store remaining — compute it)

```sql
-- A convenient view that always returns correct balances
create view order_balances as
select
  o.id as order_id,
  o.shop_id,
  o.total_amount,
  o.discount,
  coalesce(p.paid, 0)                              as paid_amount,
  (o.total_amount - o.discount - coalesce(p.paid,0)) as remaining_amount
from orders o
left join (
  select order_id, sum(amount) as paid
  from payments group by order_id
) p on p.order_id = o.id;
```
The "advance" the shop takes at order creation is simply the **first payment row**. Remaining = `total - discount - sum(payments)`. This makes the books impossible to corrupt by hand.

### 4.3 Per-shop sequential order numbers

```sql
create table order_counters (
  shop_id   uuid primary key references shops(id) on delete cascade,
  next_no   bigint not null default 1
);

create or replace function assign_order_number()
returns trigger language plpgsql as $$
declare n bigint;
begin
  insert into order_counters(shop_id, next_no) values (new.shop_id, 1)
  on conflict (shop_id) do nothing;

  update order_counters
     set next_no = next_no + 1
   where shop_id = new.shop_id
   returning next_no - 1 into n;

  new.order_number := n;
  if new.token_number is null then
    new.token_number := 'T-' || lpad(n::text, 4, '0');
  end if;
  return new;
end $$;

create trigger trg_assign_order_number
before insert on orders
for each row when (new.order_number is null or new.order_number = 0)
execute function assign_order_number();
```

### 4.4 Row Level Security (critical — do this before any client work)

```sql
-- helper: current user's shop
create or replace function current_shop_id()
returns uuid language sql stable as $$
  select shop_id from profiles where id = auth.uid()
$$;

-- enable RLS on every table
alter table shops                  enable row level security;
alter table profiles               enable row level security;
alter table customers              enable row level security;
alter table measurement_templates  enable row level security;
alter table measurements           enable row level security;
alter table orders                 enable row level security;
alter table order_items            enable row level security;
alter table payments               enable row level security;
alter table order_images           enable row level security;
alter table reminders              enable row level security;

-- generic shop-scoped policy pattern (repeat per table that has shop_id)
create policy shop_isolation on customers
  for all
  using (shop_id = current_shop_id())
  with check (shop_id = current_shop_id());
-- ^ duplicate this block for: measurement_templates, measurements, orders,
--   payments, order_images, reminders.

-- order_items has no shop_id → scope through its order
create policy shop_isolation_items on order_items
  for all
  using (exists (select 1 from orders o where o.id = order_items.order_id and o.shop_id = current_shop_id()))
  with check (exists (select 1 from orders o where o.id = order_items.order_id and o.shop_id = current_shop_id()));

-- profiles: a user sees their own profile + shop-mates (owner can manage staff)
create policy profile_self on profiles
  for select using (shop_id = current_shop_id());

-- shops: see your own shop
create policy shop_own on shops
  for select using (id = current_shop_id());
create policy shop_update on shops
  for update using (id = current_shop_id() and exists(
    select 1 from profiles where id = auth.uid() and role = 'owner'));
```

> ⚠️ Keep the **service_role key server-side only**. The Flutter app uses the **anon key** + RLS. (You've done a security overhaul before — same rules apply: no secrets in the repo, env via `--dart-define`.)

### 4.5 Storage
- Bucket `design-images` (private). Path convention: `{shop_id}/{order_id}/{uuid}.jpg`.
- Bucket `shop-logos` (public-read or signed). Path: `{shop_id}/logo.png`.
- Add storage RLS policies so a user can only read/write paths starting with their `shop_id`.

---

## 5. Feature specifications

### 5.1 Customer Management
- List with search-as-you-type (name / phone) using the trigram index.
- Detail screen = tabs: **Profile · Measurements · Orders (history)**.
- On opening a returning customer, their measurements load instantly (cached + remote).
- Soft delete optional (add `deleted_at` if you want recoverable deletes; otherwise `on delete cascade` cleans children).

### 5.2 Measurement Management
- Category selector (men/women/children) → loads matching default template.
- Render fields dynamically from the template's `fields` JSON (label, unit, input).
- **Custom fields:** owner edits templates in Settings; new fields appear automatically.
- Body-diagram: ship 3 SVG illustrations (men/women/child) with labeled measurement points; tapping a point focuses the matching field. Keep diagrams as assets, not generated.
- Auto-fill: when creating an order item, default the measurement dropdown to the customer's latest matching measurement.

### 5.3 Order Management
- Wizard: pick customer → add garment items (each with type, qty, cloth, design, measurement, price) → set delivery date → set total + advance → save.
- Status pipeline with a visual stepper: Pending → Cutting → Stitching → Ready → Delivered. Realtime subscription so status updates reflect live across devices.
- Multiple garments = multiple `order_items`. Order `total_amount` can be auto-suggested from sum(item unit_price × qty) but stays editable.

### 5.4 Billing & Payments
- At order creation, advance = first `payments` row.
- Payment history list per order; "Add payment" appends rows.
- Remaining always read from `order_balances` view. Never let the user type a remaining figure.
- Invoice/order number auto-generated by the DB trigger (Section 4.3).

### 5.5 Customer Token / Card (the signature feature)
Branded, printable card containing: shop logo, shop name, customer name, order #, token #, order date, delivery date, total, advance, remaining, contact number, important notes. See Section 6 for layout.

### 5.6 Printing System
- `pdf` package builds the document; `printing` package handles preview + send-to-printer + share.
- **Two layouts per document:** an **80mm thermal** layout (narrow, monochrome, large text) and an **A4** layout (full branded). Detect/let user choose.
- Preview screen before printing on all platforms.
- "Share as PDF" → `share_plus`; "Send on WhatsApp" → `url_launcher` deep link with the customer's number + a pre-filled message, attaching the generated PDF.

### 5.7 Design & Image Management
- `image_picker` for camera + gallery (multi-select on gallery).
- Compress before upload (e.g. `flutter_image_compress`) to save storage/bandwidth.
- Upload to `design-images` bucket; store `storage_path` in `order_images`.
- Gallery viewer per order with delete.

### 5.8 Search System
Unified search bar that matches across: customer name, phone, order number, token number, delivery date. Implement as an RPC (`search_everything(term text)`) that UNIONs results, or separate scoped searches behind one UI.

### 5.9 Dashboard
KPIs: total customers, total orders, pending, ready, delivered, daily revenue, monthly revenue. Back these with SQL aggregate RPCs (don't pull all rows client-side). Add a small revenue trend chart (`fl_chart`).

### 5.10 Reports & Analytics
- Daily sales, monthly sales, pending orders, delivered orders, customer stats.
- Each report = a parameterized Postgres function returning rows; export to PDF/CSV.

### 5.11 Notifications
- `reminders` table drives in-app reminders (delivery due, pending too long).
- For push later: a Supabase Edge Function on a cron checks due reminders and sends via your push provider (OneSignal works, same as your other project).
- WhatsApp share + PDF share as in 5.6.

---

## 6. Customer Card layout spec

**A4 / branded version (top-to-bottom):**
1. Header band: logo (left), shop name + address + phone (center/right).
2. Token + order number row, large and bold (this is what staff scan visually).
3. Customer block: name, contact.
4. Dates row: order date | delivery date (delivery emphasized).
5. Items summary table: dress type · qty · cloth.
6. Money block (right-aligned): Total / Advance / **Remaining** (remaining highlighted).
7. Notes box.
8. Footer: small "Generated by [Shop Name]" + optional QR encoding the order id (for fast lookup later).

**80mm thermal version:** same data, single column, no heavy graphics, monospace-ish, dividers as dashed lines, remaining amount in the largest text.

Keep both as pure `pdf` widget trees so they render identically on Android/Windows/Web.

---

## 7. Recommended packages

| Concern | Package |
|---|---|
| Backend client | `supabase_flutter` |
| State | `flutter_riverpod` + `riverpod_annotation` / `riverpod_generator` |
| Routing | `go_router` |
| Models | `freezed` + `json_serializable` |
| Functional errors | `fpdart` (Either/Result) |
| PDF | `pdf` |
| Print/preview/share-pdf | `printing` |
| Images | `image_picker`, `flutter_image_compress`, `cached_network_image` |
| Offline cache | `hive` / `hive_flutter` (or `isar`) |
| Sharing | `share_plus`, `url_launcher` |
| Charts | `fl_chart` |
| Dates/money format | `intl` |
| Windows printing note | `printing` supports Windows; test thermal via system driver |

---

## 8. Responsive strategy

- Breakpoint at **1024px** (reuse your `R.isDesktop(context)` helper pattern).
- Mobile (<1024): bottom nav (Dashboard, Customers, Orders, More), full-screen pushes.
- Desktop/Web (≥1024): persistent `NavigationRail` + master-detail (list on left, detail on right). Orders and Customers especially benefit from master-detail.
- Use `LayoutBuilder`/`MediaQuery` in a single `AppShell` widget so every feature screen just provides content.

---

## 9. Offline & sync (pragmatic version)

- Cache `customers`, `measurements`, recent `orders` in Hive on fetch.
- Reads: show cached instantly, then refresh from Supabase (stale-while-revalidate).
- Writes while offline: queue mutations in a local box, replay on reconnect (use connectivity listener). Start simple — even read-cache alone is a big UX win; add write-queue in a later phase.

---

## 10. Security checklist (you know the drill)

- Anon key + RLS only in the app; **service_role never ships**.
- Keys via `--dart-define` / env, not committed.
- Storage RLS so users only touch their `shop_id` paths.
- Validate file types/size on upload (you've built file-type validation before — reuse it).
- Test RLS by logging in as a second shop and confirming zero cross-shop visibility **before** building UI on top.

---

## 11. Phased build roadmap (build in this order)

| Phase | Deliverable | Why first |
|---|---|---|
| 0 | Supabase project: schema, RLS, storage buckets, triggers, seed one shop + owner | Foundation |
| 1 | Flutter skeleton: clean-arch folders, theme, router, AppShell (responsive), Supabase init, auth (login) | Walls before furniture |
| 2 | Customers feature (CRUD + search + detail tabs) end-to-end through all 3 layers | Proves the architecture pattern |
| 3 | Measurements (templates + dynamic fields + body diagram + auto-fill) | Core differentiator |
| 4 | Orders + order_items (wizard, status pipeline, realtime) | Central workflow |
| 5 | Billing & payments (advance, history, balances view) | Money |
| 6 | Printing: card + receipt + invoice (thermal + A4) + preview + PDF share | Signature feature |
| 7 | Images (camera/gallery, compress, upload, gallery view) | Enhances orders |
| 8 | Dashboard + reports (aggregate RPCs + charts + exports) | Owner value |
| 9 | Notifications/reminders + WhatsApp share + offline write-queue | Polish |
| 10 | Hardening: error states, empty states, loading skeletons, Windows/Web QA, store prep | Ship |

---

## 12. Agent-ready prompts (paste one per phase)

> Give the agent **this whole document as context**, then paste the relevant phase prompt. Make it build one phase, you review, then proceed.

**Phase 0 — Database**
> Using the schema, triggers, views, and RLS policies in Section 4 of the blueprint, generate a single idempotent Supabase migration SQL file. Enable required extensions (`pgcrypto`, `pg_trgm`). Add the storage bucket creation + storage RLS policies for `design-images` and `shop-logos` scoped by `shop_id`. Include a seed block that creates one demo shop, one owner profile, and 2 sample customers. Output as `supabase/migrations/0001_init.sql`.

**Phase 1 — App skeleton**
> Scaffold a Flutter app following the Clean Architecture folder structure in Section 3. Set up: theme + typography, `go_router` with an auth guard, a responsive `AppShell` (NavigationRail ≥1024px, bottom nav below) per Section 8, `supabaseClientProvider`, `currentShopProvider`, a `Result<T>`/`Failure` error layer, and email/password login + logout wired to Supabase Auth. Use riverpod code-gen. No feature screens yet — just an empty Dashboard placeholder behind auth.

**Phase 2 — Customers**
> Implement the Customers feature end-to-end across data/domain/presentation layers (models with freezed, remote + Hive local datasource, repository, usecases, Riverpod controllers). Screens: searchable list (trigram search by name/phone), add/edit form with validation, and a detail screen with Profile/Measurements/Orders tabs (latter two can be placeholders for now). Implement stale-while-revalidate caching.

*(Continue with one prompt per phase, always referencing the matching Section 5 spec.)*

---

## 13. Open decisions to confirm before Phase 4

1. **Single shop or true multi-shop SaaS?** Schema supports both; affects onboarding/signup flow.
2. **Pricing model on order items** — fixed per garment, or free-form total only?
3. **Thermal printer model(s)** you'll actually use (affects width/charset testing).
4. **Languages** — English only, or Urdu/RTL support in the UI and on printed cards?
5. **Staff accounts** in v1, or owner-only login first?

Lock these and Phase 4+ gets much smoother.
