-- Fundação do backend de áreas de trabalho compartilhadas.
-- Nenhuma tabela ou dado do SQLite local é acessado por esta migração.

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.shared_workspaces (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (char_length(btrim(name)) BETWEEN 1 AND 120),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  invite_ttl_seconds integer NOT NULL DEFAULT 86400
    CHECK (invite_ttl_seconds BETWEEN 3600 AND 2592000),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.workspace_members (
  workspace_id uuid NOT NULL REFERENCES public.shared_workspaces(id) ON DELETE RESTRICT,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  role text NOT NULL CHECK (role IN ('admin', 'operator')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'suspended', 'removed')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (workspace_id, user_id)
);

CREATE INDEX workspace_members_user_status_idx
  ON public.workspace_members(user_id, status, workspace_id);

CREATE TABLE public.workspace_invites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  workspace_id uuid NOT NULL REFERENCES public.shared_workspaces(id) ON DELETE RESTRICT,
  invited_email text NOT NULL CHECK (
    invited_email = lower(btrim(invited_email)) AND
    invited_email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
  ),
  token_hash bytea NOT NULL UNIQUE,
  invited_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  expires_at timestamptz NOT NULL,
  used_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  revoked_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((used_at IS NULL) = (accepted_by IS NULL)),
  CHECK (used_at IS NULL OR revoked_at IS NULL)
);

CREATE INDEX workspace_invites_workspace_created_idx
  ON public.workspace_invites(workspace_id, created_at DESC);
CREATE UNIQUE INDEX workspace_invites_one_open_email_idx
  ON public.workspace_invites(workspace_id, invited_email)
  WHERE used_at IS NULL AND revoked_at IS NULL;

CREATE TABLE public.workspace_audit_events (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  workspace_id uuid NOT NULL REFERENCES public.shared_workspaces(id) ON DELETE RESTRICT,
  actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  action text NOT NULL CHECK (action IN (
    'workspace_created', 'workspace_updated', 'invite_issued',
    'invite_revoked', 'invite_accepted', 'member_removed',
    'member_role_changed'
  )),
  subject_user_id uuid REFERENCES auth.users(id) ON DELETE RESTRICT,
  invite_id uuid REFERENCES public.workspace_invites(id) ON DELETE RESTRICT,
  details jsonb NOT NULL DEFAULT '{}'::jsonb
    CHECK (jsonb_typeof(details) = 'object'),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX workspace_audit_workspace_time_idx
  ON public.workspace_audit_events(workspace_id, created_at DESC, id DESC);

ALTER TABLE public.shared_workspaces ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workspace_audit_events ENABLE ROW LEVEL SECURITY;

CREATE FUNCTION public.is_active_workspace_member(p_workspace_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.workspace_members AS member
    WHERE member.workspace_id = p_workspace_id
      AND member.user_id = auth.uid()
      AND member.status = 'active'
  );
$$;

CREATE FUNCTION public.is_active_workspace_admin(p_workspace_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.workspace_members AS member
    WHERE member.workspace_id = p_workspace_id
      AND member.user_id = auth.uid()
      AND member.role = 'admin'
      AND member.status = 'active'
  );
$$;

CREATE POLICY shared_workspaces_member_read
  ON public.shared_workspaces FOR SELECT TO authenticated
  USING (public.is_active_workspace_member(id));
CREATE POLICY workspace_members_member_read
  ON public.workspace_members FOR SELECT TO authenticated
  USING (public.is_active_workspace_member(workspace_id));
CREATE POLICY workspace_invites_admin_read
  ON public.workspace_invites FOR SELECT TO authenticated
  USING (public.is_active_workspace_admin(workspace_id));
CREATE POLICY workspace_audit_admin_read
  ON public.workspace_audit_events FOR SELECT TO authenticated
  USING (public.is_active_workspace_admin(workspace_id));

-- O bloqueio da linha da UAN serializa alterações de papel/estado e convites.
CREATE FUNCTION public._require_workspace_admin(p_workspace_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.' USING ERRCODE = '28000';
  END IF;
  PERFORM 1
  FROM public.shared_workspaces AS workspace
  WHERE workspace.id = p_workspace_id
  FOR UPDATE;
  IF NOT FOUND OR NOT public.is_active_workspace_admin(p_workspace_id) THEN
    RAISE EXCEPTION 'Ação permitida somente a administradores ativos da UAN.'
      USING ERRCODE = '42501';
  END IF;
  RETURN v_actor;
END;
$$;

CREATE FUNCTION public._protect_last_active_admin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_workspace_id uuid := OLD.workspace_id;
  v_remaining integer;
  v_removes_admin boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_removes_admin := OLD.role = 'admin' AND OLD.status = 'active';
  ELSE
    v_removes_admin := OLD.role = 'admin' AND OLD.status = 'active'
      AND (NEW.role <> 'admin' OR NEW.status <> 'active');
  END IF;
  IF NOT v_removes_admin THEN
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  PERFORM 1 FROM public.shared_workspaces
    WHERE id = v_workspace_id FOR UPDATE;
  SELECT count(*) INTO v_remaining
  FROM public.workspace_members
  WHERE workspace_id = v_workspace_id
    AND user_id <> OLD.user_id
    AND role = 'admin'
    AND status = 'active';
  IF v_remaining = 0 THEN
    RAISE EXCEPTION 'A UAN precisa manter pelo menos um administrador ativo.'
      USING ERRCODE = '23514';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER workspace_members_preserve_admin
  BEFORE UPDATE OF role, status OR DELETE ON public.workspace_members
  FOR EACH ROW EXECUTE FUNCTION public._protect_last_active_admin();

CREATE FUNCTION public.create_shared_workspace(p_name text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_workspace_id uuid;
  v_name text := btrim(p_name);
BEGIN
  IF v_actor IS NULL THEN
    RAISE EXCEPTION 'Autenticação obrigatória.' USING ERRCODE = '28000';
  END IF;
  IF v_name IS NULL OR char_length(v_name) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'Informe um nome de UAN entre 1 e 120 caracteres.'
      USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.shared_workspaces(name, created_by)
    VALUES (v_name, v_actor) RETURNING id INTO v_workspace_id;
  INSERT INTO public.workspace_members(workspace_id, user_id, role, status)
    VALUES (v_workspace_id, v_actor, 'admin', 'active');
  INSERT INTO public.workspace_audit_events(workspace_id, actor_id, action)
    VALUES (v_workspace_id, v_actor, 'workspace_created');
  RETURN v_workspace_id;
END;
$$;

CREATE FUNCTION public.update_shared_workspace(
  p_workspace_id uuid,
  p_name text,
  p_invite_ttl_seconds integer
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := public._require_workspace_admin(p_workspace_id);
  v_name text := btrim(p_name);
BEGIN
  IF v_name IS NULL OR char_length(v_name) NOT BETWEEN 1 AND 120 THEN
    RAISE EXCEPTION 'Informe um nome de UAN entre 1 e 120 caracteres.'
      USING ERRCODE = '22023';
  END IF;
  IF p_invite_ttl_seconds NOT BETWEEN 3600 AND 2592000 THEN
    RAISE EXCEPTION 'A validade do convite deve ficar entre 1 hora e 30 dias.'
      USING ERRCODE = '22023';
  END IF;
  UPDATE public.shared_workspaces
  SET name = v_name, invite_ttl_seconds = p_invite_ttl_seconds, updated_at = now()
  WHERE id = p_workspace_id;
  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, details
  ) VALUES (
    p_workspace_id, v_actor, 'workspace_updated',
    jsonb_build_object('invite_ttl_seconds', p_invite_ttl_seconds)
  );
END;
$$;

CREATE FUNCTION public.issue_workspace_invite(
  p_workspace_id uuid,
  p_invited_email text
)
RETURNS TABLE(invite_id uuid, invite_code text, expires_at timestamptz)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := public._require_workspace_admin(p_workspace_id);
  v_email text := lower(btrim(p_invited_email));
  v_ttl integer;
  v_code text;
  v_invite_id uuid;
  v_expires timestamptz;
  v_old_id uuid;
BEGIN
  IF v_email IS NULL OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' THEN
    RAISE EXCEPTION 'Informe um e-mail válido para o convite.' USING ERRCODE = '22023';
  END IF;
  SELECT invite_ttl_seconds INTO v_ttl
  FROM public.shared_workspaces WHERE id = p_workspace_id;

  -- Reemissão invalida explicitamente o convite anterior para o mesmo e-mail.
  FOR v_old_id IN
    SELECT id FROM public.workspace_invites
    WHERE workspace_id = p_workspace_id AND invited_email = v_email
      AND used_at IS NULL AND revoked_at IS NULL
    FOR UPDATE
  LOOP
    UPDATE public.workspace_invites SET revoked_at = now() WHERE id = v_old_id;
    INSERT INTO public.workspace_audit_events(
      workspace_id, actor_id, action, invite_id
    ) VALUES (p_workspace_id, v_actor, 'invite_revoked', v_old_id);
  END LOOP;

  v_code := translate(
    rtrim(encode(extensions.gen_random_bytes(32), 'base64'), '='),
    '+/', '-_'
  );
  v_expires := now() + make_interval(secs => v_ttl);
  INSERT INTO public.workspace_invites(
    workspace_id, invited_email, token_hash, invited_by, expires_at
  ) VALUES (
    p_workspace_id,
    v_email,
    extensions.digest(convert_to(v_code, 'UTF8'), 'sha256'),
    v_actor,
    v_expires
  ) RETURNING id INTO v_invite_id;
  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, invite_id
  ) VALUES (p_workspace_id, v_actor, 'invite_issued', v_invite_id);
  RETURN QUERY SELECT v_invite_id, v_code, v_expires;
END;
$$;

CREATE FUNCTION public.revoke_workspace_invite(
  p_workspace_id uuid,
  p_invite_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := public._require_workspace_admin(p_workspace_id);
  v_invite public.workspace_invites%ROWTYPE;
BEGIN
  SELECT * INTO v_invite
  FROM public.workspace_invites
  WHERE id = p_invite_id AND workspace_id = p_workspace_id
  FOR UPDATE;
  IF NOT FOUND OR v_invite.used_at IS NOT NULL OR v_invite.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'Convite não encontrado ou já encerrado.' USING ERRCODE = '22023';
  END IF;
  UPDATE public.workspace_invites SET revoked_at = now() WHERE id = p_invite_id;
  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, invite_id
  ) VALUES (p_workspace_id, v_actor, 'invite_revoked', p_invite_id);
END;
$$;

CREATE FUNCTION public.accept_workspace_invite(p_invite_code text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := auth.uid();
  v_email text;
  v_workspace_id uuid;
  v_invite public.workspace_invites%ROWTYPE;
  v_changed integer;
BEGIN
  IF v_actor IS NULL OR p_invite_code IS NULL OR p_invite_code = '' THEN
    RAISE EXCEPTION 'Conta autenticada e código do convite são obrigatórios.'
      USING ERRCODE = '28000';
  END IF;
  SELECT lower(email) INTO v_email
  FROM auth.users
  WHERE id = v_actor AND email_confirmed_at IS NOT NULL;
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'A conta precisa ter um e-mail confirmado.' USING ERRCODE = '42501';
  END IF;

  SELECT workspace_id INTO v_workspace_id
  FROM public.workspace_invites
  WHERE token_hash = extensions.digest(convert_to(p_invite_code, 'UTF8'), 'sha256');
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Convite inválido, expirado ou já utilizado.' USING ERRCODE = '22023';
  END IF;
  PERFORM 1 FROM public.shared_workspaces
  WHERE id = v_workspace_id FOR UPDATE;
  SELECT * INTO v_invite
  FROM public.workspace_invites
  WHERE token_hash = extensions.digest(convert_to(p_invite_code, 'UTF8'), 'sha256')
  FOR UPDATE;
  IF NOT FOUND OR v_invite.used_at IS NOT NULL OR v_invite.revoked_at IS NOT NULL
    OR v_invite.expires_at <= now() OR v_invite.invited_email <> v_email THEN
    RAISE EXCEPTION 'Convite inválido, expirado ou já utilizado.' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.workspace_members
    WHERE workspace_id = v_invite.workspace_id AND user_id = v_actor
      AND status <> 'removed'
  ) THEN
    RAISE EXCEPTION 'A conta já possui associação ativa ou suspensa nesta UAN.'
      USING ERRCODE = '23505';
  END IF;

  UPDATE public.workspace_invites
  SET used_at = now(), accepted_by = v_actor
  WHERE id = v_invite.id AND used_at IS NULL AND revoked_at IS NULL
    AND expires_at > now();
  GET DIAGNOSTICS v_changed = ROW_COUNT;
  IF v_changed <> 1 THEN
    RAISE EXCEPTION 'Convite inválido, expirado ou já utilizado.' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.workspace_members(workspace_id, user_id, role, status)
  VALUES (v_invite.workspace_id, v_actor, 'operator', 'active')
  ON CONFLICT (workspace_id, user_id) DO UPDATE
    SET role = 'operator', status = 'active', updated_at = now()
    WHERE public.workspace_members.status = 'removed';
  GET DIAGNOSTICS v_changed = ROW_COUNT;
  IF v_changed <> 1 THEN
    RAISE EXCEPTION 'Não foi possível ativar a associação convidada.' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, subject_user_id, invite_id
  ) VALUES (
    v_invite.workspace_id, v_actor, 'invite_accepted', v_actor, v_invite.id
  );
  RETURN v_invite.workspace_id;
END;
$$;

CREATE FUNCTION public.remove_workspace_member(
  p_workspace_id uuid,
  p_user_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := public._require_workspace_admin(p_workspace_id);
BEGIN
  UPDATE public.workspace_members
  SET status = 'removed', updated_at = now()
  WHERE workspace_id = p_workspace_id AND user_id = p_user_id
    AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro ativo não encontrado nesta UAN.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, subject_user_id
  ) VALUES (p_workspace_id, v_actor, 'member_removed', p_user_id);
END;
$$;

CREATE FUNCTION public.set_workspace_member_role(
  p_workspace_id uuid,
  p_user_id uuid,
  p_role text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_actor uuid := public._require_workspace_admin(p_workspace_id);
BEGIN
  IF p_role NOT IN ('admin', 'operator') THEN
    RAISE EXCEPTION 'Papel inválido.' USING ERRCODE = '22023';
  END IF;
  UPDATE public.workspace_members
  SET role = p_role, updated_at = now()
  WHERE workspace_id = p_workspace_id AND user_id = p_user_id
    AND status = 'active';
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Membro ativo não encontrado nesta UAN.' USING ERRCODE = '22023';
  END IF;
  INSERT INTO public.workspace_audit_events(
    workspace_id, actor_id, action, subject_user_id, details
  ) VALUES (
    p_workspace_id, v_actor, 'member_role_changed', p_user_id,
    jsonb_build_object('new_role', p_role)
  );
END;
$$;

-- O cliente só pode ler linhas autorizadas; gravações passam pelas funções acima.
REVOKE ALL ON public.shared_workspaces, public.workspace_members,
  public.workspace_invites, public.workspace_audit_events FROM anon, authenticated;
GRANT SELECT ON public.shared_workspaces TO authenticated;
GRANT SELECT (workspace_id, user_id, role, status, created_at, updated_at)
  ON public.workspace_members TO authenticated;
GRANT SELECT (id, workspace_id, invited_email, invited_by, expires_at,
  used_at, accepted_by, revoked_at, created_at)
  ON public.workspace_invites TO authenticated;
GRANT SELECT ON public.workspace_audit_events TO authenticated;

REVOKE ALL ON FUNCTION public.is_active_workspace_member(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.is_active_workspace_admin(uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public._require_workspace_admin(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._protect_last_active_admin() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_workspace_member(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_active_workspace_admin(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.create_shared_workspace(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_shared_workspace(uuid, text, integer) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.issue_workspace_invite(uuid, text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.revoke_workspace_invite(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_workspace_invite(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.remove_workspace_member(uuid, uuid) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_workspace_member_role(uuid, uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_shared_workspace(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_shared_workspace(uuid, text, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_workspace_invite(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_workspace_invite(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_workspace_invite(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.remove_workspace_member(uuid, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_workspace_member_role(uuid, uuid, text) TO authenticated;
