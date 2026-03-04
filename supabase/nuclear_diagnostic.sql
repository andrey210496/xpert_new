-- 1. AUDITORIA DE EXISTÊNCIA (Onde está a tabela profiles?)
SELECT 
    schemaname as esquema, 
    tablename as tabela, 
    tableowner as dono 
FROM pg_catalog.pg_tables 
WHERE tablename = 'profiles';

-- 2. VERIFICAR COLUNAS (Existe algum tipo de dado estranho?)
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles' AND table_schema = 'public';

-- 3. RESET TOTAL DE PERMISSÕES (Se a 406 persiste, a API está bloqueada)
ALTER TABLE public.profiles OWNER TO postgres;
GRANT ALL ON TABLE public.profiles TO postgres, service_role, authenticated, anon;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Forçar recarregamento (Rode isso após os comandos acima)
NOTIFY pgrst, 'reload schema';


-- 3. RESOLVER ERRO 406 (Not Acceptable) - Forçar visibilidade para a API
-- Ajusta o caminho de busca para a API encontrar tabelas em public e auth
ALTER ROLE authenticator SET search_path TO public, auth;

-- Garante que os papéis da API tenham acesso ao esquema e tabelas
GRANT USAGE ON SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO anon, authenticated;

-- Força a API a recarregar tudo com as novas permissões
NOTIFY pgrst, 'reload schema';

-- 4. AGORA TENTE O POWERSHELL NOVAMENTE.

/*
===========================================================
COMO VER O ERRO REAL (Se o 500 continuar):
===========================================================
Acesse seu Dashboard do Supabase:
1. Vá em "Logs" (ícone de relógio no menu lateral esquerdo).
2. Clique em "Postgres logs".
3. Procure por mensagens de erro em VERMELHO que aconteceram 
   exatamente no momento da sua tentativa.
4. Me mande esse erro. Ele dirá "ERROR: column 'xyz' does not exist" 
   ou algo similar que é a causa real do 500.
===========================================================
*/
