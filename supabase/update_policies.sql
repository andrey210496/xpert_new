-- =============================================
-- RLS FIX: DROPPING OLD POLICIES
-- =============================================

DROP POLICY IF EXISTS "Users can view profiles in their tenant" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

DROP POLICY IF EXISTS "Users can view own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can insert own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON conversations;

DROP POLICY IF EXISTS "Users can view own messages" ON messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON messages;

DROP POLICY IF EXISTS "Admins can view tenant transactions" ON token_transactions;

DROP POLICY IF EXISTS "Admins can view tenant limits" ON token_limits;
DROP POLICY IF EXISTS "Admins can manage tenant limits" ON token_limits;

DROP POLICY IF EXISTS "Anyone can read invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Admins can manage invite codes" ON invite_codes;


-- =============================================
-- ROW LEVEL SECURITY (RLS) HELPERS
-- =============================================

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
-- CREATING NEW SAFE POLICIES
-- =============================================

-- Profiles
CREATE POLICY "Users can view profiles in their tenant"
  ON profiles FOR SELECT
  USING (tenant_id = get_user_tenant_id() OR user_id = auth.uid());

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (user_id = auth.uid());

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (user_id = auth.uid());

-- Conversations
CREATE POLICY "Users can view own conversations"
  ON conversations FOR SELECT
  USING (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can insert own conversations"
  ON conversations FOR INSERT
  WITH CHECK (tenant_id = get_user_tenant_id());

CREATE POLICY "Users can update own conversations"
  ON conversations FOR UPDATE
  USING (tenant_id = get_user_tenant_id());

-- Messages
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

-- Token Transactions
CREATE POLICY "Admins can view tenant transactions"
  ON token_transactions FOR SELECT
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Token Limits
CREATE POLICY "Admins can view tenant limits"
  ON token_limits FOR SELECT
  USING (tenant_id = get_user_tenant_id() AND is_admin());

CREATE POLICY "Admins can manage tenant limits"
  ON token_limits FOR ALL
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Invite Codes
CREATE POLICY "Anyone can read invite codes"
  ON invite_codes FOR SELECT
  USING (true);

CREATE POLICY "Admins can manage invite codes"
  ON invite_codes FOR ALL
  USING (tenant_id = get_user_tenant_id() AND is_admin());
