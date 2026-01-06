-- =============================================================================
-- 04_COMPRESSION.SQL
-- Smart Energy Grid Monitoring System - Compression Implementation
-- =============================================================================
--
-- PURPOSE:
--   Enables and applies TimescaleDB compression to measure storage savings
--   and query performance impact.
--
-- HOW TIMESCALEDB COMPRESSION WORKS:
--   1. Converts row-based storage to columnar format
--   2. Applies delta encoding for sequential timestamps
--   3. Uses dictionary encoding for repeated values (meter_id)
--   4. Compresses similar values together
--
-- TRADE-OFF:
--   - Storage: ~53% reduction (390 MB → 183 MB)
--   - Queries: 2-4x slower (decompression overhead)
--   - Exception: Large aggregation queries may be faster (less I/O)
--
-- USAGE:
--   psql -h localhost -p 5434 -U postgres -d energy_grid -f 04_compression.sql
--
-- =============================================================================

\timing on

\echo ''
\echo '============================================================================='
\echo 'COMPRESSION IMPLEMENTATION'
\echo '============================================================================='

-- =============================================================================
-- STEP 1: MEASURE STORAGE BEFORE COMPRESSION
-- =============================================================================

\echo ''
\echo '--- Storage BEFORE Compression ---'
SELECT 
    hypertable_name,
    pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as size
FROM timescaledb_information.hypertables
ORDER BY hypertable_name;

-- =============================================================================
-- STEP 2: ENABLE COMPRESSION ON ALL TABLES
-- =============================================================================
-- compress_orderby: Orders data by timestamp for optimal compression
-- This is critical for time-series data compression efficiency

\echo ''
\echo '--- Enabling Compression ---'

-- Enable compression on 1-day chunk table
ALTER TABLE energy_readings SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'timestamp DESC'
);
\echo 'Compression enabled on energy_readings (1-day)'

-- Enable compression on 3-hour chunk table
ALTER TABLE energy_readings_3h SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'timestamp DESC'
);
\echo 'Compression enabled on energy_readings_3h (3-hour)'

-- Enable compression on 1-week chunk table
ALTER TABLE energy_readings_week SET (
    timescaledb.compress,
    timescaledb.compress_orderby = 'timestamp DESC'
);
\echo 'Compression enabled on energy_readings_week (1-week)'

-- =============================================================================
-- STEP 3: MANUALLY COMPRESS ALL CHUNKS
-- =============================================================================
-- Note: In production, you'd use add_compression_policy() for automatic
-- compression. Here we manually compress all chunks immediately.

\echo ''
\echo '--- Compressing All Chunks (this may take a few minutes) ---'

-- Compress all chunks in 1-day table
\echo 'Compressing 1-day chunks...'
SELECT compress_chunk(c) 
FROM show_chunks('energy_readings') c;

-- Compress all chunks in 3-hour table
\echo 'Compressing 3-hour chunks...'
SELECT compress_chunk(c) 
FROM show_chunks('energy_readings_3h') c;

-- Compress all chunks in 1-week table
\echo 'Compressing 1-week chunks...'
SELECT compress_chunk(c) 
FROM show_chunks('energy_readings_week') c;

-- =============================================================================
-- STEP 4: MEASURE STORAGE AFTER COMPRESSION
-- =============================================================================

\echo ''
\echo '--- Storage AFTER Compression ---'
SELECT 
    hypertable_name,
    pg_size_pretty(hypertable_size(format('%I.%I', hypertable_schema, hypertable_name)::regclass)) as size
FROM timescaledb_information.hypertables
ORDER BY hypertable_name;

-- =============================================================================
-- STEP 5: DETAILED COMPRESSION STATISTICS
-- =============================================================================

\echo ''
\echo '--- Compression Statistics ---'
SELECT 
    hypertable_name,
    compression_status,
    COUNT(*) as chunk_count,
    pg_size_pretty(SUM(before_compression_total_bytes)) as before_size,
    pg_size_pretty(SUM(after_compression_total_bytes)) as after_size,
    ROUND(100.0 * (1 - SUM(after_compression_total_bytes)::float / 
          NULLIF(SUM(before_compression_total_bytes), 0)), 1) as savings_pct
FROM timescaledb_information.chunks c
JOIN timescaledb_information.hypertables h USING (hypertable_schema, hypertable_name)
LEFT JOIN timescaledb_information.compressed_chunk_stats s ON c.chunk_name = s.chunk_name
GROUP BY hypertable_name, compression_status
ORDER BY hypertable_name;

-- =============================================================================
-- STEP 6: TEST QUERY PERFORMANCE AFTER COMPRESSION
-- =============================================================================

\echo ''
\echo '============================================='
\echo 'QUERY PERFORMANCE AFTER COMPRESSION (1-Day Table)'
\echo '============================================='

\echo '--- Query 1: Hourly Average ---'
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) as avg_power
FROM energy_readings
WHERE timestamp >= '2026-01-04'::date
GROUP BY hour 
ORDER BY hour;

\echo '--- Query 2: Peak Periods ---'
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) as avg_power
FROM energy_readings
WHERE timestamp >= '2025-12-28'::date
GROUP BY period 
ORDER BY avg_power DESC 
LIMIT 10;

\echo '--- Query 3: Monthly per Meter ---'
SELECT meter_id,
       DATE_TRUNC('month', timestamp) as month,
       SUM(energy) as total_energy
FROM energy_readings
GROUP BY meter_id, month
ORDER BY month, total_energy DESC
LIMIT 20;

\echo '--- Query 4: Full Dataset ---'
SELECT COUNT(*), 
       AVG(power), 
       MAX(power), 
       MIN(power)
FROM energy_readings;

-- =============================================================================
-- RESULTS SUMMARY
-- =============================================================================

\echo ''
\echo '============================================================================='
\echo 'COMPRESSION RESULTS SUMMARY'
\echo '============================================================================='
\echo ''
\echo 'STORAGE SAVINGS:'
\echo '| Table                | Before   | After    | Savings |'
\echo '|----------------------|----------|----------|---------|'
\echo '| energy_readings      | 390 MB   | 183 MB   | 53%     |'
\echo '| energy_readings_3h   | 396 MB   | 191 MB   | 52%     |'
\echo '| energy_readings_week | 390 MB   | 182 MB   | 53%     |'
\echo ''
\echo 'QUERY PERFORMANCE IMPACT (1-Day Chunks):'
\echo '| Query | Before      | After       | Change       |'
\echo '|-------|-------------|-------------|--------------|'
\echo '| Q1    | 181.37 ms   | 734.24 ms   | +305% slower |'
\echo '| Q2    | 1238.10 ms  | 3175.28 ms  | +156% slower |'
\echo '| Q3    | 1629.75 ms  | 1586.10 ms  | -3% faster   |'
\echo '| Q4    | 188.86 ms   | 428.19 ms   | +127% slower |'
\echo ''
\echo 'KEY INSIGHT: Compression saves 53% storage but slows most queries.'
\echo 'Use for archival data, keep recent data uncompressed.'
\echo '============================================================================='
