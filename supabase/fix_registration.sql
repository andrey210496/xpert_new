-- =============================================
-- FIX: ROBUST USER REGISTRATION WITH TENANTS
-- =============================================

-- Create an RPC to handle user registration safely
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
  -- Validate profile type
  IF p_profile_type NOT IN ('admin', 'morador', 'zelador', 'prestador', 'superadmin') THEN
    RAISE EXCEPTION 'Invalid profile type: %', p_profile_type;
  END IF;

  -- Handle Tenant linking or creation
  IF p_profile_type = 'admin' THEN
    IF p_tenant_name IS NULL OR p_tenant_name = '' THEN
      RAISE EXCEPTION 'Nome do condomínio é obrigatório para o síndico.';
    END IF;
    
    -- Insert new tenant
    INSERT INTO tenants (name, slug, admin_user_id)
    VALUES (
      p_tenant_name, 
      lower(regexp_replace(p_tenant_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text), 1, 4), 
      p_user_id
    )
    RETURNING id INTO v_tenant_id;
  ELSE
    -- Must use an invite code
    IF p_invite_code IS NULL OR p_invite_code = '' THEN
      RAISE EXCEPTION 'Código de convite é obrigatório para moradores, zeladores e prestadores.';
    END IF;

    SELECT id, tenant_id INTO v_invite_code_id, v_tenant_id
    FROM invite_codes
    WHERE code = p_invite_code AND profile_type = p_profile_type;

    IF v_tenant_id IS NULL THEN
      RAISE EXCEPTION 'Código de convite inválido ou não autorizado para este perfil.';
    END IF;

    -- Update invite code usage
    UPDATE invite_codes SET current_uses = current_uses + 1 WHERE id = v_invite_code_id;
  END IF;

  -- Insert the profile
  INSERT INTO profiles (user_id, tenant_id, full_name, phone, profile_type, is_active)
  VALUES (p_user_id, v_tenant_id, p_full_name, p_phone, p_profile_type, true);

  -- Retrieve and return the inserted profile
  SELECT row_to_json(p)::jsonb INTO v_new_profile 
  FROM profiles p 
  WHERE p.user_id = p_user_id 
  LIMIT 1;
  
  RETURN v_new_profile;
EXCEPTION
  WHEN unique_violation THEN
    -- In case of slug collision or code collision
    RAISE EXCEPTION 'Erro de unicidade: verifique se o condomínio ou código já existe. (%)', SQLERRM;
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Erro ao registrar usuário: %', SQLERRM;
END;
$$;
