-- Run as ADMIN in Database Actions SQL.
-- Replace the password value if you did not use the default workshop.env variable.

ALTER USER SH IDENTIFIED BY "ReplaceWithStrongShPassword#2026" ACCOUNT UNLOCK;
GRANT CONNECT, RESOURCE TO SH;

BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'SH',
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
      p_schema         => 'SH',
      p_object         => object_name.name,
      p_object_type    => 'TABLE',
      p_object_alias   => LOWER(object_name.name),
      p_auto_rest_auth => FALSE
    );
  END LOOP;
  COMMIT;
END;
/

SELECT username, account_status
FROM dba_users
WHERE username = 'SH';
