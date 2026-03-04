-- =============================================
-- FIX: POSTGRESQL INLINING CAUSING RLS RECURSION
-- =============================================
-- Funções `LANGUAGE sql` sofrem inlining pelo otimizador do Postgres, o que faz com que
-- as verificações de `SECURITY DEFINER` falhem em alguns contextos de RLS e voltem a gerar Loop (Recursão).
-- A solução definitiva é forçar as funções de auxílio de autenticação a usarem `LANGUAGE plpgsql`.

-- 1. Helper: Pegar Tenant ID do Usuário Logado
CREATE OR REPLACE FUNCTION get_user_tenant_id()
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id UUID;
BEGIN
  SELECT tenant_id INTO v_tenant_id FROM profiles WHERE user_id = auth.uid() LIMIT 1;
  RETURN v_tenant_id;
END;
$$;

-- 2. Helper: Checar se o usuário é Admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_admin BOOLEAN;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND (profile_type = 'admin' OR profile_type = 'superadmin')
  ) INTO v_is_admin;
  RETURN v_is_admin;
END;
$$;

-- 3. Helper: Checar se o usuário é superadmin (Lendo do Token JWT com fallback pro banco)
CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_super BOOLEAN;
  v_profile_type TEXT;
BEGIN
  -- Tenta ler do metadata primeiro (muito mais rápido e não lê tabela)
  v_profile_type := current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'profile_type';
  
  IF v_profile_type = 'superadmin' THEN
    RETURN true;
  END IF;

  -- Fallback seguro lendo a tabela (blindado contra inlining)
  SELECT EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() AND profile_type = 'superadmin'
  ) INTO v_is_super;
  
  RETURN coalesce(v_is_super, false);
END;
$$;

-- 4. Vamos recriar apenas a Policy principal do PROFILE para garantir que está limpa
DROP POLICY IF EXISTS "Users can view profiles in their tenant" ON profiles;

CREATE POLICY "Users can view profiles in their tenant"
  ON profiles FOR SELECT
  USING (
    tenant_id = get_user_tenant_id() 
    OR user_id = auth.uid()
  );
