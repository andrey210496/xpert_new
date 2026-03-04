-- 0. CLEAN WIPE (Reset schema for 100% fresh start)
-- Isso limpa tudo na nossa camada pública
DROP TABLE IF EXISTS invite_codes CASCADE;
DROP TABLE IF EXISTS leads CASCADE;
DROP TABLE IF EXISTS token_limits CASCADE;
DROP TABLE IF EXISTS token_transactions CASCADE;
DROP TABLE IF EXISTS messages CASCADE;
DROP TABLE IF EXISTS conversations CASCADE;
DROP TABLE IF EXISTS profiles CASCADE;
DROP TABLE IF EXISTS tenants CASCADE;

-- Limpeza de funções
DROP FUNCTION IF EXISTS deduct_tokens CASCADE;
DROP FUNCTION IF EXISTS increment_conversation_tokens CASCADE;
DROP FUNCTION IF EXISTS register_user CASCADE;
DROP FUNCTION IF EXISTS superadmin_create_tenant_and_admin CASCADE;
DROP FUNCTION IF EXISTS is_superadmin CASCADE;
DROP FUNCTION IF EXISTS is_admin CASCADE;
DROP FUNCTION IF EXISTS get_user_tenant_id CASCADE;
DROP FUNCTION IF EXISTS update_updated_at CASCADE;

-- LIMPEZA NUCLEAR (Opcional: use se tiver erro ao deletar usuários no painel)
--DELETE FROM auth.users; 
--DELETE FROM auth.identities;

-- 1. EXTENSIONS
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 2. TABLES
-- Tenants (Condomínios/Administradoras)
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  admin_user_id UUID, -- References auth.users(id) - updated after table creation
  token_balance BIGINT DEFAULT 0,
  plan TEXT DEFAULT 'trial' CHECK (plan IN ('trial', 'starter', 'pro', 'enterprise')),
  plan_tokens_total BIGINT DEFAULT 50000,
  settings JSONB DEFAULT '{}',
  tenant_context TEXT,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Profiles
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  profile_type TEXT DEFAULT 'resident', -- Usando TEXT para máxima compatibilidade API
  is_active BOOLEAN DEFAULT true,
  daily_token_usage BIGINT DEFAULT 0,
  last_usage_reset TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Conversations
CREATE TABLE conversations (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  agent_type TEXT NOT NULL,
  title TEXT DEFAULT 'Nova conversa',
  tokens_used BIGINT DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  conversation_id UUID REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  tokens_input INT,
  tokens_output INT,
  model TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Token Transactions
CREATE TABLE token_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE SET NULL,
  conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
  tokens_input INT NOT NULL DEFAULT 0,
  tokens_output INT NOT NULL DEFAULT 0,
  tokens_total INT NOT NULL DEFAULT 0,
  model TEXT,
  profile_type TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Token Limits
CREATE TABLE token_limits (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  profile_type TEXT NOT NULL,
  daily_limit BIGINT,
  monthly_limit BIGINT,
  UNIQUE(tenant_id, profile_type)
);

-- Leads
CREATE TABLE leads (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  first_name TEXT NOT NULL,
  last_name TEXT,
  phone TEXT,
  email TEXT,
  status TEXT DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'converted', 'lost')),
  source TEXT DEFAULT 'landing',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Invite Codes
CREATE TABLE invite_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  code TEXT UNIQUE NOT NULL,
  profile_type TEXT NOT NULL CHECK (profile_type IN ('morador', 'zelador', 'prestador')),
  max_uses INT DEFAULT 100,
  current_uses INT DEFAULT 0,
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 3. INDEXES
CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_profiles_tenant_id ON profiles(tenant_id);
CREATE INDEX idx_conversations_profile_id ON conversations(profile_id);
CREATE INDEX idx_conversations_tenant_id ON conversations(tenant_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_token_transactions_tenant_id ON token_transactions(tenant_id);
CREATE INDEX idx_token_transactions_created_at ON token_transactions(created_at);
CREATE INDEX idx_invite_codes_code ON invite_codes(code);

-- 4. HELPER FUNCTIONS (Anti-recursion & Security Definer)

-- Check if user is SuperAdmin (Reads from JWT claims or DB)
CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  -- 1. Try to check from JWT claims for performance
  IF (auth.jwt() -> 'app_metadata' ->> 'profile_type') = 'superadmin' THEN
    RETURN TRUE;
  END IF;

  -- 2. Fallback to DB check
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND profile_type = 'superadmin'
  );
END;
$$;

-- Get current user's Tenant ID
CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM profiles WHERE user_id = auth.uid() LIMIT 1;
  RETURN v_tenant_id;
END;
$$;

-- Check if user is Admin or Superadmin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND (profile_type = 'admin' OR profile_type = 'superadmin')
  );
END;
$$;

-- 5. ROW LEVEL SECURITY (RLS)
-- Enable RLS on all tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Tenants Policies
CREATE POLICY "Superadmin sees all tenants" ON tenants FOR SELECT USING (is_superadmin());
CREATE POLICY "Users view own tenant" ON tenants FOR SELECT USING (id = get_user_tenant_id());
CREATE POLICY "Admin update own tenant" ON tenants FOR UPDATE USING (is_admin() AND id = get_user_tenant_id());

-- Profiles Policies
CREATE POLICY "Superadmin sees all profiles" ON profiles FOR SELECT USING (is_superadmin());
CREATE POLICY "Users see profiles from same tenant" ON profiles FOR SELECT USING (tenant_id = get_user_tenant_id());
CREATE POLICY "Users update own profile" ON profiles FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users insert own profile" ON profiles FOR INSERT WITH CHECK (user_id = auth.uid());

-- Conversations Policies
CREATE POLICY "Users view own conversations" ON conversations FOR SELECT 
USING (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()) OR is_superadmin());

CREATE POLICY "Users insert own conversations" ON conversations FOR INSERT 
WITH CHECK (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()) AND tenant_id = get_user_tenant_id());

CREATE POLICY "Users update own conversations" ON conversations FOR UPDATE 
USING (profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid()));

-- Messages Policies
CREATE POLICY "Users view own messages" ON messages FOR SELECT
USING (
    is_superadmin() OR
    EXISTS (
        SELECT 1 FROM conversations c 
        JOIN profiles p ON c.profile_id = p.id
        WHERE c.id = messages.conversation_id AND p.user_id = auth.uid()
    )
);

CREATE POLICY "Users insert own messages" ON messages FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM conversations c 
        JOIN profiles p ON c.profile_id = p.id
        WHERE c.id = messages.conversation_id AND p.user_id = auth.uid()
    )
);

-- Token Transactions Policies
CREATE POLICY "Superadmin view all transactions" ON token_transactions FOR SELECT USING (is_superadmin());
CREATE POLICY "Admins view tenant transactions" ON token_transactions FOR SELECT USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Token Limits Policies
CREATE POLICY "Admins manage tenant limits" ON token_limits FOR ALL USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Leads Policies
CREATE POLICY "Anyone submit leads" ON leads FOR INSERT WITH CHECK (true);
CREATE POLICY "Superadmin view leads" ON leads FOR SELECT USING (is_superadmin());

-- Invite Codes Policies
CREATE POLICY "Anyone read invite codes for validation" ON invite_codes FOR SELECT USING (true);
CREATE POLICY "Admins manage invite codes" ON invite_codes FOR ALL USING (tenant_id = get_user_tenant_id() AND is_admin());

-- 6. TRIGGERS
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenants_updated_at BEFORE UPDATE ON tenants FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER conversations_updated_at BEFORE UPDATE ON conversations FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- 7. BUSINESS RPCs

-- Deduct tokens from tenant
CREATE OR REPLACE FUNCTION deduct_tokens(p_tenant_id UUID, p_amount BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE tenants
  SET token_balance = GREATEST(token_balance - p_amount, 0),
      updated_at = now()
  WHERE id = p_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Increment conversation tokens
CREATE OR REPLACE FUNCTION increment_conversation_tokens(p_conv_id UUID, p_tokens INT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE conversations
  SET tokens_used = tokens_used + p_tokens,
      updated_at = now()
  WHERE id = p_conv_id;
END;
$$;

-- Global Registration (Invite Only for residents/staff)
CREATE OR REPLACE FUNCTION register_user(
  p_user_id UUID,
  p_full_name TEXT,
  p_phone TEXT,
  p_profile_type TEXT,
  p_tenant_name TEXT,
  p_invite_code TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
  v_invite_code_id UUID;
  v_new_profile JSONB;
BEGIN
  -- A. Block public Admin/Superadmin creation
  IF p_profile_type NOT IN ('morador', 'zelador', 'prestador') THEN
    RAISE EXCEPTION 'Perfil não permitido via cadastro público.';
  END IF;

  -- B. Validate Invite Code
  IF p_invite_code IS NULL OR p_invite_code = '' THEN
    RAISE EXCEPTION 'Código de convite é obrigatório.';
  END IF;

  SELECT id, tenant_id INTO v_invite_code_id, v_tenant_id
  FROM invite_codes
  WHERE code = p_invite_code 
    AND profile_type = p_profile_type
    AND (expires_at IS NULL OR expires_at > now())
    AND current_uses < max_uses;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Código de convite inválido ou expirado.';
  END IF;

  -- C. Create Profile
  INSERT INTO profiles (user_id, tenant_id, full_name, phone, profile_type, is_active)
  VALUES (p_user_id, v_tenant_id, p_full_name, p_phone, p_profile_type, true);

  -- D. Update Usage
  UPDATE invite_codes SET current_uses = current_uses + 1 WHERE id = v_invite_code_id;

  SELECT row_to_json(p)::jsonb INTO v_new_profile FROM profiles p WHERE p.user_id = p_user_id LIMIT 1;
  RETURN v_new_profile;
END;
$$;

-- Superadmin Creator for Tenants
CREATE OR REPLACE FUNCTION superadmin_create_tenant_and_admin(
    p_tenant_name text,
    p_plan text,
    p_admin_name text,
    p_admin_email text,
    p_admin_password text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_tenant_id uuid;
    v_user_id uuid;
    v_encrypted_password text;
    v_slug text;
BEGIN
    IF NOT is_superadmin() THEN
        RAISE EXCEPTION 'Acesso negado: apenas superadmins podem criar novos condomínios.';
    END IF;

    v_slug := lower(regexp_replace(p_tenant_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text), 1, 4);

    INSERT INTO tenants (name, slug, plan, status, plan_tokens_total, token_balance)
    VALUES (
        p_tenant_name, v_slug, p_plan, 'active', 
        CASE p_plan WHEN 'starter' THEN 500000 WHEN 'pro' THEN 2000000 WHEN 'enterprise' THEN 10000000 ELSE 500000 END,
        CASE p_plan WHEN 'starter' THEN 500000 WHEN 'pro' THEN 2000000 WHEN 'enterprise' THEN 10000000 ELSE 500000 END
    )
    RETURNING id INTO v_tenant_id;

    v_user_id := gen_random_uuid();
    v_encrypted_password := crypt(p_admin_password, gen_salt('bf'));
    
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, recovery_sent_at, last_sign_in_at, 
        created_at, updated_at, raw_app_meta_data, raw_user_meta_data, 
        is_super_admin, is_sso_user,
        confirmation_token, recovery_token, email_change_token_new,
        email_change_token_current, phone_change_token, reauthentication_token
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', p_admin_email, v_encrypted_password, 
        now(), now(), now(), 
        now(), now(), '{"provider":"email","providers":["email"]}', jsonb_build_object('full_name', p_admin_name, 'profile_type', 'admin'), 
        false, false,
        '', '', '', '', '', ''
    );
    
    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, 
        last_sign_in_at, created_at, updated_at
    )
    VALUES (
        gen_random_uuid(), v_user_id, 
        jsonb_build_object('sub', v_user_id::text, 'email', p_admin_email, 'email_verified', true, 'phone_verified', false), 
        'email', p_admin_email, 
        now(), now(), now()
    );

    UPDATE tenants SET admin_user_id = v_user_id WHERE id = v_tenant_id;
    INSERT INTO profiles (user_id, tenant_id, full_name, profile_type, is_active) VALUES (v_user_id, v_tenant_id, p_admin_name, 'admin', true);

    RETURN jsonb_build_object('success', true, 'tenant_id', v_tenant_id, 'admin_id', v_user_id, 'slug', v_slug);
END;
$$;

-- 8. INITIAL SETUP (INSTRUCTIONS)
/*
PARA CRIAR O PRIMEIRO SUPERADMIN:

DO $$
DECLARE
    v_user_id uuid := gen_random_uuid();
    v_email text := 'admin@xpert.ia'; 
    v_password text := 'Xpert@2026'; 
    v_full_name text := 'Dono da Plataforma';
    v_encrypted_password text;
    -- 1. LIMPEZA E REPARO (Garantir que não haja resquícios nulos)
    DELETE FROM auth.users WHERE email = v_email;
    DELETE FROM auth.identities WHERE identity_data->>'email' = v_email;
    DELETE FROM public.profiles WHERE user_id IN (SELECT id FROM auth.users WHERE email = v_email);

    v_encrypted_password := crypt(v_password, gen_salt('bf'));

    -- 2. INSERÇÃO TOTAL (Evita erro de Scan NULL no GoTrue)
    INSERT INTO auth.users (
        instance_id, id, aud, role, email, encrypted_password, 
        email_confirmed_at, last_sign_in_at, raw_app_meta_data, 
        raw_user_meta_data, is_super_admin, created_at, updated_at,
        confirmed_at, is_sso_user, 
        confirmation_token, recovery_token, email_change_token_new,
        email_change_token_current, phone_change_token, reauthentication_token,
        deleted_at
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000', v_user_id, 'authenticated', 'authenticated', v_email, v_encrypted_password, 
        now(), now(), '{"provider": "email", "providers": ["email"]}', 
        jsonb_build_object('full_name', v_full_name, 'profile_type', 'superadmin'), 
        false, now(), now(), 
        now(), false,
        '', '', '', '', '', '', -- NUNCA DEIXAR NULL (Causa Erro 500 no GoTrue)
        NULL
    );
    
    -- 3. AUTH.IDENTITIES (Vinculada corretamente ao user_id)
    INSERT INTO auth.identities (
        id, user_id, identity_data, provider, provider_id, 
        last_sign_in_at, created_at, updated_at
    )
    VALUES (
        v_user_id, v_user_id, 
        jsonb_build_object('sub', v_user_id::text, 'email', v_email, 'email_verified', true, 'phone_verified', false), 
        'email', v_email, 
        now(), now(), now()
    );

    -- 4. PERFIL PÚBLICO
    INSERT INTO public.profiles (user_id, full_name, profile_type, is_active)
    VALUES (v_user_id, v_full_name, 'superadmin', true);

END $$;
*/

/*
SOLUÇÃO DEFINITIVA (CASO O SQL ACIMA DÊ ERRO 500):
Execute este comando no seu terminal (PowerShell) para criar o usuário via API oficial:

$env:SB_URL="https://vsbeekboxuqrmkmhbypv.supabase.co"
$env:SB_KEY="PASTE_YOUR_SERVICE_ROLE_KEY_HERE"

Invoke-RestMethod -Uri "$env:SB_URL/auth/v1/admin/users" `
  -Method Post `
  -Headers @{ "Authorization" = "Bearer $env:SB_KEY"; "apikey" = "$env:SB_KEY" } `
  -ContentType "application/json" `
  -Body '{
    "email": "admin@xpert.ia",
    "password": "Xpert@2026",
    "email_confirm": true,
    "user_metadata": { "full_name": "Dono da Plataforma", "profile_type": "superadmin" }
  }'
*/
