import sys
import json
from sqlalchemy import create_engine, MetaData
from sqlalchemy.orm import sessionmaker

# Database URL from .env
DATABASE_URL = "mysql+pymysql://root:220104@localhost/trawime_db?charset=utf8mb4"

try:
    engine = create_engine(DATABASE_URL)
    metadata = MetaData()
    metadata.reflect(bind=engine)
    
    db_schema = {}
    db_schema["tables"] = {}
    
    SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = SessionLocal()
    
    for table_name in metadata.tables:
        table = metadata.tables[table_name]
        columns = []
        for col in table.columns:
            columns.append({
                "name": col.name,
                "type": str(col.type),
                "primary_key": col.primary_key,
                "nullable": col.nullable
            })
        
        # Get sample data
        sample_data = []
        try:
            result = db.execute(table.select().limit(5))
            for row in result:
                # Convert row to dict
                row_dict = {}
                for key, value in zip(row.keys(), row):
                    row_dict[key] = str(value)
                sample_data.append(row_dict)
        except Exception as e:
            sample_data = [f"Error fetching data: {str(e)}"]

        db_schema["tables"][table_name] = {
            "columns": columns,
            "sample_data": sample_data
        }
    
    db.close()
    
    with open("db_schema_dump.json", "w", encoding="utf-8") as f:
        json.dump(db_schema, f, indent=4, ensure_ascii=False)
        
    print("Successfully dumped database schema and sample data to db_schema_dump.json")

except Exception as e:
    print(f"Error connecting to or dumping database: {str(e)}")
    sys.exit(1)
