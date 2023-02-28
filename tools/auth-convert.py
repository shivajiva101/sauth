#!/bin/env python3

# convert an `auth.sqlite` or `sauth.sqlite` file to the other format

# The output file will be named `out-auth.sqlite` or `out-sauth.sqlite`
# depending on the file passed at argv[1] to the script.
# the file format of the input file is checked, and a new file is
# created and given the correct sqlite table schema. If a filename
# already exists, the script stops.

import sqlite3
import sys
import os

try:
    name = sys.argv[1]
except:
    print("Usage: $0 from_db.sqlite")
    exit();

if not os.path.isfile(name):
    print("$1 must be the path to an sqlite database file")
    exit();

try:
    db = sqlite3.connect(name)
except:
    print("$1 must be the path to an sqlite auth or sauth format file")
    exit();

cur = db.cursor()
cur2 = db.cursor()

# check input file table format
has_id = False
has_name = False
has_password = False
has_privileges = False
has_last_login = False

authfileformat = "unknown"

for row in cur.execute("PRAGMA table_info('auth')"):
    has_id |= row[1] == "id"
    has_name |= row[1] == "name"
    has_password |= row[1] == "password"
    has_privileges |= row[1] == "privileges"
    has_last_login |= row[1] == "last_login"

if has_id and has_name and has_password and has_last_login:
    if has_privileges:
        authfileformat = "sauth"
        out_name = "out-auth.sqlite"
    else:
        authfileformat = "auth"
        out_name = "out-sauth.sqlite"
else:
    print("db file does not seem to have the right format!")
    exit()
        
print("Detected " + authfileformat + " format input file")

if os.path.isfile(out_name):
    print("Error: remove or rename " + out_name + " first")
    exit();

print("Creating " + out_name)

try:
    out_db = sqlite3.connect(out_name)
except:
    print("Unable to open " + out_name + " for writing")
    exit();

out_cur = out_db.cursor()

print("Creating auth tables...")

if authfileformat == "sauth":
    # create auth format output file
    out_cur.execute("CREATE TABLE `auth` (`id` INTEGER PRIMARY KEY AUTOINCREMENT,`name` VARCHAR(32) UNIQUE,`password` VARCHAR(512),`last_login` INTEGER);")
    out_cur.execute("CREATE TABLE `user_privileges` (`id` INTEGER,`privilege` VARCHAR(32),PRIMARY KEY (id, privilege)CONSTRAINT fk_id FOREIGN KEY (id) REFERENCES auth (id) ON DELETE CASCADE);")
    out_db.commit()
else:
    # create sauth format output file
    out_cur.execute("CREATE TABLE auth (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);")
    out_cur.execute("CREATE TABLE _s (import BOOLEAN);")
    out_db.commit()


print("Copying entries...")
count = 0
last_id = 0

if authfileformat == "sauth":
    # split privs from auth table into a second table
    for row in cur.execute("SELECT id, name, password, privileges, last_login FROM auth;"):
        count += 1
        if count % 100 == 0:
            print(count)

        last_id = row[0]

        try:
            out_cur.execute("INSERT INTO auth (id, name, password, last_login) VALUES ("
                           + str(row[0]) + ", \"" + row[1] + "\", \"" + row[2] + "\", "
                           + str(row[4]) + ");")
            out_db.commit()
        except:
            print("An error occured for id " + str(row[0]) + " - skipping")
            continue

        try:
            for priv in row[3].replace(" ", "").split(","):
                out_cur.execute("INSERT INTO user_privileges (id, privilege) VALUES ("
                               + str(row[0]) + ", \"" + priv + "\");")
                out_db.commit()
        except:
            print("An error occured for id " + str(row[0]) + " - skipping")
            continue

else:
    # merge user_privileges table into the auth table as a new string column
    for row in cur.execute("SELECT id, name, password, last_login FROM auth;"):
        count += 1
        if count % 100 == 0:
            print(count)

        last_id = row[0]

        priv_str = ""
        for p in cur2.execute("SELECT privilege FROM user_privileges WHERE id = " + str(row[0])):
            if priv_str != "":
                priv_str = priv_str + ","
            priv_str = priv_str + p[0]

        try:
            out_cur.execute("INSERT INTO auth (id, name, password, privileges, last_login) VALUES ("
                           + str(row[0]) + ", \"" + row[1] + "\", \"" + row[2] + "\", \""
                           + priv_str + "\", " + str(row[3]) + ");")
            out_db.commit()
        except:
            print("An error occured for id " + str(row[0]) + " - skipping")
            continue

print(str(count) + " records written, last id = " + str(last_id)) 

# end
db.close()
out_db.commit()
out_db.close()

