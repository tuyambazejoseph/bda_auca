# Performance Results Summary

## Smart Energy Grid Monitoring System - TimescaleDB Analysis

---

## Dataset Configuration

| Parameter | Value |
|-----------|-------|
| Total Readings | 4,033,000 |
| Number of Meters | 1,000 |
| Data Period | 14 days (Dec 21, 2025 - Jan 4, 2026) |
| Reading Interval | 5 minutes |
| Readings per Meter per Day | 288 |
| Generation Time | 5.7 minutes |
| Insertion Rate | 11,722 rows/second |

---

## 1. Chunk Interval Experiment Results

### Chunk Distribution

| Strategy | Chunk Interval | Number of Chunks |
|----------|----------------|------------------|
| Small | 3 hours | 113 |
| Medium | 1 day | 15 |
| Large | 1 week | 3 |

### Query Performance (Cold Cache)

| Query | Description | 3-Hour | 1-Day | 1-Week | Winner |
|-------|-------------|--------|-------|--------|--------|
| Q1 | Hourly avg (1 day) | 295.53 ms | 181.37 ms | **86.24 ms** | 1-Week |
| Q2 | Peak periods (7 days) | **414.62 ms** | 1,238.10 ms | 972.51 ms | 3-Hour |
| Q3 | Monthly per meter | 1,757.17 ms | 1,629.75 ms | **1,444.98 ms** | 1-Week |
| Q4 | Full dataset scan | 340.42 ms | **188.86 ms** | 239.31 ms | 1-Day |

### Analysis

- **Query 1 (Single Day)**: 1-week chunks fastest because entire day fits in single chunk
- **Query 2 (7 Day Range)**: 3-hour chunks fastest due to better chunk exclusion
- **Query 3 (Full Scan Aggregation)**: 1-week chunks fastest with less coordination overhead
- **Query 4 (Full Dataset)**: 1-day chunks provide optimal parallelism balance

**Recommendation**: Use 1-day chunks for balanced workloads

---

## 2. Compression Results

### Storage Savings

| Table | Before | After | Savings | Ratio |
|-------|--------|-------|---------|-------|
| energy_readings (1-day) | 390 MB | 183 MB | 207 MB (53%) | 2.1x |
| energy_readings_3h | 396 MB | 191 MB | 205 MB (52%) | 2.1x |
| energy_readings_week | 390 MB | 182 MB | 208 MB (53%) | 2.1x |

### Query Performance Impact (1-Day Table)

| Query | Before | After | Change |
|-------|--------|-------|--------|
| Q1 | 181.37 ms | 734.24 ms | +305% (slower) |
| Q2 | 1,238.10 ms | 3,175.28 ms | +156% (slower) |
| Q3 | 1,629.75 ms | 1,586.10 ms | **-3% (faster)** |
| Q4 | 188.86 ms | 428.19 ms | +127% (slower) |

### Analysis

- Compression saves ~53% storage consistently
- Most queries slow down 2-4x due to decompression overhead
- Large aggregation queries (Q3) can be faster due to reduced I/O

**Recommendation**: 
- Compress data older than 24-48 hours
- Keep recent data uncompressed for fast queries
- Use continuous aggregates to query compressed historical data

---

## 3. Continuous Aggregate Results

### Views Created

| View Name | Bucket Size | Use Case |
|-----------|-------------|----------|
| energy_readings_15min | 15 minutes | Real-time monitoring |
| energy_readings_hourly | 1 hour | Daily pattern analysis |
| energy_readings_daily | 1 day | Billing, trend reports |

### Performance Comparison

| Query Type | Execution Time | Improvement |
|------------|----------------|-------------|
| Raw Data Query | 59.42 ms | Baseline |
| Continuous Aggregate | 3.21 ms | **18x faster** |

### Why So Much Faster

1. **No aggregation computation**: Results pre-computed during refresh
2. **Fewer rows to scan**: 96 rows vs 288 for one day
3. **Smaller data size**: Aggregate table more cacheable
4. **Index efficiency**: Optimized indexes on aggregated data

**Recommendation**: Always use continuous aggregates for dashboards and reports

---

## 4. Data Generation Validation

### Consumption Pattern (Generated Data)

| Period | Hours | Expected Range | Actual Average |
|--------|-------|----------------|----------------|
| Night (Low) | 23:00-05:59 | 200-500 W | ~350 W |
| Morning Peak | 06:00-09:59 | 1,500-3,000 W | ~2,250 W |
| Daytime | 10:00-17:59 | 800-1,500 W | ~1,150 W |
| Evening Peak | 18:00-22:59 | 1,500-3,000 W | ~2,250 W |

The generated data successfully simulates realistic residential energy consumption patterns.

---

## 5. Key Recommendations

### For Production Deployment

1. **Chunk Interval**: Use 1-day chunks for balanced performance
2. **Compression**: Implement tiered compression (compress after 24-48 hours)
3. **Continuous Aggregates**: Create 15-min, hourly, and daily tiers
4. **Retention Policy**: Consider dropping raw data > 90 days, keep aggregates

### Optimal Configuration

```sql
-- Primary hypertable with 1-day chunks
SELECT create_hypertable('energy_readings', 'timestamp', 
    chunk_time_interval => INTERVAL '1 day');

-- Compression policy (compress after 24 hours)
ALTER TABLE energy_readings SET (timescaledb.compress);
SELECT add_compression_policy('energy_readings', INTERVAL '24 hours');

-- Continuous aggregates
CREATE MATERIALIZED VIEW energy_readings_15min
WITH (timescaledb.continuous) AS
SELECT meter_id, time_bucket('15 minutes', timestamp) AS bucket,
       AVG(power), MAX(power), SUM(energy)
FROM energy_readings GROUP BY meter_id, bucket;

-- Retention policy (optional)
SELECT add_retention_policy('energy_readings', INTERVAL '90 days');
```

---

## 6. Conclusion

TimescaleDB provides significant performance improvements for time-series data:

| Feature | Benefit |
|---------|---------|
| Hypertables | Automatic time-partitioning |
| Chunk Intervals | Query optimization through chunk exclusion |
| Compression | 53% storage savings |
| Continuous Aggregates | 18x query speedup |

The combination of appropriate chunk sizing, selective compression, and continuous aggregates provides both storage efficiency and query performance for energy monitoring applications.
