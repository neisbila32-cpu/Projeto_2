#!/usr/bin/env sh
set -eu

: "${DATABASE_URL:?Informe DATABASE_URL do Supabase local.}"
: "${WORKSPACE_ID:?Informe o UUID de uma UAN de teste.}"
: "${INVITED_USER_ID:?Informe o UUID da conta vinculada ao convite.}"
: "${INVITED_EMAIL:?Informe o e-mail confirmado dessa conta.}"
: "${INVITE_CODE:?Informe um código de convite pendente criado só para este teste.}"

case "$DATABASE_URL" in
  postgresql://*) ;;
  *) echo "Recusado: use uma URL PostgreSQL local." >&2; exit 2 ;;
esac

autoridade=${DATABASE_URL#postgresql://}
autoridade=${autoridade%%/*}
host_porta=${autoridade##*@}
case "$host_porta" in
  localhost:*|127.0.0.1:*|\[::1\]:*) ;;
  *) echo "Recusado: o teste concorrente só aceita uma URL PostgreSQL local." >&2; exit 2 ;;
esac

case "$WORKSPACE_ID:$INVITED_USER_ID" in
  *[!0-9a-fA-F:-]*) echo "UUID de UAN ou usuário inválido." >&2; exit 2 ;;
esac
case "$INVITE_CODE" in
  *[!A-Za-z0-9_-]*) echo "O código do convite contém caracteres inesperados." >&2; exit 2 ;;
esac
case "$INVITED_EMAIL" in
  *[!A-Za-z0-9_.+@-]*) echo "O e-mail contém caracteres inesperados." >&2; exit 2 ;;
esac

diretorio_temporario=$(mktemp -d)
trap 'rm -rf "$diretorio_temporario"' EXIT HUP INT TERM

aceitar() {
psql "$DATABASE_URL" -X -q -v ON_ERROR_STOP=1 -v VERBOSITY=verbose >"$1" 2>"$2" <<SQL
BEGIN;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', '$INVITED_USER_ID', true);
SELECT set_config('request.jwt.claims',
  '{"sub":"$INVITED_USER_ID","role":"authenticated","email":"$INVITED_EMAIL"}', true);
SELECT public.accept_workspace_invite('$INVITE_CODE');
COMMIT;
SQL
}

set +e
aceitar "$diretorio_temporario/um.out" "$diretorio_temporario/um.err" & pid_um=$!
aceitar "$diretorio_temporario/dois.out" "$diretorio_temporario/dois.err" & pid_dois=$!
wait "$pid_um"; estado_um=$?
wait "$pid_dois"; estado_dois=$?
set -e

if [ "$estado_um" -eq "$estado_dois" ]; then
  echo "Falha: esperava exatamente uma aceitação concorrente bem-sucedida." >&2
  cat "$diretorio_temporario/um.err" "$diretorio_temporario/dois.err" >&2
  exit 1
fi

if [ "$estado_um" -ne 0 ]; then
  arquivo_falha="$diretorio_temporario/um.err"
else
  arquivo_falha="$diretorio_temporario/dois.err"
fi
if ! grep -q '22023' "$arquivo_falha"; then
  echo "Falha: a sessão recusada não recebeu o erro esperado de convite inválido/consumido (SQLSTATE 22023)." >&2
  cat "$arquivo_falha" >&2
  exit 1
fi

estado=$(psql "$DATABASE_URL" -X -qAt -v ON_ERROR_STOP=1 <<SQL
SELECT
  (SELECT count(*) FROM public.workspace_members
   WHERE workspace_id = '$WORKSPACE_ID'::uuid
     AND user_id = '$INVITED_USER_ID'::uuid AND status = 'active')::text
  || '|' ||
  (SELECT count(*) FROM public.workspace_invites
   WHERE token_hash = extensions.digest(convert_to('$INVITE_CODE', 'UTF8'), 'sha256')
     AND used_at IS NOT NULL AND accepted_by = '$INVITED_USER_ID'::uuid)::text;
SQL
)

if [ "$estado" != "1|1" ]; then
  echo "Falha: estado após corrida inesperado: $estado" >&2
  exit 1
fi

echo "Concorrência validada: uma aceitação concluída, uma recusada e um único vínculo ativo."
