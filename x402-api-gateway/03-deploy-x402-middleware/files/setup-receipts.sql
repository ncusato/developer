-- Run as ADMIN in Database Actions SQL.
-- This script creates the x402_app schema and REST-enables the receipt table.

DECLARE
  user_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_count FROM dba_users WHERE username = 'X402_APP';
  IF user_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER x402_app IDENTIFIED BY "ReplaceWithStrongX402Password#2026"';
    EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO x402_app';
  END IF;
END;
/

DECLARE
  table_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO table_count
  FROM all_tables
  WHERE owner = 'X402_APP'
  AND table_name = 'X402_RECEIPTS';

  IF table_count = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE x402_app.x402_receipts (
        nonce            VARCHAR2(66) PRIMARY KEY,
        payer_address    VARCHAR2(42) NOT NULL,
        amount           VARCHAR2(78) NOT NULL,
        asset            VARCHAR2(42) NOT NULL,
        network          VARCHAR2(50) NOT NULL,
        tx_hash          VARCHAR2(100),
        resource_path    VARCHAR2(500),
        status           VARCHAR2(20) NOT NULL,
        created_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        settled_at       TIMESTAMP
      )';
  END IF;
END;
/

DECLARE
  index_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO index_count
  FROM all_indexes
  WHERE owner = 'X402_APP'
  AND index_name = 'IDX_RECEIPTS_PAYER';

  IF index_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE INDEX x402_app.idx_receipts_payer ON x402_app.x402_receipts(payer_address)';
  END IF;
END;
/

DECLARE
  index_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO index_count
  FROM all_indexes
  WHERE owner = 'X402_APP'
  AND index_name = 'IDX_RECEIPTS_CREATED';

  IF index_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE INDEX x402_app.idx_receipts_created ON x402_app.x402_receipts(created_at)';
  END IF;
END;
/

BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'X402_APP',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'x402',
    p_auto_rest_auth      => TRUE
  );

  ORDS.ENABLE_OBJECT(
    p_enabled        => TRUE,
    p_schema         => 'X402_APP',
    p_object         => 'X402_RECEIPTS',
    p_object_type    => 'TABLE',
    p_object_alias   => 'x402_receipts',
    p_auto_rest_auth => TRUE
  );
  COMMIT;
END;
/

SELECT owner, table_name
FROM all_tables
WHERE owner = 'X402_APP'
AND table_name = 'X402_RECEIPTS';
