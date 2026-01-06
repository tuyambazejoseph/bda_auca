-- =============================================================================
-- 02_CREATE_HYPERTABLES.SQL
-- Smart Energy Grid Monitoring System - Chunk Interval Experimentation
-- =============================================================================
--
-- PURPOSE:
--   Creates two additional hypertables with different chunk intervals
--   (3-hour and 1-week) to compare query performance across strategies.
--
-- WHY DIFFERENT CHUNK SIZES:
--   - 3-hour chunks: Fine-grained, many small chunks (113 chunks for 14 days)
--   - 1-day chunks: Balanced, moderate chunks (15 chunks) - BASELINE
--   - 1-week chunks: Coarse-grained, few large chunks (3 chunks)
--
-- USAGE:
--   psql -h localhost -p 5434 -U postgres -d energy_grid -f 02_create_hypertables.sql
--
-- EXPECTED RESULT:
--   - Two new hypertables created
--   - 4.03M rows copied to each (takes ~1-2 minutes each)
--   - Total: 3 identical datasets with different chunk configurations
--
-- =============================================================================

-- Enable timing to see how long operations take
\timing on

-- =============================================================================
-- CREATE 3-HOUR CHUNK TABLE
-- =============================================================================
-- Fine-grained partitioning: 14 days × 8 chunks/day = 112-113 chunks
-- BEST FOR: Queries on narrow time ranges (chunk exclusion benefits)

-- Create table with same structure as original
CREATE TABLE energy_readings_3h (LIKE energy_readings INCLUDING ALL);

-- Convert to hypertable with 3-hour chunks
SELECT create_hypertable(
    'energy_readings_3h', 
    'timestamp', 
    chunk_time_interval => INTERVAL '3 hours',
    if_not_exists => TRUE
);

-- =============================================================================
-- CREATE 1-WEEK CHUNK TABLE
-- =============================================================================
-- Coarse-grained partitioning: 14 days = 2-3 chunks
-- BEST FOR: Full table scans, wide time range queries

-- Create table with same structure as original
CREATE TABLE energy_readings_week (LIKE energy_readings INCLUDING ALL);

-- Convert to hypertable with 1-week chunks
SELECT create_hypertable(
    'energy_readings_week', 
    'timestamp', 
    chunk_time_interval => INTERVAL '1 week',
    if_not_exists => TRUE
);

-- =============================================================================
-- COPY DATA TO NEW TABLES
-- =============================================================================
-- Copies the same 4.03M rows to each table for fair comparison
-- This ensures identical data across all chunk configurations

-- Copy to 3-hour chunk table (~1-2 minutes)
\echo 'Copying data to 3-hour chunk table...'
INSERT INTO energy_readings_3h SELECT * FROM energy_readings;

-- Copy to 1-week chunk table (~1-2 minutes)
\echo 'Copying data to 1-week chunk table...'
INSERT INTO energy_readings_week SELECT * FROM energy_readings;

-- =============================================================================
-- VERIFY CHUNK DISTRIBUTION
-- =============================================================================
-- Shows how many chunks were created for each configuration

\echo ''
\echo '============================================='
\echo 'CHUNK DISTRIBUTION ANALYSIS'
\echo '============================================='

-- Count chunks for each hypertable
SELECT 
    hypertable_name,
    COUNT(*) as num_chunks
FROM timescaledb_information.chunks
GROUP BY hypertable_name
ORDER BY hypertable_name;

-- Detailed chunk information for 1-day table
\echo ''
\echo '--- 1-Day Chunks (energy_readings) ---'
SELECT 
    chunk_name, 
    range_start::date as start_date, 
    range_end::date as end_date
FROM timescaledb_information.chunks
WHERE hypertable_name = 'energy_readings'
ORDER BY range_start
LIMIT 5;

-- Detailed chunk information for 3-hour table
\echo ''
\echo '--- 3-Hour Chunks (energy_readings_3h) ---'
SELECT 
    chunk_name, 
    range_start, 
    range_end
FROM timescaledb_information.chunks
WHERE hypertable_name = 'energy_readings_3h'
ORDER BY range_start
LIMIT 5;

-- Detailed chunk information for 1-week table
\echo ''
\echo '--- 1-Week Chunks (energy_readings_week) ---'
SELECT 
    chunk_name, 
    range_start::date as start_date, 
    range_end::date as end_date
FROM timescaledb_information.chunks
WHERE hypertable_name = 'energy_readings_week'
ORDER BY range_start;

-- Verify row counts match
\echo ''
\echo '--- Row Count Verification ---'
SELECT 'energy_readings (1-day)' as table_name, COUNT(*) as rows FROM energy_readings
UNION ALL
SELECT 'energy_readings_3h (3-hour)', COUNT(*) FROM energy_readings_3h
UNION ALL
SELECT 'energy_readings_week (1-week)', COUNT(*) FROM energy_readings_week;

-- =============================================================================
-- EXPECTED OUTPUT:
-- =============================================================================
-- Chunk counts:
--   energy_readings (1-day):     15 chunks
--   energy_readings_3h (3-hour): 113 chunks
--   energy_readings_week (1-week): 3 chunks
--
-- Row counts: All three tables should have 4,033,000 rows
-- =============================================================================
