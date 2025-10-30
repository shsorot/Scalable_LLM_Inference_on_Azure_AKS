#!/usr/bin/env python3
"""
PostgreSQL Database Wipe Script
Drops and recreates the openwebui database
"""
import sys
import psycopg2

if len(sys.argv) < 2:
    print("Usage: python wipe-database.py <connection_string>")
    sys.exit(1)

conn_str = sys.argv[1]

try:
    # Connect to postgres database (not openwebui)
    base_conn_str = conn_str.replace('dbname=openwebui', 'dbname=postgres')

    print("Connecting to PostgreSQL server...")
    conn = psycopg2.connect(base_conn_str)
    conn.autocommit = True
    cur = conn.cursor()

    # Drop database if exists
    print("Dropping database 'openwebui' (if exists)...")
    try:
        cur.execute("DROP DATABASE IF EXISTS openwebui WITH (FORCE)")
        print("[OK] Database dropped")
    except Exception as e:
        print(f"[WARN] Drop warning: {e}")

    # Create fresh database
    print("Creating fresh database 'openwebui'...")
    try:
        cur.execute("CREATE DATABASE openwebui OWNER pgadmin")
        print("[OK] Database created")
    except Exception as e:
        print(f"[WARN] Create warning: {e}")

    # Verify
    cur.execute("SELECT datname FROM pg_database WHERE datname='openwebui'")
    if cur.fetchone():
        print("")
        print("[SUCCESS] Database wiped and recreated successfully!")
        print("          Extensions (vector, uuid-ossp) will be recreated on deployment")
    else:
        print("")
        print("[ERROR] Database verification failed")
        sys.exit(1)

    cur.close()
    conn.close()
    sys.exit(0)

except Exception as e:
    print(f"[ERROR] {e}")
    sys.exit(1)
