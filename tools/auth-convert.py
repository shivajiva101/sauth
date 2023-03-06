#!/bin/env python3

# convert v1.1 sauth.sqlite file to builtin auth schema

import sys, sqlite3, os

name = "sauth.sqlite"

if not os.path.isfile(name):
    print("You must run this script in a folder where sauth.sqlite exists!")
    sys.exit(1)

try:
    db = sqlite3.connect(name)
except:
    print("You must use a database file!")
    sys.exit(1)

cur = db.cursor()

# check input file table format
has_id = False
has_name = False
has_password = False
has_privileges = False
has_last_login = False

for row in cur.execute("PRAGMA table_info('auth');"):
    has_id |= row[1] == "id"
    has_name |= row[1] == "name"
    has_password |= row[1] == "password"
    has_privileges |= row[1] == "privileges"
    has_last_login |= row[1] == "last_login"

if has_id and has_name and has_password and has_privileges and has_last_login:
    out_name = "out-auth.sqlite"
else:
    print("db file does not have the right table format!")
    sys.exit(1)

if os.path.isfile(out_name):
    print(f"Error: remove or rename {out_name} first!")
    sys.exit(1)

print(f"Creating {out_name} file...")

try:
    db2 = sqlite3.connect(out_name)
except:
    print(f"Unable to open {out_name} for writing")
    sys.exit(1)

cur2 = db2.cursor()

print("Creating db tables...")

# create auth format db file
cur2.execute("CREATE TABLE `auth` (`id` INTEGER PRIMARY KEY AUTOINCREMENT,`name` VARCHAR(32) UNIQUE,`password` VARCHAR(512),`last_login` INTEGER);")
cur2.execute("CREATE TABLE `user_privileges` (`id` INTEGER,`privilege` VARCHAR(32),PRIMARY KEY (id, privilege)CONSTRAINT fk_id FOREIGN KEY (id) REFERENCES auth (id) ON DELETE CASCADE);")
cur2.execute("CREATE TABLE `tmp` (`id` INTEGER PRIMARY KEY AUTOINCREMENT,`name` VARCHAR(32) UNIQUE ON CONFLICT REPLACE,`password` VARCHAR(512),`last_login` INTEGER);")
db2.commit()

print("Copying entries...")
ctr = 0
last_id = 0
privs = []

# fetch auth table data and insert it into tmp table
cur.execute("SELECT id, name, password, last_login FROM auth;")
result = cur.fetchall()

cur2.executemany("INSERT INTO tmp VALUES (?, ?, ?, ?);", result)
db2.commit()

# fetch tmp table data and insert it into auth table
cur2.execute("SELECT id, name, password, last_login FROM tmp;")
result = cur2.fetchall()

cur2.executemany("INSERT INTO auth VALUES (?, ?, ?, ?);", result)
db2.commit()

# drop tmp table
cur2.execute("DROP TABLE tmp;")
db2.commit()

# split privs from auth table into user_privileges table
for row in cur.execute("SELECT id, privileges FROM auth;"):
    ctr += 1
    last_id = row[0]

    for priv in row[1].replace(" ", "").split(","):
        privs.append((row[0], priv))

cur2.executemany("INSERT INTO user_privileges VALUES (?, ?);", privs)
db2.commit()

print(f"{str(ctr)} records written, last id = {str(last_id)}")

# end
cur2.execute("VACUUM;")
db2.commit()
db.close()
db2.close()
