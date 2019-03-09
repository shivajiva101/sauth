/*
sauth mod support file - created by shivajiva101@hotmail.com

Use this file to import the data set from a Minetest 0.5 auth.sqlite
database file by copying it to the world folder you want to apply it
to and importing it with sqlite from that location. See readme file
for further information on using sqlite to import the default db.
*/

PRAGMA foreign_keys=off;

ATTACH DATABASE "auth.sqlite" AS src;

BEGIN TRANSACTION;

-- tables
CREATE TABLE IF NOT EXISTS auth (name VARCHAR(32) PRIMARY KEY, password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS _s (import BOOLEAN, db_version VARCHAR (6));

-- itermediary table for priv conversion
CREATE TABLE IF NOT EXISTS tmp (id INTEGER, name VARCHAR(32) PRIMARY KEY, password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);

-- copy data that doesn't req processing
INSERT INTO tmp (id, name, password, last_login) SELECT id, name, password, last_login from src.auth;

-- process privileges using group_concat
UPDATE tmp
SET
    privileges = (
    SELECT group_concat(privilege, ',') AS privileges FROM src.user_privileges WHERE id = tmp.id
);

-- copy data dropping id
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login from tmp;

-- clean up
DROP TABLE tmp;

-- add the status settings
INSERT INTO _s VALUES ('true', '1.1');

COMMIT;

DETACH DATABASE src;

PRAGMA foreign_keys=on;
