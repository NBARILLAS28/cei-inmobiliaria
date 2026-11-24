-- CEI Inmobiliaria · esquema de base de datos (Supabase / Postgres)
-- Roles: admin, supervisor, cliente. Todo cliente nuevo queda "pendiente" hasta que un admin lo asigna.

create type user_role   as enum ('admin','supervisor','cliente');
create type user_status as enum ('pendiente','activo','suspendido');
create type pay_status  as enum ('revision','aprobado','rechazado');
create type req_status  as enum ('abierta','proceso','atendida');
create type media_kind  as enum ('render','proyecto','lote','avance');

create table profiles (
  id uuid primary key references auth.users on delete cascade,
  full_name text not null,
  email text,
  phone text,
  role user_role not null default 'cliente',
  status user_status not null default 'pendiente',
  created_at timestamptz not null default now()
);

create table projects (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  place text not null,
  total_lots int not null check (total_lots > 0),
  description text,
  progress_pct int not null default 0 check (progress_pct between 0 and 100),
  stage text not null default 'Por iniciar',
  lat double precision, lng double precision,
  created_at timestamptz not null default now()
);

-- Supervisores asignados a uno o más proyectos
create table project_staff (
  project_id uuid references projects on delete cascade,
  user_id uuid references profiles on delete cascade,
  primary key (project_id, user_id)
);

-- Lote asignado a un cliente, con su plan de pagos
create table lots (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects on delete cascade,
  code text not null,                       -- ej. L-23
  client_id uuid references profiles,
  price numeric(12,2) not null check (price >= 0),
  down_payment numeric(12,2) not null default 0,
  installments int not null default 1 check (installments > 0),
  unique (project_id, code)
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references profiles,
  lot_id uuid not null references lots,
  concept text not null,                    -- Enganche, Cuota 10, etc.
  amount numeric(12,2) not null check (amount > 0),
  paid_on date not null,
  bank text not null,
  reference text not null,
  file_path text not null,                  -- foto o PDF en el bucket privado "boletas"
  status pay_status not null default 'revision',
  reject_reason text,
  reviewed_by uuid references profiles,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (bank, reference)                  -- evita boletas duplicadas
);

create table receipts (
  id uuid primary key default gen_random_uuid(),
  payment_id uuid not null unique references payments on delete cascade,
  number text not null unique,              -- REC-2026-0001 / FEL-2026-0001
  kind text not null check (kind in ('Recibo','Factura')),
  pdf_path text,                            -- PDF emitido (factura FEL certificada por SAT)
  issued_at timestamptz not null default now()
);

create table requests (
  id uuid primary key default gen_random_uuid(),
  client_id uuid not null references profiles,
  project_id uuid references projects,
  kind text not null,
  message text not null,
  status req_status not null default 'abierta',
  reply text,
  answered_by uuid references profiles,
  created_at timestamptz not null default now()
);

create table media (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects on delete cascade,
  client_id uuid references profiles,       -- solo para fotos de un lote en particular
  kind media_kind not null,
  title text not null,
  description text,
  stage text, progress_pct int,
  file_path text not null,                  -- bucket "media"
  created_by uuid references profiles,
  created_at timestamptz not null default now()
);

create table audit_log (
  id bigint generated always as identity primary key,
  actor uuid references profiles,
  action text not null,
  entity text not null, entity_id uuid,
  detail jsonb,
  created_at timestamptz not null default now()
);

-- Perfil automático al registrarse (siempre cliente y pendiente)
create function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, full_name, email, phone)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), new.email, new.raw_user_meta_data->>'phone');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Funciones de apoyo para las políticas
create function my_role() returns user_role language sql stable security definer set search_path = public as
  $$ select role from profiles where id = auth.uid() $$;
create function is_admin() returns boolean language sql stable security definer set search_path = public as
  $$ select coalesce(my_role() = 'admin', false) $$;
create function supervises(p uuid) returns boolean language sql stable security definer set search_path = public as
  $$ select exists (select 1 from project_staff where project_id = p and user_id = auth.uid()) $$;
create function owns_in(p uuid) returns boolean language sql stable security definer set search_path = public as
  $$ select exists (select 1 from lots where project_id = p and client_id = auth.uid()) $$;

alter table profiles      enable row level security;
alter table projects      enable row level security;
alter table project_staff enable row level security;
alter table lots          enable row level security;
alter table payments      enable row level security;
alter table receipts      enable row level security;
alter table requests      enable row level security;
alter table media         enable row level security;
alter table audit_log     enable row level security;

-- profiles: cada quien ve el suyo; admin ve y edita todos; nadie cambia su propio rol
create policy profiles_read   on profiles for select using (id = auth.uid() or is_admin());
create policy profiles_self   on profiles for update using (id = auth.uid())
  with check (id = auth.uid() and role = my_role() and status = (select status from profiles where id = auth.uid()));
create policy profiles_admin  on profiles for all using (is_admin()) with check (is_admin());

-- proyectos y lotes
create policy projects_read   on projects for select using (is_admin() or supervises(id) or owns_in(id));
create policy projects_admin  on projects for all using (is_admin()) with check (is_admin());
create policy staff_read      on project_staff for select using (is_admin() or user_id = auth.uid());
create policy staff_admin     on project_staff for all using (is_admin()) with check (is_admin());
create policy lots_read       on lots for select using (is_admin() or client_id = auth.uid() or supervises(project_id));
create policy lots_admin      on lots for all using (is_admin()) with check (is_admin());

-- pagos: el cliente ve y sube los suyos (siempre en revisión); solo el admin aprueba. El supervisor no ve finanzas.
create policy pay_read        on payments for select using (is_admin() or client_id = auth.uid());
create policy pay_insert      on payments for insert with check (client_id = auth.uid() and status = 'revision');
create policy pay_admin       on payments for update using (is_admin()) with check (is_admin());
create policy rec_read        on receipts for select using (is_admin() or exists (select 1 from payments p where p.id = payment_id and p.client_id = auth.uid()));
create policy rec_admin       on receipts for all using (is_admin()) with check (is_admin());

-- solicitudes: el cliente crea y ve las suyas; admin y supervisor del proyecto responden
create policy req_read        on requests for select using (is_admin() or client_id = auth.uid() or supervises(project_id));
create policy req_insert      on requests for insert with check (client_id = auth.uid());
create policy req_answer      on requests for update using (is_admin() or supervises(project_id)) with check (is_admin() or supervises(project_id));

-- imágenes: los clientes ven las del proyecto y las de su lote; admin y supervisor publican
create policy media_read      on media for select using (
  is_admin() or supervises(project_id) or (owns_in(project_id) and (client_id is null or client_id = auth.uid())));
create policy media_write     on media for insert with check (is_admin() or supervises(project_id));
create policy media_admin     on media for update using (is_admin()) with check (is_admin());
create policy media_delete    on media for delete using (is_admin());

create policy audit_read      on audit_log for select using (is_admin());

-- Almacenamiento: crear dos buckets PRIVADOS en Supabase Storage
--   "boletas": ruta {client_id}/{archivo}; el cliente solo lee/escribe su carpeta, el admin lee todo.
--   "media":   ruta {project_id}/{archivo}; lectura según las mismas reglas de la tabla media.
