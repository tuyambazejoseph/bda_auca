-- =============================================================================
-- 01_SETUP_SCHEMA.SQL
-- Smart Energy Grid Monitoring System - Initial Database Setup
-- =============================================================================
--
-- PURPOSE:
--   Creates the initial database schema and converts the table to a 
--   TimescaleDB hypertable with 1-day chunk intervals.
--
-- PREREQUISITES:
--   - TimescaleDB Docker container running on port 5434
--   - Database 'energy_grid' exists
--
-- USAGE:
--   psql -h localhost -p 5434 -U postgres -d energy_grid -f 01_setup_schema.sql
--
-- EXPECTED RESULT:
--   - TimescaleDB extension enabled
--   - energy_readings table created
--   - Converted to hypertable with 1-day chunks
--
-- =============================================================================

-- Enable TimescaleDB extension
-- This adds time-series capabilities to PostgreSQL
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Verify TimescaleDB is installed
SELECT default_version, installed_version 
FROM pg_available_extensions 
WHERE name = 'timescaledb';

-- =============================================================================
-- CREATE ENERGY READINGS TABLE
-- =============================================================================
-- Schema designed to store smart meter readings with all required fields
-- for energy monitoring and analysis.

CREATE TABLE IF NOT EXISTS energy_readings (
    -- Primary timestamp field (used for time-partitioning)
    timestamp TIMESTAMPTZ NOT NULL,
    
    -- 10-digit meter identifier (e.g., '0000000001')
    -- First digit can represent region for grouping analysis
    meter_id VARCHAR(10) NOT NULL,
    
    -- Instantaneous power consumption in Watts
    -- Range: 200-3000W for residential meters
    power DOUBLE PRECISION,
    
    -- Voltage reading in Volts
    -- Expected: ~230V with ±5V variation
    voltage DOUBLE PRECISION,
    
    -- Current reading in Amperes
    -- Derived from: power / voltage
    current DOUBLE PRECISION,
    
    -- Grid frequency in Hertz
    -- Expected: ~50Hz with minimal variation
    frequency DOUBLE PRECISION,
    
    -- Energy consumed in this interval (kWh)
    -- Calculated as: power * (interval_minutes/60) / 1000
    energy DOUBLE PRECISION
);

-- =============================================================================
-- CONVERT TO HYPERTABLE
-- =============================================================================
-- A hypertable automatically partitions data by time into "chunks"
-- Each chunk is a separate PostgreSQL table for efficient querying
--
-- chunk_time_interval => INTERVAL '1 day':
--   - Creates one chunk per day
--   - For 14 days of data = 15 chunks
--   - Balanced for most query patterns

SELECT create_hypertable(
    'energy_readings',           -- Table name
    'timestamp',                 -- Time column for partitioning
    chunk_time_interval => INTERVAL '1 day',  -- Chunk size
    if_not_exists => TRUE        -- Don't error if already exists
);

-- =============================================================================
-- CREATE INDEXES FOR COMMON QUERIES
-- =============================================================================
-- Index on meter_id for filtering by specific meters
CREATE INDEX IF NOT EXISTS idx_energy_readings_meter_id 
ON energy_readings (meter_id, timestamp DESC);

-- =============================================================================
-- VERIFY SETUP
-- =============================================================================

-- Check that the table is a hypertable
SELECT hypertable_name, num_dimensions, tablespaces 
FROM timescaledb_information.hypertables 
WHERE hypertable_name = 'energy_readings';

-- Show table structure
\d energy_readings

-- =============================================================================
-- EXPECTED OUTPUT:
-- =============================================================================
-- CREATE EXTENSION (or NOTICE if already exists)
-- CREATE TABLE
-- create_hypertable: (1,public,energy_readings,t)
-- CREATE INDEX
-- hypertable info showing 'energy_readings' with 1 dimension
-- =============================================================================
