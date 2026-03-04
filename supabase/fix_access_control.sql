-- =============================================
-- FIX: ACCESS CONTROL & SUPERADMIN POLICIES
-- Run this AFTER schema.sql and update_policies.sql
-- =============================================

-- =============================================
-- 1. FIX: Profile Type CHECK Constraint
-- Add 'superadmin' to the allowed profile types
-- =============================================

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS profiles_profile_type_check;
ALTER TABLE profiles ADD CONSTRAINT profiles_profile_type_check 
  CHECK (profile_type IN ('admin', 'morador', 'zelador', 'prestador', 'superadmin'));


-- =============================================
-- 2. NEW HELPER: is_superadmin()
-- =============================================

CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND profile_type = 'superadmin'
  );
$$;


-- =============================================
-- 3. FIX: Conversations RLS
-- Users should only see THEIR OWN conversations
-- (not all conversations in the tenant)
-- =============================================

DROP POLICY IF EXISTS "Users can view own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can insert own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON conversations;

-- SELECT: user only sees conversations where profile_id matches their profile
CREATE POLICY "Users can view own conversations"
  ON conversations FOR SELECT
  USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
    OR is_superadmin()
  );

-- INSERT: user can only create conversations linked to their own profile
CREATE POLICY "Users can insert own conversations"
  ON conversations FOR INSERT
  WITH CHECK (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
    AND tenant_id = get_user_tenant_id()
  );

-- UPDATE: user can only update their own conversations
CREATE POLICY "Users can update own conversations"
  ON conversations FOR UPDATE
  USING (
    profile_id IN (SELECT id FROM profiles WHERE user_id = auth.uid())
  );


-- =============================================
-- 4. FIX: Messages RLS
-- Messages are only visible through user's own conversations
-- =============================================

DROP POLICY IF EXISTS "Users can view own messages" ON messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON messages;

CREATE POLICY "Users can view own messages"
  ON messages FOR SELECT
  USING (conversation_id IN (
    SELECT c.id FROM conversations c
    JOIN profiles p ON c.profile_id = p.id
    WHERE p.user_id = auth.uid()
  ));

CREATE POLICY "Users can insert own messages"
  ON messages FOR INSERT
  WITH CHECK (conversation_id IN (
    SELECT c.id FROM conversations c
    JOIN profiles p ON c.profile_id = p.id
    WHERE p.user_id = auth.uid()
  ));


-- =============================================
-- 5. SUPERADMIN: Global Read Access
-- Superadmin can view ALL tenants and leads
-- =============================================

DROP POLICY IF EXISTS "Superadmin can view all tenants" ON tenants;
DROP POLICY IF EXISTS "Superadmin can view all leads" ON leads;
DROP POLICY IF EXISTS "Superadmin can view all transactions" ON token_transactions;
DROP POLICY IF EXISTS "Superadmin can view all profiles" ON profiles;

-- Tenants: superadmin can view all
CREATE POLICY "Superadmin can view all tenants"
  ON tenants FOR SELECT
  USING (is_superadmin());

-- Leads: superadmin can view all
CREATE POLICY "Superadmin can view all leads"
  ON leads FOR SELECT
  USING (is_superadmin());

-- Token transactions: superadmin can view all
CREATE POLICY "Superadmin can view all transactions"
  ON token_transactions FOR SELECT
  USING (is_superadmin());

-- Profiles: superadmin can view all profiles
CREATE POLICY "Superadmin can view all profiles"
  ON profiles FOR SELECT
  USING (is_superadmin());
-- =============================================
-- 6. NEW RPC: increment_conversation_tokens
-- =============================================

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
