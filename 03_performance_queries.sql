-- =============================================================================
-- 03_PERFORMANCE_QUERIES.SQL
-- Smart Energy Grid Monitoring System - Benchmark Queries
-- =============================================================================
--
-- PURPOSE:
--   Runs 4 standard benchmark queries against all three chunk configurations
--   to measure query performance differences.
--
-- IMPORTANT - COLD CACHE TESTING:
--   For accurate results, restart PostgreSQL before running these queries:
--   sudo docker restart timescaledb
--   Wait 10 seconds, then run this script.
--
-- USAGE:
--   psql -h localhost -p 5434 -U postgres -d energy_grid -f 03_performance_queries.sql
--
-- EXPECTED RESULTS (approximate):
--   Query 1: 86-295 ms depending on chunk size
--   Query 2: 414-1238 ms depending on chunk size
--   Query 3: 1444-1757 ms depending on chunk size
--   Query 4: 188-340 ms depending on chunk size
--
-- =============================================================================

-- Enable timing for performance measurement
\timing on

\echo ''
\echo '============================================================================='
\echo 'PERFORMANCE BENCHMARK QUERIES'
\echo 'Testing all queries on all three chunk configurations'
\echo '============================================================================='

-- =============================================================================
-- QUERY 1: HOURLY AVERAGE POWER CONSUMPTION (SINGLE DAY)
-- =============================================================================
-- PURPOSE: Analyze daily consumption patterns
-- CHARACTERISTICS: Single-day range, hourly aggregation
-- EXPECTED WINNER: Larger chunks (less coordination overhead)

\echo ''
\echo '============================================='
\echo 'QUERY 1: Hourly Average Power (1 day)'
\echo '============================================='

\echo '--- 1-Day Chunks ---'
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) as avg_power
FROM energy_readings
WHERE timestamp >= '2026-01-04'::date
GROUP BY hour 
ORDER BY hour;

\echo '--- 3-Hour Chunks ---'
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) as avg_power
FROM energy_readings_3h
WHERE timestamp >= '2026-01-04'::date
GROUP BY hour 
ORDER BY hour;

\echo '--- 1-Week Chunks ---'
SELECT time_bucket('1 hour', timestamp) AS hour,
       AVG(power) as avg_power
FROM energy_readings_week
WHERE timestamp >= '2026-01-04'::date
GROUP BY hour 
ORDER BY hour;


-- =============================================================================
-- QUERY 2: PEAK CONSUMPTION PERIODS (7 DAYS)
-- =============================================================================
-- PURPOSE: Find highest consumption periods for load balancing
-- CHARACTERISTICS: 7-day range, sorting, limiting
-- EXPECTED WINNER: Smaller chunks (better chunk exclusion)

\echo ''
\echo '============================================='
\echo 'QUERY 2: Peak Periods (7 days, TOP 10)'
\echo '============================================='

\echo '--- 1-Day Chunks ---'
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) as avg_power
FROM energy_readings
WHERE timestamp >= '2025-12-28'::date
GROUP BY period 
ORDER BY avg_power DESC 
LIMIT 10;

\echo '--- 3-Hour Chunks ---'
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) as avg_power
FROM energy_readings_3h
WHERE timestamp >= '2025-12-28'::date
GROUP BY period 
ORDER BY avg_power DESC 
LIMIT 10;

\echo '--- 1-Week Chunks ---'
SELECT time_bucket('15 minutes', timestamp) AS period,
       AVG(power) as avg_power
FROM energy_readings_week
WHERE timestamp >= '2025-12-28'::date
GROUP BY period 
ORDER BY avg_power DESC 
LIMIT 10;


-- =============================================================================
-- QUERY 3: MONTHLY CONSUMPTION PER METER
-- =============================================================================
-- PURPOSE: Billing and usage analysis per meter
-- CHARACTERISTICS: Full dataset, grouping by meter and month
-- EXPECTED WINNER: Larger chunks (less overhead for full scan)

\echo ''
\echo '============================================='
\echo 'QUERY 3: Monthly Consumption per Meter'
\echo '============================================='

\echo '--- 1-Day Chunks ---'
SELECT meter_id,
       DATE_TRUNC('month', timestamp) as month,
       SUM(energy) as total_energy
FROM energy_readings
GROUP BY meter_id, month
ORDER BY month, total_energy DESC
LIMIT 20;

\echo '--- 3-Hour Chunks ---'
SELECT meter_id,
       DATE_TRUNC('month', timestamp) as month,
       SUM(energy) as total_energy
FROM energy_readings_3h
GROUP BY meter_id, month
ORDER BY month, total_energy DESC
LIMIT 20;

\echo '--- 1-Week Chunks ---'
SELECT meter_id,
       DATE_TRUNC('month', timestamp) as month,
       SUM(energy) as total_energy
FROM energy_readings_week
GROUP BY meter_id, month
ORDER BY month, total_energy DESC
LIMIT 20;


-- =============================================================================
-- QUERY 4: FULL DATASET STATISTICS
-- =============================================================================
-- PURPOSE: Overall system statistics
-- CHARACTERISTICS: Full table scan, no filtering
-- EXPECTED WINNER: Medium chunks (balanced parallelism)

\echo ''
\echo '============================================='
\echo 'QUERY 4: Full Dataset Statistics'
\echo '============================================='

\echo '--- 1-Day Chunks ---'
SELECT COUNT(*), 
       AVG(power), 
       MAX(power), 
       MIN(power)
FROM energy_readings;

\echo '--- 3-Hour Chunks ---'
SELECT COUNT(*), 
       AVG(power), 
       MAX(power), 
       MIN(power)
FROM energy_readings_3h;

\echo '--- 1-Week Chunks ---'
SELECT COUNT(*), 
       AVG(power), 
       MAX(power), 
       MIN(power)
FROM energy_readings_week;


-- =============================================================================
-- RESULTS SUMMARY TABLE
-- =============================================================================

\echo ''
\echo '============================================================================='
\echo 'RECORD YOUR RESULTS IN THIS FORMAT:'
\echo '============================================================================='
\echo ''
\echo '| Query | Description              | 3-Hour    | 1-Day     | 1-Week    |'
\echo '|-------|--------------------------|-----------|-----------|-----------|'
\echo '| Q1    | Hourly avg (1 day)       | ___ ms    | ___ ms    | ___ ms    |'
\echo '| Q2    | Peak periods (7 days)    | ___ ms    | ___ ms    | ___ ms    |'
\echo '| Q3    | Monthly per meter        | ___ ms    | ___ ms    | ___ ms    |'
\echo '| Q4    | Full dataset scan        | ___ ms    | ___ ms    | ___ ms    |'
\echo ''
\echo 'OUR RESULTS:'
\echo '| Q1    | Hourly avg (1 day)       | 295.53 ms | 181.37 ms | 86.24 ms  |'
\echo '| Q2    | Peak periods (7 days)    | 414.62 ms | 1238.10ms | 972.51 ms |'
\echo '| Q3    | Monthly per meter        | 1757.17ms | 1629.75ms | 1444.98ms |'
\echo '| Q4    | Full dataset scan        | 340.42 ms | 188.86 ms | 239.31 ms |'
\echo '============================================================================='
