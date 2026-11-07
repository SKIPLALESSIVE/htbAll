import hashlib
import sqlite3
import sys


database_path = sys.argv[1]
admin_password = sys.argv[2]

with sqlite3.connect(database_path) as database:
    database.executescript(
        """
        DROP TABLE IF EXISTS users;
        CREATE TABLE users (
            id INTEGER PRIMARY KEY,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            role TEXT NOT NULL CHECK(role IN ('analyst', 'admin'))
        );
        """
    )
    database.execute(
        "INSERT INTO users (username, password_hash, role) VALUES (?, ?, 'admin')",
        ("reports-admin", hashlib.sha256(admin_password.encode()).hexdigest()),
    )

