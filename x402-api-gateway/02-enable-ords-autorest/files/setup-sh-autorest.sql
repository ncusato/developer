-- Run as ADMIN in Database Actions SQL.
-- This script keeps SH as the maintained sample-data source.
-- It creates X402_REST, exposes views over SH data, and maps ORDS to /ords/sh/.

DECLARE
  user_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO user_count
  FROM dba_users
  WHERE username = 'X402_REST';

  IF user_count = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER x402_rest IDENTIFIED BY "ReplaceWithStrongRestPassword#2026"';
  ELSE
    EXECUTE IMMEDIATE 'ALTER USER x402_rest IDENTIFIED BY "ReplaceWithStrongRestPassword#2026" ACCOUNT UNLOCK';
  END IF;

  EXECUTE IMMEDIATE 'GRANT CONNECT, RESOURCE, UNLIMITED TABLESPACE TO x402_rest';
END;
/

GRANT SELECT ON sh.sales TO x402_rest;
GRANT SELECT ON sh.products TO x402_rest;
GRANT SELECT ON sh.customers TO x402_rest;
GRANT SELECT ON sh.channels TO x402_rest;

CREATE OR REPLACE VIEW x402_rest.sales AS
SELECT *
FROM sh.sales;

CREATE OR REPLACE VIEW x402_rest.products AS
SELECT *
FROM sh.products;

CREATE OR REPLACE VIEW x402_rest.customers AS
SELECT *
FROM sh.customers;

CREATE OR REPLACE VIEW x402_rest.channels AS
SELECT *
FROM sh.channels;

BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'X402_REST',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'sh',
    p_auto_rest_auth      => FALSE
  );
  COMMIT;
END;
/

BEGIN
  FOR object_name IN (
    SELECT column_value AS name
    FROM TABLE(sys.odcivarchar2list('SALES', 'PRODUCTS', 'CUSTOMERS', 'CHANNELS'))
  ) LOOP
    ORDS.ENABLE_OBJECT(
      p_enabled        => TRUE,
      p_schema         => 'X402_REST',
      p_object         => object_name.name,
      p_object_type    => 'VIEW',
      p_object_alias   => LOWER(object_name.name),
      p_auto_rest_auth => FALSE
    );
  END LOOP;
  COMMIT;
END;
/

SELECT username, account_status
FROM dba_users
WHERE username = 'X402_REST';

SELECT owner, view_name
FROM all_views
WHERE owner = 'X402_REST'
AND view_name IN ('SALES', 'PRODUCTS', 'CUSTOMERS', 'CHANNELS')
ORDER BY view_name;
