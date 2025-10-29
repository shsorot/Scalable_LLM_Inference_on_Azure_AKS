#!/usr/bin/env python3
import psycopg2

conn = psycopg2.connect(
    'postgresql://pgadmin:3nm6FVeQhtzub8jk0AxRyKsc!%40%23@shsorot-pg-u6nkmvc5rezpy.postgres.database.azure.com:5432/openwebui?sslmode=require'
)

cur = conn.cursor()

# Check table structure
print("\n=== document_chunk table structure ===")
cur.execute("""
    SELECT column_name, data_type 
    FROM information_schema.columns 
    WHERE table_name = 'document_chunk' 
    ORDER BY ordinal_position
""")
cols = cur.fetchall()
for name, dtype in cols:
    print(f"  - {name}: {dtype}")

# Count chunks
cur.execute("SELECT COUNT(*) FROM document_chunk")
count = cur.fetchone()[0]
print(f"\nTotal vector chunks: {count}")

# Sample data
if count > 0:
    print("\nSample data (first 3 chunks):")
    cur.execute("SELECT * FROM document_chunk LIMIT 3")
    rows = cur.fetchall()
    for row in rows:
        print(f"  ID: {row[0]}")

conn.close()
