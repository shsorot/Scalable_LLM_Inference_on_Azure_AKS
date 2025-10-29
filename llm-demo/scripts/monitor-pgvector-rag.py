#!/usr/bin/env python3
import psycopg2
import sys
import time

def check_pgvector():
    try:
        conn = psycopg2.connect(
            'postgresql://pgadmin:3nm6FVeQhtzub8jk0AxRyKsc!%40%23@shsorot-pg-u6nkmvc5rezpy.postgres.database.azure.com:5432/openwebui?sslmode=require'
        )
        
        cur = conn.cursor()
        
        print("\n" + "="*60)
        print("PGVector RAG Monitoring")
        print("="*60)
        
        # Check documents
        print("\n1. Documents uploaded:")
        cur.execute("SELECT id, name, created_at FROM document ORDER BY created_at DESC LIMIT 10")
        docs = cur.fetchall()
        if docs:
            for doc_id, name, created_at in docs:
                print(f"   📄 {name} (ID: {doc_id[:8]}...)")
                print(f"      Created: {created_at}")
        else:
            print("   (No documents uploaded yet)")
        
        # Check document chunks with vectors
        print("\n2. Vector embeddings stored:")
        cur.execute("""
            SELECT 
                collection_name,
                COUNT(*) as chunk_count,
                array_length(embedding, 1) as vector_dimensions
            FROM document_chunk 
            GROUP BY collection_name, array_length(embedding, 1)
        """)
        chunks = cur.fetchall()
        if chunks:
            for collection, count, dimensions in chunks:
                print(f"   🔢 Collection: {collection}")
                print(f"      Chunks: {count}")
                print(f"      Dimensions: {dimensions}")
        else:
            print("   (No embeddings yet - waiting for document upload)")
        
        # Check total storage
        cur.execute("SELECT COUNT(*) FROM document_chunk")
        total_chunks = cur.fetchone()[0]
        
        if total_chunks > 0:
            cur.execute("""
                SELECT 
                    pg_size_pretty(pg_total_relation_size('document_chunk')) as table_size
            """)
            size = cur.fetchone()[0]
            print(f"\n3. Storage usage:")
            print(f"   Total chunks: {total_chunks}")
            print(f"   Table size: {size}")
        
        # Check active connections
        print("\n4. Active connections:")
        cur.execute("""
            SELECT 
                application_name,
                COUNT(*) as connection_count,
                state
            FROM pg_stat_activity 
            WHERE datname = 'openwebui' 
            GROUP BY application_name, state
            ORDER BY connection_count DESC
        """)
        conns = cur.fetchall()
        for app_name, count, state in conns:
            if app_name:
                print(f"   {app_name}: {count} ({state})")
        
        cur.close()
        conn.close()
        
        print("\n" + "="*60)
        if total_chunks > 0:
            print("✅ RAG is active! Documents are being processed.")
        else:
            print("⏳ Waiting for document upload to test RAG...")
        print("="*60 + "\n")
        
    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    check_pgvector()
