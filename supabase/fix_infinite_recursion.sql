-- =============================================
-- FIX: INFINITE RECURSION na RLS de Profiles e Superadmin
-- =============================================

-- O erro "Database error querying schema" ao logar acontece porque a função is_superadmin() 
-- consulta a tabela "profiles" para verificar quem é superadmin e as Políticas (Policies) 
-- da própria tabela "profiles" usam a função is_superadmin().
-- Isto cria um Loop Infinito (Recursão)!

-- 1. Substituir is_superadmin() por uma versão segura baseada no Token de Autenticação JWT 
-- Ou lendo direto os metadados brutos do auth.users, que nunca entra em Políticas (RLS bypass)

CREATE OR REPLACE FUNCTION is_superadmin()
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  -- Lê a permissão diretamente dos metas injetados na conta, sem consultar a tabela de profiles!
  SELECT coalesce(
    (current_setting('request.jwt.claims', true)::jsonb -> 'user_metadata' ->> 'profile_type') = 'superadmin',
    false
  );
$$;

-- 2. Reescrever as Políticas da tabela profiles para garantir segurança extra

DROP POLICY IF EXISTS "Superadmin can view all profiles" ON profiles;

CREATE POLICY "Superadmin can view all profiles"
  ON profiles FOR SELECT
  USING (
    is_superadmin()
  );

-- Opcional: Garantir que a policy de acesso próprio em profiles (se não existir) esteja declarada
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;

CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (id = auth.uid()); 
