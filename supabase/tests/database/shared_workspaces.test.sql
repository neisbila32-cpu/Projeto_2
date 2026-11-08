BEGIN;
SET LOCAL search_path = public, extensions;

SELECT no_plan();

INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('c3100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'admin@exemplo.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('c3100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'operador@exemplo.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('c3100000-0000-4000-8000-000000000003', 'authenticated', 'authenticated',
   'intruso@exemplo.test', '', now(), '{"provider":"email","providers":["email"]}', '{}', now(), now());

SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000001","role":"authenticated","email":"admin@exemplo.test"}', true);
SET LOCAL ROLE authenticated;

SELECT ok(
  has_function_privilege('authenticated', 'public.create_shared_workspace(text)', 'EXECUTE'),
  'usuário autenticado pode criar uma UAN pela função autorizada'
);
SELECT ok(
  NOT has_function_privilege('anon', 'public.create_shared_workspace(text)', 'EXECUTE'),
  'usuário anônimo não pode criar uma UAN'
);
SELECT lives_ok(
  $$SELECT public.create_shared_workspace('UAN de teste')$$,
  'o administrador pode criar uma UAN'
);
SELECT set_config('test.workspace_id', (
  SELECT id::text FROM public.shared_workspaces WHERE name = 'UAN de teste'
), true);
SELECT is(
  (SELECT role FROM public.workspace_members
   WHERE workspace_id = current_setting('test.workspace_id')::uuid
     AND user_id = auth.uid()),
  'admin',
  'o criador recebe papel de administrador ativo'
);

SELECT set_config('test.invite_code', (
  SELECT invite_code FROM public.issue_workspace_invite(
    current_setting('test.workspace_id')::uuid,
    ' Operador@Exemplo.Test '
  )
), true);
SELECT ok(
  (SELECT expires_at BETWEEN now() + interval '23 hours 59 minutes'
                         AND now() + interval '24 hours 1 minute'
   FROM public.workspace_invites
   WHERE workspace_id = current_setting('test.workspace_id')::uuid
     AND invited_email = 'operador@exemplo.test'),
  'convite padrão expira em aproximadamente 24 horas e normaliza o e-mail'
);

RESET ROLE;
SELECT ok(
  (SELECT token_hash = extensions.digest(
      convert_to(current_setting('test.invite_code'), 'UTF8'), 'sha256')
   FROM public.workspace_invites
   WHERE workspace_id = current_setting('test.workspace_id')::uuid),
  'o banco guarda somente o hash do código do convite'
);

SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000003', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000003","role":"authenticated","email":"intruso@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT is(
  (SELECT count(*)::integer FROM public.shared_workspaces),
  0,
  'usuário sem associação não enxerga a UAN'
);
SELECT is(
  (SELECT count(*)::integer FROM public.workspace_members
   WHERE workspace_id = current_setting('test.workspace_id')::uuid),
  0,
  'usuário sem associação não enxerga os membros da UAN'
);
SELECT throws_ok(
  format('SELECT public.issue_workspace_invite(%L::uuid, %L)',
    current_setting('test.workspace_id'), 'alguem@exemplo.test'),
  '42501', NULL,
  'usuário sem papel administrativo não pode emitir convite'
);

SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000002', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000002","role":"authenticated","email":"operador@exemplo.test"}', true);
SELECT is(
  public.accept_workspace_invite(current_setting('test.invite_code')),
  current_setting('test.workspace_id')::uuid,
  'conta cujo e-mail corresponde ao convite pode aceitá-lo'
);
SELECT throws_ok(
  $$SELECT public.accept_workspace_invite(current_setting('test.invite_code'))$$,
  '22023', NULL,
  'convite já utilizado não pode ser reutilizado'
);
SELECT is(
  (SELECT role FROM public.workspace_members
   WHERE workspace_id = current_setting('test.workspace_id')::uuid
     AND user_id = auth.uid()),
  'operator',
  'convite cria associação de operador'
);
SELECT is(
  (SELECT count(*)::integer FROM public.workspace_audit_events
   WHERE workspace_id = current_setting('test.workspace_id')::uuid),
  0,
  'operador não pode ler a auditoria administrativa'
);
SELECT throws_ok(
  format('UPDATE public.workspace_members SET role = %L WHERE workspace_id = %L::uuid AND user_id = auth.uid()',
    'admin', current_setting('test.workspace_id')),
  '42501', NULL,
  'membro não pode alterar diretamente o próprio papel'
);

RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000001","role":"authenticated","email":"admin@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  format('SELECT public.remove_workspace_member(%L::uuid, auth.uid())',
    current_setting('test.workspace_id')),
  '23514', NULL,
  'a UAN não permite remover seu último administrador ativo'
);
SELECT throws_ok(
  format('SELECT public.set_workspace_member_role(%L::uuid, auth.uid(), %L)',
    current_setting('test.workspace_id'), 'operator'),
  '23514', NULL,
  'a UAN não permite rebaixar seu último administrador ativo'
);

SELECT lives_ok(
  format('SELECT public.update_shared_workspace(%L::uuid, %L, 3600)',
    current_setting('test.workspace_id'), 'UAN atualizada'),
  'administrador pode configurar validade dos convites'
);
SELECT is(
  (SELECT invite_ttl_seconds FROM public.shared_workspaces
   WHERE id = current_setting('test.workspace_id')::uuid),
  3600,
  'a validade configurada é persistida no servidor'
);

SELECT
  set_config('test.revoked_invite_id', invite_id::text, true),
  set_config('test.revoked_code', invite_code, true)
FROM public.issue_workspace_invite(
  current_setting('test.workspace_id')::uuid, 'intruso@exemplo.test'
);
SELECT lives_ok(
  format('SELECT public.revoke_workspace_invite(%L::uuid, %L::uuid)',
    current_setting('test.workspace_id'), current_setting('test.revoked_invite_id')),
  'administrador pode revogar convite pendente'
);

RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000003', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000003","role":"authenticated","email":"intruso@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  $$SELECT public.accept_workspace_invite(current_setting('test.revoked_code'))$$,
  '22023', NULL,
  'convite revogado não pode ser aceito'
);
SELECT is(
  (SELECT count(*)::integer FROM public.shared_workspaces),
  0,
  'membro de outra UAN não enxerga a primeira UAN'
);
SELECT lives_ok(
  $$SELECT public.create_shared_workspace('Outra UAN')$$,
  'uma conta pode criar sua própria UAN independente'
);
SELECT is(
  (SELECT count(*)::integer FROM public.shared_workspaces),
  1,
  'a conta enxerga somente sua própria UAN'
);

RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000001","role":"authenticated","email":"admin@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT is(
  (SELECT count(*)::integer FROM public.shared_workspaces),
  1,
  'administrador da primeira UAN não enxerga a UAN independente'
);
SELECT ok(
  (SELECT count(*) > 0 FROM public.workspace_audit_events
   WHERE workspace_id = current_setting('test.workspace_id')::uuid),
  'administrador pode consultar auditoria da própria UAN'
);

SELECT set_config('test.wrong_email_code', (
  SELECT invite_code FROM public.issue_workspace_invite(
    current_setting('test.workspace_id')::uuid, 'operador@exemplo.test'
  )
), true);
RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000003', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000003","role":"authenticated","email":"intruso@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  $$SELECT public.accept_workspace_invite(current_setting('test.wrong_email_code'))$$,
  '22023', NULL,
  'conta com e-mail diferente não pode aceitar o convite'
);

RESET ROLE;
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000001', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000001","role":"authenticated","email":"admin@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT set_config('test.expired_code', (
  SELECT invite_code FROM public.issue_workspace_invite(
    current_setting('test.workspace_id')::uuid, 'operador@exemplo.test'
  )
), true);
RESET ROLE;
UPDATE public.workspace_invites
SET expires_at = now() - interval '1 minute'
WHERE token_hash = extensions.digest(
  convert_to(current_setting('test.expired_code'), 'UTF8'), 'sha256');
SELECT set_config('request.jwt.claim.sub', 'c3100000-0000-4000-8000-000000000002', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"c3100000-0000-4000-8000-000000000002","role":"authenticated","email":"operador@exemplo.test"}', true);
SET LOCAL ROLE authenticated;
SELECT throws_ok(
  $$SELECT public.accept_workspace_invite(current_setting('test.expired_code'))$$,
  '22023', NULL,
  'convite expirado não pode ser aceito'
);

SELECT * FROM finish();
ROLLBACK;
