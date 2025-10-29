#!/usr/bin/env python3
import psycopg2
import sys

try:
    # Connect to PostgreSQL
    conn = psycopg2.connect(
        'postgresql://pgadmin:3nm6FVeQhtzub8jk0AxRyKsc!%40%23@shsorot-pg-u6nkmvc5rezpy.postgres.database.azure.com:5432/openwebui?sslmode=require'
    )
    
    cur = conn.cursor()
    
    # Check what tables exist
    print("=== Checking PGVector Setup ===\n")
    
    print("1. Extensions installed:")
    cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp') ORDER BY extname")
    for ext_name, ext_version in cur.fetchall():
        print(f"   ✓ {ext_name} v{ext_version}")
    
    print("\n2. Tables in openwebui database:")
    cur.execute("""
        SELECT table_name, table_type 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        ORDER BY table_name
    """)
    tables = cur.fetchall()
    if tables:
        for table_name, table_type in tables:
            print(f"   - {table_name} ({table_type})")
    else:
        print("   (No tables yet - will be created on first document upload)")
    
    print("\n3. Ready for RAG operations!")
    print("   - Upload a document via Web UI")
    print("   - PGVector will auto-create tables on first use")
    print("   - All 3 replicas will share the same vector database")
    
    cur.close()
    conn.close()
    
    sys.exit(0)
    
except Exception as e:
    print(f"❌ Error: {e}", file=sys.stderr)
    sys.exit(1)
