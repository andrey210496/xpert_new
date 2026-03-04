-- =============================================
-- CONSOLIDATED MULTI-TENANT ARCHITECTURE
-- Run this to ensure all RLS are correctly isolated
-- =============================================

-- 1. ADICIONAR COLUNA DE CONTEXTO (Se não existir)
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tenants' AND column_name='tenant_context') THEN
        ALTER TABLE tenants ADD COLUMN tenant_context TEXT;
    END IF;
END $$;

-- 2. GARANTIR QUE AS FUNÇÕES HELPERS ESTEJAM USANDO PLPGSQL (Anti-recursion)
-- (Já fizemos isso no fix_rls_functions.sql, mas garantimos aqui como âncora)

-- 3. RESET DE POLÍTICAS (Limpeza para garantir consistência)
DROP POLICY IF EXISTS "Users can view own tenant" ON tenants;
DROP POLICY IF EXISTS "Admin can update own tenant" ON tenants;
DROP POLICY IF EXISTS "Superadmin can view all tenants" ON tenants;

DROP POLICY IF EXISTS "Users can view profiles in their tenant" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
DROP POLICY IF EXISTS "Superadmin can view all profiles" ON profiles;

DROP POLICY IF EXISTS "Users can view own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can insert own conversations" ON conversations;
DROP POLICY IF EXISTS "Users can update own conversations" ON conversations;

DROP POLICY IF EXISTS "Users can view own messages" ON messages;
DROP POLICY IF EXISTS "Users can insert own messages" ON messages;

-- 4. NOVAS POLÍTICAS BLINDADAS POR TENANT

-- TENANTS: Superadmin vê tudo. Admin vê apenas o seu.
CREATE POLICY "Superadmin sees all tenants" ON tenants FOR SELECT USING (is_superadmin());
CREATE POLICY "Users can view own tenant" ON tenants FOR SELECT USING (id = get_user_tenant_id());
CREATE POLICY "Admin can update own tenant" ON tenants FOR UPDATE USING (is_admin() AND id = get_user_tenant_id());

-- PROFILES: Superadmin vê tudo. Usuários veem apenas quem é do mesmo condomínio.
CREATE POLICY "Superadmin sees all profiles" ON profiles FOR SELECT USING (is_superadmin());
CREATE POLICY "Users see profiles from same tenant" ON profiles FOR SELECT USING (tenant_id = get_user_tenant_id());
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (user_id = auth.uid());

-- CONVERSATIONS: Isolamento total por tenant_id
CREATE POLICY "Users view own tenant conversations" ON conversations FOR SELECT USING (tenant_id = get_user_tenant_id() OR is_superadmin());
CREATE POLICY "Users insert own tenant conversations" ON conversations FOR INSERT WITH CHECK (tenant_id = get_user_tenant_id());
CREATE POLICY "Users update own tenant conversations" ON conversations FOR UPDATE USING (tenant_id = get_user_tenant_id());

-- MESSAGES: Vínculo indireto via conversation -> tenant_id
CREATE POLICY "Users view messages from own tenant" ON messages FOR SELECT 
USING (
    is_superadmin() OR
    EXISTS (
        SELECT 1 FROM conversations c 
        WHERE c.id = messages.conversation_id 
        AND c.tenant_id = get_user_tenant_id()
    )
);

CREATE POLICY "Users insert messages into own tenant" ON messages FOR INSERT 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM conversations c 
        WHERE c.id = messages.conversation_id 
        AND c.tenant_id = get_user_tenant_id()
    )
);

-- INVITE CODES: Síndico gerencia. Usuário comum apenas Lê (para validar).
DROP POLICY IF EXISTS "Anyone can read invite codes" ON invite_codes;
DROP POLICY IF EXISTS "Admins can manage invite codes" ON invite_codes;

CREATE POLICY "Anyone can read invite codes for validation" ON invite_codes FOR SELECT USING (true);
CREATE POLICY "Admins manage own tenant invite codes" ON invite_codes FOR ALL 
USING (tenant_id = get_user_tenant_id() AND is_admin());

-- 5. RPC DE REGISTRO REFINADA (Apenas via Convite)
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
  -- A. Bloquear criação pública de Síndicos e Superadmins
  -- (Estes devem ser criados apenas pela RPC de Superadmin ou manualmente)
  IF p_profile_type NOT IN ('morador', 'zelador', 'prestador') THEN
    RAISE EXCEPTION 'Perfil não permitido via cadastro público. Contate o suporte.';
  END IF;

  -- B. Validar Código de Convite
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
    RAISE EXCEPTION 'Código de convite inválido, expirado ou com limite de usos atingido.';
  END IF;

  -- C. Criar o perfil vinculado ao condomínio do convite
  INSERT INTO profiles (user_id, tenant_id, full_name, phone, profile_type, is_active)
  VALUES (p_user_id, v_tenant_id, p_full_name, p_phone, p_profile_type, true);

  -- D. Atualizar uso do convite
  UPDATE invite_codes SET current_uses = current_uses + 1 WHERE id = v_invite_code_id;

  -- E. Retornar os dados do perfil
  SELECT row_to_json(p)::jsonb INTO v_new_profile 
  FROM profiles p 
  WHERE p.user_id = p_user_id 
  LIMIT 1;
  
  RETURN v_new_profile;
EXCEPTION
  WHEN unique_violation THEN
    RAISE EXCEPTION 'Este usuário já possui um perfil cadastrado.';
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao registrar usuário: %', SQLERRM;
END;
$$;

-- NOTA: O campo is_superadmin() e get_user_tenant_id() devem ser os PLPGSQL
-- criados no arquivo anterior para maior segurança e performance.
