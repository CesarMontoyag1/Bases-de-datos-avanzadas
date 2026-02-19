DO
$$
BEGIN
   IF NOT EXISTS (
      SELECT FROM pg_catalog.pg_roles
      WHERE rolname = 'replicator'
   ) THEN
      CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass';
   ELSE
      ALTER ROLE replicator WITH REPLICATION LOGIN PASSWORD 'repl_pass';
   END IF;
END
$$;