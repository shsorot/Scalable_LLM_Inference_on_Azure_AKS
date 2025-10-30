#!/usr/bin/env python3
import psycopg2
import sys

try:
    # Connect to PostgreSQL
    conn = psycopg2.connect(
        'postgresql://pgadmin:9aLgrwTIAHeGk3Xn7zl15sQh!%40%23@shsorot-pg-u6nkmvc5rezpy.postgres.database.azure.com:5432/openwebui?sslmode=require'
    )

    cur = conn.cursor()

    # Enable vector extension
    print("Creating vector extension...")
    cur.execute('CREATE EXTENSION IF NOT EXISTS vector')

    # Enable uuid-ossp extension
    print("Creating uuid-ossp extension...")
    cur.execute('CREATE EXTENSION IF NOT EXISTS "uuid-ossp"')

    # Commit changes
    conn.commit()

    # Verify extensions
    print("\nVerifying extensions...")
    cur.execute("SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'uuid-ossp') ORDER BY extname")
    extensions = cur.fetchall()

    print("\nInstalled extensions:")
    for ext_name, ext_version in extensions:
        print(f"  ✓ {ext_name} version {ext_version}")

    cur.close()
    conn.close()

    print("\n✅ PGVector extensions enabled successfully!")
    sys.exit(0)

except Exception as e:
    print(f"❌ Error: {e}", file=sys.stderr)
    sys.exit(1)


