\set ON_ERROR_STOP on
BEGIN;

INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) VALUES
  ('e3100000-0000-4000-8000-000000000001', 'authenticated', 'authenticated',
   'admin-corrida@exemplo.test', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now()),
  ('e3100000-0000-4000-8000-000000000002', 'authenticated', 'authenticated',
   'operador-corrida@exemplo.test', '', now(),
   '{"provider":"email","providers":["email"]}', '{}', now(), now());

SET LOCAL request.jwt.claim.sub = 'e3100000-0000-4000-8000-000000000001';
SET LOCAL request.jwt.claims =
  '{"sub":"e3100000-0000-4000-8000-000000000001","role":"authenticated","email":"admin-corrida@exemplo.test"}';
SET LOCAL ROLE authenticated;

SELECT public.create_shared_workspace('UAN descartável - teste concorrente')
  AS workspace_id \gset
SELECT invite_code
  FROM public.issue_workspace_invite(:'workspace_id'::uuid,
    'operador-corrida@exemplo.test') \gset

\echo WORKSPACE_ID=:workspace_id
\echo INVITE_CODE=:invite_code
COMMIT;
