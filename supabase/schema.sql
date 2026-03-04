-- =============================================
-- XPERT - Database Schema (Supabase/PostgreSQL)
-- =============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- TABLES
-- =============================================

-- Tenants (Condomínios/Administradoras)
CREATE TABLE tenants (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  slug TEXT UNIQUE NOT NULL,
  admin_user_id UUID REFERENCES auth.users(id),
  token_balance BIGINT DEFAULT 0,
  plan TEXT DEFAULT 'trial' CHECK (plan IN ('trial', 'starter', 'pro', 'enterprise')),
  plan_tokens_total BIGINT DEFAULT 50000,
  settings JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Profiles
CREATE TABLE profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id UUID REFERENCES tenants(id) ON DELETE CASCADE,
  full_name TEXT NOT NULL,
  phone TEXT,
  profile_type TEXT NOT NULL CHECK (profile_type IN ('admin', 'morador', 'zelador', 'prestador')),
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

-- =============================================
-- INDEXES
-- =============================================

CREATE INDEX idx_profiles_user_id ON profiles(user_id);
CREATE INDEX idx_profiles_tenant_id ON profiles(tenant_id);
CREATE INDEX idx_conversations_profile_id ON conversations(profile_id);
CREATE INDEX idx_conversations_tenant_id ON conversations(tenant_id);
CREATE INDEX idx_messages_conversation_id ON messages(conversation_id);
CREATE INDEX idx_token_transactions_tenant_id ON token_transactions(tenant_id);
CREATE INDEX idx_token_transactions_created_at ON token_transactions(created_at);
CREATE INDEX idx_invite_codes_code ON invite_codes(code);

-- =============================================
-- RPC FUNCTIONS
-- =============================================

-- Deduct tokens from tenant balance
CREATE OR REPLACE FUNCTION deduct_tokens(p_tenant_id UUID, p_amount BIGINT)
RETURNS VOID AS $$
BEGIN
  UPDATE tenants
  SET token_balance = GREATEST(token_balance - p_amount, 0),
      updated_at = now()
  WHERE id = p_tenant_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =============================================
-- ROW LEVEL SECURITY (RLS) HELPERS
-- =============================================

-- Security definer functions bypass RLS to prevent infinite recursion

CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS UUID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT tenant_id FROM profiles WHERE user_id = auth.uid() LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND (profile_type = 'admin' OR profile_type = 'superadmin')
  );
$$;

-- =============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =============================================

-- Enable RLS on all tables
ALTER TABLE tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE token_limits ENABLE ROW LEVEL SECURITY;
ALTER TABLE leads ENABLE ROW LEVEL SECURITY;
ALTER TABLE invite_codes ENABLE ROW LEVEL SECURITY;

-- Tenants: users can only see their own tenant
CREATE POLICY "Users can view own tenant"
  ON tenants FOR SELECT
  USING (id IN (SELECT tenant_id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Admin can update own tenant"
  ON tenants FOR UPDATE
  USING (admin_user_id = auth.uid());

-- Profiles: users can see profiles in their tenant
CREATE POLICY "Users can view profiles in their tenant"
  ON profiles FOR SELECT
  USING (tenant_id = get_user_tenant_id() OR user_id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Conversations: users can only see their own conversations
CREATE POLICY "Users can view own conversations"
  ON conversations FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can insert own conversations"
  ON conversations FOR INSERT
  WITH CHECK (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can update own conversations"
  ON conversations FOR UPDATE
  USING (tenant_id = get_user_tenant_id());

-- Messages: users can see messages in their conversations
CREATE POLICY "Users can view own messages"
  ON messages FOR SELECT
  USING (conversation_id IN (
    SELECT id FROM conversations WHERE tenant_id = get_user_tenant_id()
  ));

CREATE POLICY "Users can insert own messages"
  ON messages FOR INSERT
  WITH CHECK (conversation_id IN (
    SELECT id FROM conversations WHERE tenant_id = get_user_tenant_id()
  ));

-- Token Transactions: admins can view, service role can insert
CREATE POLICY "Admins can view tenant transactions"
  ON token_transactions FOR SELECT
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Token Limits: admins can manage
CREATE POLICY "Admins can view tenant limits"
  ON token_limits FOR SELECT
  USING (tenant_id = get_user_tenant_id() AND is_admin());

CREATE POLICY "Admins can manage tenant limits"
  ON token_limits FOR ALL
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Leads: anyone can insert (public form), only service role can read
CREATE POLICY "Anyone can submit leads"
  ON leads FOR INSERT
  WITH CHECK (true);

-- Invite Codes: public can read (to validate), admins can manage
CREATE POLICY "Anyone can read invite codes"
  ON invite_codes FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage invite codes"
  ON invite_codes FOR ALL
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- =============================================
-- TRIGGERS
-- =============================================

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tenants_updated_at
  BEFORE UPDATE ON tenants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER conversations_updated_at
  BEFORE UPDATE ON conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
