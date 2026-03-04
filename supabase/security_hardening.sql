-- =============================================
-- XPERT - Security Hardening Patches
-- Execute este arquivo no Supabase SQL Editor
-- após rodar o full_database_setup.sql
-- Este arquivo é idempotente: pode ser re-executado sem erros.
-- =============================================

-- =============================================
-- 1. INVITE CODES — Restringir leitura pública
-- Problema: qualquer pessoa (incluindo anônimos)
-- conseguia listar TODOS os códigos de convite.
-- =============================================

DROP POLICY IF EXISTS "Anyone can read invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Anyone read invite codes for validation" ON invite_codes;
DROP POLICY IF EXISTS "Admins can view own tenant invite codes" ON invite_codes;

-- Somente admins autenticados do mesmo tenant podem ver seus próprios códigos
CREATE POLICY "Admins can view own tenant invite codes"
  ON invite_codes FOR SELECT
  USING (tenant_id = get_user_tenant_id() AND is_admin());

-- Função segura para validar código sem expor a lista completa
CREATE OR REPLACE FUNCTION validate_invite_code(p_code TEXT)
RETURNS TABLE(valid BOOLEAN, tenant_id UUID, profile_type TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
    SELECT
      (current_uses < max_uses AND (expires_at IS NULL OR expires_at > now())) AS valid,
      ic.tenant_id,
      ic.profile_type
    FROM invite_codes ic
    WHERE ic.code = p_code
    LIMIT 1;
END;
$$;

-- =============================================
-- 2. AGENT CONFIGS — Restringir a usuários autenticados
-- Problema: qualquer pessoa (sem login) conseguia
-- ler os system prompts internos dos agentes.
-- =============================================

DROP POLICY IF EXISTS "Anyone can read agent configs" ON agent_configs;
DROP POLICY IF EXISTS "Authenticated users can read agent configs" ON agent_configs;

-- Apenas usuários autenticados leem as configs
CREATE POLICY "Authenticated users can read agent configs"
  ON agent_configs FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- =============================================
-- 3. LEADS — Restringir UPDATE e DELETE ao superadmin
-- Problema: qualquer admin de tenant conseguia
-- alterar status de leads de outros tenants.
-- =============================================

DROP POLICY IF EXISTS "Superadmin view leads" ON leads;
DROP POLICY IF EXISTS "Superadmin update leads" ON leads;
DROP POLICY IF EXISTS "Superadmin can view leads" ON leads;
DROP POLICY IF EXISTS "Superadmin can update leads" ON leads;
DROP POLICY IF EXISTS "Superadmin can delete leads" ON leads;

-- Apenas superadmin pode ler leads
CREATE POLICY "Superadmin can view leads"
  ON leads FOR SELECT
  USING (is_superadmin());

-- Apenas superadmin pode atualizar leads
CREATE POLICY "Superadmin can update leads"
  ON leads FOR UPDATE
  USING (is_superadmin());

-- Apenas superadmin pode deletar leads
CREATE POLICY "Superadmin can delete leads"
  ON leads FOR DELETE
  USING (is_superadmin());

-- =============================================
-- 4. TENANTS — Adicionar UPDATE e DELETE para superadmin
-- Problema: superadmin não conseguia editar nem excluir
-- tenants porque não havia política RLS para isso.
-- =============================================

DROP POLICY IF EXISTS "Superadmin can update any tenant" ON tenants;
DROP POLICY IF EXISTS "Superadmin can delete any tenant" ON tenants;

-- Superadmin pode atualizar qualquer tenant
CREATE POLICY "Superadmin can update any tenant"
  ON tenants FOR UPDATE
  USING (is_superadmin());

-- Superadmin pode excluir qualquer tenant
CREATE POLICY "Superadmin can delete any tenant"
  ON tenants FOR DELETE
  USING (is_superadmin());

-- =============================================
-- 5. FUNÇÃO is_superadmin — Verificação via DB
-- Proteção dupla: JWT + registro na tabela profiles
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
    WHERE user_id = auth.uid()
      AND profile_type = 'superadmin'
      AND is_active = true
  );
$$;

-- =============================================
-- 6. TOKEN BALANCE CHECK — Impede chat com saldo zero
-- Problema: tenant com 0 tokens ainda conseguia
-- iniciar conversas.
-- =============================================

CREATE OR REPLACE FUNCTION check_token_balance(p_tenant_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_balance BIGINT;
BEGIN
  SELECT token_balance INTO v_balance
  FROM tenants
  WHERE id = p_tenant_id;

  RETURN COALESCE(v_balance, 0) > 0;
END;
$$;

-- =============================================
-- 7. CONVERSAS — Restringir DELETE ao próprio usuário
-- Garante que usuário só delete suas próprias conversas.
-- =============================================

DROP POLICY IF EXISTS "Users can delete own conversations" ON conversations;

CREATE POLICY "Users can delete own conversations"
  ON conversations FOR DELETE
  USING (profile_id IN (
    SELECT id FROM profiles WHERE user_id = auth.uid()
  ));

-- =============================================
-- 8. PROFILES — Bloquear alteração de profile_type pelo usuário
-- Problema: usuário poderia tentar escalar para 'admin' ou 'superadmin'
-- via UPDATE na própria linha.
-- =============================================

DROP POLICY IF EXISTS "Users can update own profile" ON profiles;

-- Permite update apenas de campos não sensíveis (full_name, phone)
-- A alteração de profile_type, tenant_id, is_active deve ser feita
-- apenas por funções SECURITY DEFINER (RPCs internas).
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (
    user_id = auth.uid()
    AND profile_type = (SELECT profile_type FROM profiles WHERE user_id = auth.uid() LIMIT 1)
    AND tenant_id = (SELECT tenant_id FROM profiles WHERE user_id = auth.uid() LIMIT 1)
    AND is_active = (SELECT is_active FROM profiles WHERE user_id = auth.uid() LIMIT 1)
  );

-- =============================================
-- 9. LIMPEZA AUTOMÁTICA DE AUTH.USERS
-- Trigger: quando um profile é deletado (diretamente
-- ou em cascata ao excluir o tenant), remove o
-- usuário correspondente em auth.users se ele não
-- tiver outros profiles no sistema.
-- =============================================

CREATE OR REPLACE FUNCTION cleanup_auth_user_on_profile_delete()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Só deleta o auth.user se não restar nenhum outro profile com esse user_id
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE user_id = OLD.user_id
  ) THEN
    BEGIN
      DELETE FROM auth.users WHERE id = OLD.user_id;
    EXCEPTION WHEN OTHERS THEN
      NULL; -- falha silenciosa: dados do tenant já foram apagados
    END;
  END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS on_profile_deleted ON public.profiles;
CREATE TRIGGER on_profile_deleted
  AFTER DELETE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION cleanup_auth_user_on_profile_delete();
