#!/usr/bin/env python3
"""
=============================================================================
DIRECT DATA LOADER FOR TIMESCALEDB
Smart Energy Grid Monitoring System
=============================================================================

PURPOSE:
    Generates realistic historical energy meter data and loads it directly
    into TimescaleDB. This approach is used instead of real-time MQTT 
    streaming for efficient bulk data loading for performance experiments.

WHY THIS APPROACH:
    1. Time Efficiency: 14 days of data in ~5.7 minutes (vs 14 actual days)
    2. Experimental Control: Identical datasets across all chunk configurations
    3. Realistic Patterns: Simulates morning/evening peaks, overnight lows
    4. Focus on Analysis: Enables TimescaleDB performance testing

USAGE:
    python direct_loader.py --days 14 --meters 1000 --port 5434

EXPECTED OUTPUT:
    - ~4.03 million rows generated
    - Insertion rate: ~11,700 rows/second
    - Total time: ~5.7 minutes

DATA PATTERNS GENERATED:
    - Night (23:00-05:59):    200-500W   (baseline - standby devices)
    - Morning Peak (06:00-09:59): 1500-3000W (showers, breakfast)
    - Daytime (10:00-17:59):  800-1500W  (moderate activity)
    - Evening Peak (18:00-22:59): 1500-3000W (cooking, entertainment)

=============================================================================
"""

import psycopg2
from psycopg2.extras import execute_values
from datetime import datetime, timedelta
import random
import argparse
import time


def generate_reading(meter_id: str, timestamp: datetime) -> tuple:
    """
    Generate a single realistic energy meter reading.
    
    The function simulates real-world consumption patterns based on time of day,
    following the characteristic "double-peak" pattern observed in residential
    energy consumption.
    
    Args:
        meter_id: 10-digit meter identifier (e.g., "0000000001")
        timestamp: Reading timestamp
    
    Returns:
        Tuple of (timestamp, meter_id, power, voltage, current, frequency, energy)
    
    Power Consumption Patterns:
        - Peak hours (6-9 AM, 6-10 PM): 1500-3000W (high usage)
        - Night hours (11 PM - 5 AM): 200-500W (low usage)
        - Daytime (10 AM - 5 PM): 800-1500W (medium usage)
    """
    hour = timestamp.hour
    
    # Realistic consumption patterns by time of day
    if 6 <= hour <= 9 or 18 <= hour <= 22:  # Peak hours
        base_power = random.uniform(1500, 3000)  # High usage
    elif 23 <= hour or hour <= 5:  # Night hours
        base_power = random.uniform(200, 500)    # Low usage
    else:  # Daytime hours (10 AM - 5 PM)
        base_power = random.uniform(800, 1500)   # Medium usage
    
    # Generate other electrical parameters
    voltage = random.gauss(230, 5)        # ~230V with normal variation
    current = base_power / voltage         # Ohm's law: I = P/V
    frequency = random.gauss(50, 0.1)      # ~50Hz grid frequency
    energy = base_power * (5/60) / 1000    # kWh for 5-minute interval
    
    return (timestamp, meter_id, base_power, voltage, current, frequency, energy)


def load_data(args):
    """
    Main function to generate and load historical data into TimescaleDB.
    
    Process:
        1. Connect to TimescaleDB
        2. Generate meter IDs (10-digit format)
        3. Loop through time range (past N days to now)
        4. Generate readings for each meter at 5-minute intervals
        5. Batch insert for efficiency (10,000 rows per commit)
    
    Args:
        args: Command line arguments containing connection details and parameters
    """
    
    # Connect to TimescaleDB
    print("Connecting to TimescaleDB...")
    conn = psycopg2.connect(
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        user=args.user,
        password=args.password
    )
    cursor = conn.cursor()
    print(f"Connected to {args.dbname} on {args.host}:{args.port}")
    
    # Generate meter IDs (10-digit zero-padded numbers)
    # Format: 0000000001 through 0000001000
    # First digit can represent regions for grouping analysis
    meters = [f"{i:010d}" for i in range(1, args.meters + 1)]
    
    # Calculate time range (from X days ago until now)
    end_time = datetime.now()
    start_time = end_time - timedelta(days=args.days)
    
    # 5-minute intervals = 288 readings per meter per day
    interval = timedelta(minutes=5)
    readings_per_day = 288
    total_readings = args.meters * readings_per_day * args.days
    
    print(f"\n{'='*60}")
    print(f"DATA GENERATION PARAMETERS")
    print(f"{'='*60}")
    print(f"Meters:          {args.meters:,}")
    print(f"Days:            {args.days}")
    print(f"Reading interval: 5 minutes")
    print(f"Total readings:  {total_readings:,}")
    print(f"Period:          {start_time} to {end_time}")
    print(f"Batch size:      {args.batch_size:,} rows")
    print(f"{'='*60}\n")
    
    batch = []
    batch_size = args.batch_size
    total_inserted = 0
    start = time.time()
    
    # Generate data: loop through time, then meters
    current_time = start_time
    while current_time <= end_time:
        for meter_id in meters:
            # Generate realistic reading for this meter at this time
            reading = generate_reading(meter_id, current_time)
            batch.append(reading)
            
            # Batch insert when batch is full
            if len(batch) >= batch_size:
                execute_values(
                    cursor,
                    """INSERT INTO energy_readings 
                       (timestamp, meter_id, power, voltage, current, frequency, energy)
                       VALUES %s""",
                    batch
                )
                conn.commit()
                total_inserted += len(batch)
                
                # Progress update
                elapsed = time.time() - start
                rate = total_inserted / elapsed if elapsed > 0 else 0
                remaining = (total_readings - total_inserted) / rate if rate > 0 else 0
                pct = 100 * total_inserted / total_readings
                print(f"\rProgress: {total_inserted:,}/{total_readings:,} "
                      f"({pct:.1f}%) - {rate:.0f} rows/sec - ETA: {remaining/60:.1f} min", 
                      end="", flush=True)
                
                batch = []
        
        current_time += interval
    
    # Insert any remaining rows
    if batch:
        execute_values(
            cursor,
            """INSERT INTO energy_readings 
               (timestamp, meter_id, power, voltage, current, frequency, energy)
               VALUES %s""",
            batch
        )
        conn.commit()
        total_inserted += len(batch)
    
    # Final statistics
    elapsed = time.time() - start
    print(f"\n\n{'='*60}")
    print(f"LOADING COMPLETE")
    print(f"{'='*60}")
    print(f"Total rows inserted: {total_inserted:,}")
    print(f"Time elapsed:        {elapsed/60:.1f} minutes")
    print(f"Average rate:        {total_inserted/elapsed:.0f} rows/sec")
    
    # Verify data in database
    cursor.execute("SELECT COUNT(*) FROM energy_readings")
    count = cursor.fetchone()[0]
    print(f"\nVerification:")
    print(f"  Rows in table:     {count:,}")
    
    cursor.execute("SELECT MIN(timestamp), MAX(timestamp) FROM energy_readings")
    min_ts, max_ts = cursor.fetchone()
    print(f"  Date range:        {min_ts} to {max_ts}")
    
    # Show sample of consumption pattern
    print(f"\nSample consumption pattern (hourly averages):")
    cursor.execute("""
        SELECT EXTRACT(HOUR FROM timestamp)::int as hour, 
               ROUND(AVG(power)::numeric, 2) as avg_power
        FROM energy_readings 
        WHERE timestamp >= NOW() - INTERVAL '1 day'
        GROUP BY hour 
        ORDER BY hour
        LIMIT 6
    """)
    for row in cursor.fetchall():
        print(f"  Hour {row[0]:02d}:00 - Avg Power: {row[1]:,.2f} W")
    
    print(f"{'='*60}")
    
    cursor.close()
    conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Load historical energy data into TimescaleDB",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Load 14 days of data for 1000 meters (default)
  python direct_loader.py

  # Custom configuration
  python direct_loader.py --days 7 --meters 500 --port 5432

  # Full options
  python direct_loader.py --host localhost --port 5434 --dbname energy_grid \\
                          --user postgres --password password \\
                          --days 14 --meters 1000 --batch-size 10000
        """
    )
    
    # Database connection arguments
    parser.add_argument("--host", default="localhost",
                        help="Database host (default: localhost)")
    parser.add_argument("--port", type=int, default=5434,
                        help="Database port (default: 5434)")
    parser.add_argument("--dbname", default="energy_grid",
                        help="Database name (default: energy_grid)")
    parser.add_argument("--user", default="postgres",
                        help="Database user (default: postgres)")
    parser.add_argument("--password", default="password",
                        help="Database password (default: password)")
    
    # Data generation arguments
    parser.add_argument("--days", type=int, default=14,
                        help="Number of days of historical data (default: 14)")
    parser.add_argument("--meters", type=int, default=1000,
                        help="Number of meters to simulate (default: 1000)")
    parser.add_argument("--batch-size", type=int, default=10000,
                        help="Rows per batch insert (default: 10000)")
    
    args = parser.parse_args()
    load_data(args)
