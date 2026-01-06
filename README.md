# Smart Energy Grid Monitoring System
## TimescaleDB Performance Analysis Project

**Course:** MSDA9215 - Big Data Analytics  
**Group Members:**
- Niyonagize Festus (101025)
- Mutuyeyesu Honorine (101027)
- Tuyambaze Joseph (101028)

---

## 📋 Project Overview

This project demonstrates TimescaleDB's time-series optimization features through a Smart Energy Grid Monitoring System that analyzes energy consumption data from 1,000 smart meters over 14 days (~4.03 million readings).

### Key Findings
| Feature | Result |
|---------|--------|
| **Chunk Strategy** | 1-day chunks optimal for balanced workloads |
| **Compression** | 53% storage reduction (390 MB → 183 MB) |
| **Continuous Aggregates** | 18x query speedup (59.42 ms → 3.21 ms) |

---

## 📁 Repository Structure

```
smart-energy-grid/
├── README.md                    # This file
├── scripts/
│   └── direct_loader.py         # Historical data generation script
├── sql/
│   ├── 01_setup_schema.sql      # Database and table creation
│   ├── 02_create_hypertables.sql # Different chunk interval tables
│   ├── 03_performance_queries.sql # Benchmark queries (Q1-Q4)
│   ├── 04_compression.sql       # Compression setup and testing
│   ├── 05_continuous_aggregates.sql # Materialized views
│   └── 06_analysis_queries.sql  # Chunk and storage analysis
├── dashboard/
│   └── dashboard.html           # Analytics visualization dashboard
└── docs/
    └── results_summary.md       # Performance results summary
```

---

## 🚀 Quick Start

### Prerequisites
- Docker (for TimescaleDB)
- Python 3.8+
- PostgreSQL client (`psql`)

### 1. Start TimescaleDB
```bash
sudo docker run -d --name timescaledb \
  -p 5434:5432 \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_DB=energy_grid \
  timescale/timescaledb:latest-pg15
```

### 2. Create Schema
```bash
psql -h localhost -p 5434 -U postgres -d energy_grid -f sql/01_setup_schema.sql
```

### 3. Generate Historical Data
```bash
pip install psycopg2-binary
python scripts/direct_loader.py --days 14 --meters 1000 --port 5434
```
**Expected Output:** ~4.03 million rows in ~5-7 minutes

### 4. Run Experiments
```bash
# Create chunk variants
psql -h localhost -p 5434 -U postgres -d energy_grid -f sql/02_create_hypertables.sql

# Run performance queries
psql -h localhost -p 5434 -U postgres -d energy_grid -f sql/03_performance_queries.sql

# Apply compression
psql -h localhost -p 5434 -U postgres -d energy_grid -f sql/04_compression.sql

# Create continuous aggregates
psql -h localhost -p 5434 -U postgres -d energy_grid -f sql/05_continuous_aggregates.sql
```

---

## 📊 Performance Results

### Chunk Interval Comparison
| Query | 3-Hour Chunks | 1-Day Chunks | 1-Week Chunks |
|-------|---------------|--------------|---------------|
| Q1: Hourly avg (1 day) | 295.53 ms | 181.37 ms | **86.24 ms** |
| Q2: Peak periods (7 days) | **414.62 ms** | 1,238.10 ms | 972.51 ms |
| Q3: Monthly per meter | 1,757.17 ms | 1,629.75 ms | **1,444.98 ms** |
| Q4: Full dataset scan | 340.42 ms | **188.86 ms** | 239.31 ms |

### Compression Results
| Table | Before | After | Savings |
|-------|--------|-------|---------|
| 1-Day Chunks | 390 MB | 183 MB | 53% |
| 3-Hour Chunks | 396 MB | 191 MB | 52% |
| 1-Week Chunks | 390 MB | 182 MB | 53% |

### Continuous Aggregate Performance
| Query Type | Execution Time | Speedup |
|------------|----------------|---------|
| Raw Data Query | 59.42 ms | Baseline |
| Continuous Aggregate | 3.21 ms | **18x faster** |

---

## 🔧 Configuration

### Database Connection
```
Host: localhost
Port: 5434
Database: energy_grid
User: postgres
Password: password
```

### Data Generation Parameters
| Parameter | Value |
|-----------|-------|
| Meters | 1,000 |
| Days | 14 |
| Reading Interval | 5 minutes |
| Total Rows | ~4.03 million |

---

## 📝 Files Description

### Python Scripts

| File | Purpose | Expected Result |
|------|---------|-----------------|
| `direct_loader.py` | Generates realistic historical energy data | 4.03M rows in ~5.7 min |

### SQL Scripts

| File | Purpose | Expected Result |
|------|---------|-----------------|
| `01_setup_schema.sql` | Creates database schema and 1-day hypertable | Table ready for data |
| `02_create_hypertables.sql` | Creates 3-hour and 1-week chunk tables | 3 tables with identical data |
| `03_performance_queries.sql` | Runs 4 benchmark queries | Execution times for comparison |
| `04_compression.sql` | Enables and applies compression | ~53% storage reduction |
| `05_continuous_aggregates.sql` | Creates 15min, hourly, daily views | Pre-computed aggregations |
| `06_analysis_queries.sql` | Analyzes chunks and storage | Chunk distribution info |

---

## 👥 Work Distribution

| Member | Responsibilities |
|--------|------------------|
| Niyonagize Festus | [Add contributions] |
| Mutuyeyesu Honorine | [Add contributions] |
| Tuyambaze Joseph | [Add contributions] |

---

## 📚 References

- [TimescaleDB Documentation](https://docs.timescale.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [EMQX MQTT Broker](https://www.emqx.io/)

---

## 📄 License

This project is for academic purposes - MSDA9215 Big Data Analytics course.
