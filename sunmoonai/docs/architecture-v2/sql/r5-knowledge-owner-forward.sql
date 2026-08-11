\set ON_ERROR_STOP on

BEGIN;

DO $guard$
DECLARE
  actual_tables text[];
  expected_tables constant text[] := ARRAY[
    'alembic_version', 'auth_user', 'inbox_message', 'knowledge_document',
    'knowledge_document_version', 'knowledge_ingestion_job', 'outbox_message'
  ];
BEGIN
  IF current_database() <> 'knowledge_admin' THEN
    RAISE EXCEPTION 'R5 Knowledge ownership SQL may run only in knowledge_admin';
  END IF;
  IF (SELECT version_num FROM alembic_version) <> '20260808_0004' THEN
    RAISE EXCEPTION 'R5 Knowledge database is not at 20260808_0004';
  END IF;
  SELECT array_agg(tablename ORDER BY tablename)
    INTO actual_tables
    FROM pg_tables
   WHERE schemaname = 'public';
  IF actual_tables IS DISTINCT FROM expected_tables THEN
    RAISE EXCEPTION 'R5 Knowledge table inventory drift: %', actual_tables;
  END IF;
  IF EXISTS (
    SELECT 1 FROM pg_tables
     WHERE schemaname = 'public'
       AND tableowner NOT IN (
         'knowledge_admin_user_migration', 'knowledge_backend_user_migration'
       )
  ) THEN
    RAISE EXCEPTION 'R5 Knowledge contains an unexpected table owner';
  END IF;
END
$guard$;

SELECT pg_terminate_backend(pid)
  FROM pg_stat_activity
 WHERE datname = current_database()
   AND usename IN ('knowledge_admin_user', 'knowledge_admin_user_migration')
   AND pid <> pg_backend_pid();

ALTER ROLE knowledge_backend_user LOGIN;
ALTER ROLE knowledge_backend_user_migration LOGIN;
ALTER ROLE knowledge_admin_user NOLOGIN;
ALTER ROLE knowledge_admin_user_migration NOLOGIN;

ALTER DATABASE knowledge_admin OWNER TO knowledge_backend_user_migration;
ALTER SCHEMA public OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.alembic_version OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.auth_user OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.inbox_message OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.knowledge_document OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.knowledge_document_version OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.knowledge_ingestion_job OWNER TO knowledge_backend_user_migration;
ALTER TABLE public.outbox_message OWNER TO knowledge_backend_user_migration;

REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM knowledge_admin_user;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM knowledge_admin_user;
REVOKE ALL PRIVILEGES ON SCHEMA public FROM knowledge_admin_user;
REVOKE CONNECT ON DATABASE knowledge_admin FROM knowledge_admin_user;
REVOKE CONNECT, CREATE, TEMPORARY ON DATABASE knowledge_admin
  FROM knowledge_admin_user_migration;

GRANT CONNECT ON DATABASE knowledge_admin TO knowledge_backend_user;
GRANT USAGE ON SCHEMA public TO knowledge_backend_user;
REVOKE CREATE ON SCHEMA public FROM knowledge_backend_user;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public
  TO knowledge_backend_user;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public
  TO knowledge_backend_user;
GRANT CONNECT, CREATE, TEMPORARY ON DATABASE knowledge_admin
  TO knowledge_backend_user_migration;
GRANT USAGE, CREATE ON SCHEMA public TO knowledge_backend_user_migration;

ALTER DEFAULT PRIVILEGES FOR ROLE knowledge_backend_user_migration IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO knowledge_backend_user;
ALTER DEFAULT PRIVILEGES FOR ROLE knowledge_backend_user_migration IN SCHEMA public
  GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO knowledge_backend_user;

COMMIT;
