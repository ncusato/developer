-- Run as ADMIN in Database Actions SQL.
-- This script creates a workshop-owned market intelligence dataset for paid API simulation.

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

DECLARE
  table_count NUMBER;
BEGIN
  SELECT COUNT(*) INTO table_count FROM all_tables WHERE owner = 'X402_REST' AND table_name = 'API_PRODUCTS';
  IF table_count = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE x402_rest.api_products (
        product_id          NUMBER PRIMARY KEY,
        api_path            VARCHAR2(100) NOT NULL,
        product_name        VARCHAR2(120) NOT NULL,
        category            VARCHAR2(80) NOT NULL,
        buyer_segment       VARCHAR2(120) NOT NULL,
        freshness_minutes   NUMBER NOT NULL,
        price_microusd      NUMBER NOT NULL,
        gross_margin_pct    NUMBER NOT NULL,
        description         VARCHAR2(500)
      )';
  END IF;

  SELECT COUNT(*) INTO table_count FROM all_tables WHERE owner = 'X402_REST' AND table_name = 'MARKET_SIGNALS';
  IF table_count = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE x402_rest.market_signals (
        signal_id           NUMBER PRIMARY KEY,
        signal_date         DATE NOT NULL,
        sector              VARCHAR2(80) NOT NULL,
        region              VARCHAR2(80) NOT NULL,
        signal_type         VARCHAR2(80) NOT NULL,
        signal_value        NUMBER NOT NULL,
        confidence_score    NUMBER NOT NULL,
        source_count        NUMBER NOT NULL,
        price_microusd      NUMBER NOT NULL,
        insight             VARCHAR2(500)
      )';
  END IF;

  SELECT COUNT(*) INTO table_count FROM all_tables WHERE owner = 'X402_REST' AND table_name = 'BUYER_SEGMENTS';
  IF table_count = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE x402_rest.buyer_segments (
        segment_id              NUMBER PRIMARY KEY,
        segment_name            VARCHAR2(120) NOT NULL,
        use_case                VARCHAR2(200) NOT NULL,
        urgency_score           NUMBER NOT NULL,
        avg_daily_calls         NUMBER NOT NULL,
        willingness_to_pay_usd  NUMBER NOT NULL,
        description             VARCHAR2(500)
      )';
  END IF;

  SELECT COUNT(*) INTO table_count FROM all_tables WHERE owner = 'X402_REST' AND table_name = 'PRICING_BENCHMARKS';
  IF table_count = 0 THEN
    EXECUTE IMMEDIATE '
      CREATE TABLE x402_rest.pricing_benchmarks (
        benchmark_id            NUMBER PRIMARY KEY,
        endpoint_path           VARCHAR2(120) NOT NULL,
        base_price_microusd     NUMBER NOT NULL,
        enriched_price_microusd NUMBER NOT NULL,
        freshness_sla_minutes   NUMBER NOT NULL,
        latency_sla_ms          NUMBER NOT NULL,
        rationale               VARCHAR2(500)
      )';
  END IF;
END;
/

MERGE INTO x402_rest.api_products t
USING (
  SELECT 1 product_id, '/market/signals' api_path, 'Agent Demand Signals' product_name, 'Market Intelligence' category, 'AI research agents and growth teams' buyer_segment, 15 freshness_minutes, 20000 price_microusd, 91 gross_margin_pct, 'High-confidence demand and automation signals that agents can use for market timing.' description FROM dual
  UNION ALL SELECT 2, '/market/pricing', 'API Pricing Benchmarks', 'Pricing Intelligence', 'API product managers and data sellers', 60, 50000, 94, 'Recommended per-call price bands for agent-facing data products.' FROM dual
  UNION ALL SELECT 3, '/market/products', 'Data Product Catalog', 'Product Intelligence', 'Data partnerships teams', 1440, 10000, 88, 'Commercially realistic data products with target buyer, freshness, and margin metadata.' FROM dual
  UNION ALL SELECT 4, '/market/segments', 'Buyer Segment Demand', 'Buyer Intelligence', 'Sales and revenue operations agents', 240, 15000, 89, 'Buyer segment urgency, call volume, and willingness-to-pay indicators.' FROM dual
) s
ON (t.product_id = s.product_id)
WHEN MATCHED THEN UPDATE SET
  t.api_path = s.api_path,
  t.product_name = s.product_name,
  t.category = s.category,
  t.buyer_segment = s.buyer_segment,
  t.freshness_minutes = s.freshness_minutes,
  t.price_microusd = s.price_microusd,
  t.gross_margin_pct = s.gross_margin_pct,
  t.description = s.description
WHEN NOT MATCHED THEN INSERT (
  product_id, api_path, product_name, category, buyer_segment,
  freshness_minutes, price_microusd, gross_margin_pct, description
) VALUES (
  s.product_id, s.api_path, s.product_name, s.category, s.buyer_segment,
  s.freshness_minutes, s.price_microusd, s.gross_margin_pct, s.description
);

MERGE INTO x402_rest.market_signals t
USING (
  SELECT 101 signal_id, TRUNC(SYSDATE) signal_date, 'Retail Media' sector, 'North America' region, 'agent_query_growth_pct' signal_type, 42.7 signal_value, 92 confidence_score, 18 source_count, 20000 price_microusd, 'Retail media teams show strong demand for product availability and price-comparison feeds.' insight FROM dual
  UNION ALL SELECT 102, TRUNC(SYSDATE), 'Cybersecurity', 'Global', 'automated_request_share_pct', 64.2, 95, 31, 30000, 'Security buyers value high-frequency bot and exploit telemetry for autonomous triage.' FROM dual
  UNION ALL SELECT 103, TRUNC(SYSDATE), 'Travel', 'EMEA', 'inventory_volatility_score', 88.4, 89, 14, 25000, 'Travel agents benefit from paid access to fresh inventory and pricing variance signals.' FROM dual
  UNION ALL SELECT 104, TRUNC(SYSDATE), 'Financial Services', 'North America', 'premium_data_conversion_pct', 12.8, 86, 22, 50000, 'Financial workflow agents are more likely to pay for low-latency decision data.' FROM dual
  UNION ALL SELECT 105, TRUNC(SYSDATE), 'Healthcare Operations', 'United States', 'supply_shortage_risk_score', 73.5, 84, 12, 25000, 'Procurement agents can use shortage indicators to trigger earlier buying decisions.' FROM dual
) s
ON (t.signal_id = s.signal_id)
WHEN MATCHED THEN UPDATE SET
  t.signal_date = s.signal_date,
  t.sector = s.sector,
  t.region = s.region,
  t.signal_type = s.signal_type,
  t.signal_value = s.signal_value,
  t.confidence_score = s.confidence_score,
  t.source_count = s.source_count,
  t.price_microusd = s.price_microusd,
  t.insight = s.insight
WHEN NOT MATCHED THEN INSERT (
  signal_id, signal_date, sector, region, signal_type, signal_value,
  confidence_score, source_count, price_microusd, insight
) VALUES (
  s.signal_id, s.signal_date, s.sector, s.region, s.signal_type, s.signal_value,
  s.confidence_score, s.source_count, s.price_microusd, s.insight
);

MERGE INTO x402_rest.buyer_segments t
USING (
  SELECT 201 segment_id, 'AI Research Agents' segment_name, 'Need concise market evidence before drafting recommendations.' use_case, 91 urgency_score, 18000 avg_daily_calls, 0.08 willingness_to_pay_usd, 'High volume, low friction, ideal for x402 micropayments.' description FROM dual
  UNION ALL SELECT 202, 'Revenue Operations Agents', 'Rank accounts by market timing and API purchase intent.', 86, 7200, 0.12, 'Lower volume but stronger willingness to pay for enriched signals.' FROM dual
  UNION ALL SELECT 203, 'Security Automation Agents', 'Prioritize bot, exploit, and abuse indicators for response workflows.', 94, 26000, 0.15, 'Operational urgency supports premium endpoint pricing.' FROM dual
  UNION ALL SELECT 204, 'Procurement Agents', 'Monitor supplier risk and inventory volatility before purchase events.', 79, 5400, 0.07, 'Useful for recurring monitoring and alert triggers.' FROM dual
) s
ON (t.segment_id = s.segment_id)
WHEN MATCHED THEN UPDATE SET
  t.segment_name = s.segment_name,
  t.use_case = s.use_case,
  t.urgency_score = s.urgency_score,
  t.avg_daily_calls = s.avg_daily_calls,
  t.willingness_to_pay_usd = s.willingness_to_pay_usd,
  t.description = s.description
WHEN NOT MATCHED THEN INSERT (
  segment_id, segment_name, use_case, urgency_score, avg_daily_calls,
  willingness_to_pay_usd, description
) VALUES (
  s.segment_id, s.segment_name, s.use_case, s.urgency_score, s.avg_daily_calls,
  s.willingness_to_pay_usd, s.description
);

MERGE INTO x402_rest.pricing_benchmarks t
USING (
  SELECT 301 benchmark_id, '/market/signals' endpoint_path, 20000 base_price_microusd, 100000 enriched_price_microusd, 15 freshness_sla_minutes, 800 latency_sla_ms, 'Fresh agent demand signals support a higher price than static catalog data.' rationale FROM dual
  UNION ALL SELECT 302, '/market/pricing', 50000, 200000, 60, 900, 'Pricing recommendations directly affect revenue decisions, so buyers tolerate a premium.' FROM dual
  UNION ALL SELECT 303, '/market/products', 10000, 50000, 1440, 700, 'Catalog metadata is useful but less time-sensitive.' FROM dual
  UNION ALL SELECT 304, '/market/segments', 15000, 75000, 240, 800, 'Buyer-segment data can be bundled with signals for account prioritization.' FROM dual
) s
ON (t.benchmark_id = s.benchmark_id)
WHEN MATCHED THEN UPDATE SET
  t.endpoint_path = s.endpoint_path,
  t.base_price_microusd = s.base_price_microusd,
  t.enriched_price_microusd = s.enriched_price_microusd,
  t.freshness_sla_minutes = s.freshness_sla_minutes,
  t.latency_sla_ms = s.latency_sla_ms,
  t.rationale = s.rationale
WHEN NOT MATCHED THEN INSERT (
  benchmark_id, endpoint_path, base_price_microusd, enriched_price_microusd,
  freshness_sla_minutes, latency_sla_ms, rationale
) VALUES (
  s.benchmark_id, s.endpoint_path, s.base_price_microusd, s.enriched_price_microusd,
  s.freshness_sla_minutes, s.latency_sla_ms, s.rationale
);

COMMIT;

BEGIN
  FOR object_row IN (
    SELECT 'SALES' object_name, 'VIEW' object_type, 'sales' object_alias FROM dual
    UNION ALL SELECT 'PRODUCTS', 'VIEW', 'products' FROM dual
    UNION ALL SELECT 'CUSTOMERS', 'VIEW', 'customers' FROM dual
    UNION ALL SELECT 'CHANNELS', 'VIEW', 'channels' FROM dual
    UNION ALL SELECT 'MARKET_SIGNALS', 'TABLE', 'signals' FROM dual
    UNION ALL SELECT 'API_PRODUCTS', 'TABLE', 'products' FROM dual
    UNION ALL SELECT 'BUYER_SEGMENTS', 'TABLE', 'segments' FROM dual
    UNION ALL SELECT 'PRICING_BENCHMARKS', 'TABLE', 'pricing' FROM dual
  ) LOOP
    BEGIN
      ORDS.ENABLE_OBJECT(
        p_enabled        => FALSE,
        p_schema         => 'X402_REST',
        p_object         => object_row.object_name,
        p_object_type    => object_row.object_type,
        p_object_alias   => object_row.object_alias,
        p_auto_rest_auth => FALSE
      );
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  COMMIT;
END;
/

BEGIN
  BEGIN
    ORDS_ADMIN.ENABLE_SCHEMA(
      p_enabled => FALSE,
      p_schema  => 'X402_REST'
    );
    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE != -20012 THEN
        RAISE;
      END IF;
  END;
END;
/

BEGIN
  FOR old_object IN (
    SELECT column_value AS name
    FROM TABLE(sys.odcivarchar2list('SALES', 'PRODUCTS', 'CUSTOMERS', 'CHANNELS'))
  ) LOOP
    BEGIN
      ORDS.ENABLE_OBJECT(
        p_enabled        => FALSE,
        p_schema         => 'X402_REST',
        p_object         => old_object.name,
        p_object_type    => 'VIEW',
        p_object_alias   => LOWER(old_object.name),
        p_auto_rest_auth => FALSE
      );
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  COMMIT;
END;
/

BEGIN
  FOR old_object IN (
    SELECT column_value AS name
    FROM TABLE(sys.odcivarchar2list('SALES', 'PRODUCTS', 'CUSTOMERS', 'CHANNELS'))
  ) LOOP
    BEGIN
      EXECUTE IMMEDIATE 'DROP VIEW x402_rest.' || old_object.name;
    EXCEPTION
      WHEN OTHERS THEN
        IF SQLCODE != -942 THEN
          RAISE;
        END IF;
    END;
  END LOOP;
END;
/

BEGIN
  ORDS_ADMIN.ENABLE_SCHEMA(
    p_enabled             => TRUE,
    p_schema              => 'X402_REST',
    p_url_mapping_type    => 'BASE_PATH',
    p_url_mapping_pattern => 'market',
    p_auto_rest_auth      => FALSE
  );
  COMMIT;
END;
/

BEGIN
  FOR object_row IN (
    SELECT 'MARKET_SIGNALS' object_name, 'signals' object_alias FROM dual
    UNION ALL SELECT 'API_PRODUCTS', 'products' FROM dual
    UNION ALL SELECT 'BUYER_SEGMENTS', 'segments' FROM dual
    UNION ALL SELECT 'PRICING_BENCHMARKS', 'pricing' FROM dual
  ) LOOP
    BEGIN
      ORDS.ENABLE_OBJECT(
        p_enabled        => FALSE,
        p_schema         => 'X402_REST',
        p_object         => object_row.object_name,
        p_object_type    => 'TABLE',
        p_object_alias   => object_row.object_alias,
        p_auto_rest_auth => FALSE
      );
    EXCEPTION
      WHEN OTHERS THEN NULL;
    END;
  END LOOP;
  COMMIT;
END;
/

BEGIN
  FOR object_row IN (
    SELECT 'MARKET_SIGNALS' object_name, 'signals' object_alias FROM dual
    UNION ALL SELECT 'API_PRODUCTS', 'products' FROM dual
    UNION ALL SELECT 'BUYER_SEGMENTS', 'segments' FROM dual
    UNION ALL SELECT 'PRICING_BENCHMARKS', 'pricing' FROM dual
  ) LOOP
    ORDS.ENABLE_OBJECT(
      p_enabled        => TRUE,
      p_schema         => 'X402_REST',
      p_object         => object_row.object_name,
      p_object_type    => 'TABLE',
      p_object_alias   => object_row.object_alias,
      p_auto_rest_auth => FALSE
    );
  END LOOP;
  COMMIT;
END;
/

SELECT username, account_status
FROM dba_users
WHERE username = 'X402_REST';

SELECT table_name
FROM all_tables
WHERE owner = 'X402_REST'
AND table_name IN ('MARKET_SIGNALS', 'API_PRODUCTS', 'BUYER_SEGMENTS', 'PRICING_BENCHMARKS')
ORDER BY table_name;
