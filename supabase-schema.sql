-- ============================================================
-- SCHÉMA PHÉNIX — à coller dans Supabase > SQL Editor > New query
-- Exécute tout ce fichier en une seule fois, puis "Run".
-- ============================================================

-- 1) Table des profils (une ligne par membre inscrit)
create table public.profiles (
  id uuid references auth.users on delete cascade primary key,
  full_name text,
  email text,
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

-- 2) Table des participations
--    kind = 'declared' -> a cliqué "Je participe à la prochaine séance"
--    kind = 'joined'   -> a réellement cliqué "Rejoindre la séance" (Jitsi)
create table public.attendance (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete cascade not null,
  session_label text,
  kind text not null default 'declared' check (kind in ('declared', 'joined')),
  created_at timestamptz not null default now()
);

-- 3) Création automatique du profil dès qu'un compte est créé
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, new.raw_user_meta_data->>'full_name', new.email)
  on conflict (id) do nothing;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 4) Sécurité (RLS) : chacun ne voit que ses propres données,
--    toi (admin) tu vois tout le monde.
alter table public.profiles enable row level security;
alter table public.attendance enable row level security;

create function public.is_admin()
returns boolean as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$ language sql security definer stable;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Admins can view all profiles"
  on public.profiles for select
  using (public.is_admin());

create policy "Users can insert own attendance"
  on public.attendance for insert
  with check (auth.uid() = user_id);

create policy "Users can view own attendance"
  on public.attendance for select
  using (auth.uid() = user_id);

create policy "Admins can view all attendance"
  on public.attendance for select
  using (public.is_admin());

-- ============================================================
-- DERNIÈRE ÉTAPE (à faire une fois que tu t'es inscrit sur ton
-- propre site avec ton e-mail) : te donner les droits admin.
-- Remplace l'e-mail ci-dessous par le tien puis exécute cette
-- ligne SEULE (sélectionne-la et clique "Run").
-- ============================================================
-- update public.profiles set is_admin = true where email = 'ton-email@exemple.com';
