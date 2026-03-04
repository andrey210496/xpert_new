-- Executar este comando via SQL Editor no Supabase para criar o PRIMEIRO SuperAdmin do sistema.
-- Lembre-se de deletar ou manter confidencial as senhas deste arquivo.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
    v_user_id uuid := gen_random_uuid();
    v_email text := 'admin@xpert.ia'; -- <-- Mude para seu email desejado
    v_password text := 'Xpert@2026'; -- <-- Mude para sua senha forte
    v_full_name text := 'Dono da Plataforma';
    v_encrypted_password text;
BEGIN
    v_encrypted_password := crypt(v_password, gen_salt('bf'));

    -- 1. Cria a Autenticação no GoTrue (auth.users)
    INSERT INTO auth.users (
        instance_id,
        id,
        aud,
        role,
        email,
        encrypted_password,
        email_confirmed_at,
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
        v_email,
        v_encrypted_password,
        now(),
        now(),
        now(),
        '{"provider":"email","providers":["email"]}',
        jsonb_build_object('full_name', v_full_name, 'profile_type', 'superadmin')
    );
    
    -- 2. Identidade de Login
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
        format('{"sub":"%s","email":"%s"}', v_user_id::text, v_email)::jsonb,
        'email',
        v_email,
        now(),
        now(),
        now()
    );

    -- 3. Cria o perfil público na nossa tabela definindo o poder de Superadmin
    INSERT INTO profiles (id, full_name, profile_type)
    VALUES (v_user_id, v_full_name, 'superadmin');

END $$;
