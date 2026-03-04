-- 1. Garantir que a extensão pgcrypto esteja habilitada
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

-- 2. Garantir coluna status
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tenants' AND column_name='status') THEN
        ALTER TABLE tenants ADD COLUMN status TEXT DEFAULT 'active';
    END IF;
END $$;

-- 3. RPC Consolidada e Robusta
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
    -- A. Verificar se é SuperAdmin
    IF NOT is_superadmin() THEN
        RAISE EXCEPTION 'Acesso negado: apenas superadmins podem criar novos condomínios.';
    END IF;

    -- B. Gerar Slug
    v_slug := lower(regexp_replace(p_tenant_name, '[^a-zA-Z0-9]+', '-', 'g')) || '-' || substr(md5(random()::text), 1, 4);

    -- C. Criar o Condomínio (Tenant)
    INSERT INTO tenants (name, slug, plan, status, plan_tokens_total, token_balance)
    VALUES (
        p_tenant_name,
        v_slug,
        p_plan, 
        'active', 
        CASE p_plan
            WHEN 'starter' THEN 500000
            WHEN 'pro' THEN 2000000
            WHEN 'enterprise' THEN 10000000
            ELSE 500000
        END,
        CASE p_plan
            WHEN 'starter' THEN 500000
            WHEN 'pro' THEN 2000000
            WHEN 'enterprise' THEN 10000000
            ELSE 500000
        END
    )
    RETURNING id INTO v_tenant_id;

    -- D. Criar o Usuário de Autenticação (Com todos os campos obrigatórios do Supabase 2025)
    v_user_id := gen_random_uuid();
    v_encrypted_password := crypt(p_admin_password, gen_salt('bf'));
    
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
        last_sign_in_at,
        created_at,
        updated_at,
        raw_app_meta_data,
        raw_user_meta_data
    )
    VALUES (
        '00000000-0000-0000-0000-000000000000',
        v_user_id,
        'authenticated',
        'authenticated',
        p_admin_email,
        v_encrypted_password,
        now(),
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('full_name', p_admin_name, 'profile_type', 'admin')
    );
    
    -- E. Criar Identidade (Vínculo de login)
    INSERT INTO auth.identities (
        id,
        user_id,
        identity_data,
        provider,
        provider_id,
        last_sign_in_at,
        created_at,
        updated_at
    )
    VALUES (
        gen_random_uuid(),
        v_user_id,
        format('{"sub":"%s","email":"%s"}', v_user_id::text, p_admin_email)::jsonb,
        'email',
        p_admin_email,
        now(),
        now(),
        now()
    );

    -- F. Vincular o Admin ao Tenant e vice-versa
    UPDATE tenants SET admin_user_id = v_user_id WHERE id = v_tenant_id;

    -- G. Criar Perfil Público
    INSERT INTO profiles (user_id, tenant_id, full_name, profile_type, is_active)
    VALUES (v_user_id, v_tenant_id, p_admin_name, 'admin', true);

    RETURN jsonb_build_object(
        'success', true, 
        'tenant_id', v_tenant_id, 
        'admin_id', v_user_id,
        'slug', v_slug
    );
EXCEPTION 
    WHEN unique_violation THEN
        RAISE EXCEPTION 'O e-mail ou nome (slug) do condomínio já está em uso.';
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Erro fatal ao criar condomínio: %', SQLERRM;
END;
$$;
