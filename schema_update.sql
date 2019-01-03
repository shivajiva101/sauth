PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS auth_ABC (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_DEF (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_GHI (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_JKL (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_MNO (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_PQR (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_STU (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_VWX (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_YZ (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_09 (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);
CREATE TABLE IF NOT EXISTS auth_MISC (id INTEGER PRIMARY KEY AUTOINCREMENT, name VARCHAR(32), password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);

INSERT INTO auth_ABC SELECT * FROM auth where name like "a%";
INSERT INTO auth_ABC SELECT * FROM auth where name like "b%";
INSERT INTO auth_ABC SELECT * FROM auth where name like "c%";
INSERT INTO auth_DEF SELECT * FROM auth where name like "d%";
INSERT INTO auth_DEF SELECT * FROM auth where name like "e%";
INSERT INTO auth_DEF SELECT * FROM auth where name like "f%";
INSERT INTO auth_GHI SELECT * FROM auth where name like "g%";
INSERT INTO auth_GHI SELECT * FROM auth where name like "h%";
INSERT INTO auth_GHI SELECT * FROM auth where name like "i%";
INSERT INTO auth_JKL SELECT * FROM auth where name like "j%";
INSERT INTO auth_JKL SELECT * FROM auth where name like "k%";
INSERT INTO auth_JKL SELECT * FROM auth where name like "l%";
INSERT INTO auth_MNO SELECT * FROM auth where name like "m%";
INSERT INTO auth_MNO SELECT * FROM auth where name like "n%";
INSERT INTO auth_MNO SELECT * FROM auth where name like "o%";
INSERT INTO auth_PQR SELECT * FROM auth where name like "p%";
INSERT INTO auth_PQR SELECT * FROM auth where name like "q%";
INSERT INTO auth_PQR SELECT * FROM auth where name like "r%";
INSERT INTO auth_STU SELECT * FROM auth where name like "s%";
INSERT INTO auth_STU SELECT * FROM auth where name like "t%";
INSERT INTO auth_STU SELECT * FROM auth where name like "u%";
INSERT INTO auth_VWX SELECT * FROM auth where name like "v%";
INSERT INTO auth_VWX SELECT * FROM auth where name like "w%";
INSERT INTO auth_VWX SELECT * FROM auth where name like "x%";
INSERT INTO auth_YZ SELECT * FROM auth where name like "y%";
INSERT INTO auth_YZ SELECT * FROM auth where name like "z%";
INSERT INTO auth_09 SELECT * FROM auth where name like "0%";
INSERT INTO auth_09 SELECT * FROM auth where name like "1%";
INSERT INTO auth_09 SELECT * FROM auth where name like "2%";
INSERT INTO auth_09 SELECT * FROM auth where name like "3%";
INSERT INTO auth_09 SELECT * FROM auth where name like "4%";
INSERT INTO auth_09 SELECT * FROM auth where name like "5%";
INSERT INTO auth_09 SELECT * FROM auth where name like "6%";
INSERT INTO auth_09 SELECT * FROM auth where name like "7%";
INSERT INTO auth_09 SELECT * FROM auth where name like "8%";
INSERT INTO auth_09 SELECT * FROM auth where name like "9%";

DELETE FROM auth WHERE name LIKE "a%";
DELETE FROM auth WHERE name LIKE "b%";
DELETE FROM auth WHERE name LIKE "c%";
DELETE FROM auth WHERE name LIKE "d%";
DELETE FROM auth WHERE name LIKE "e%";
DELETE FROM auth WHERE name LIKE "f%";
DELETE FROM auth WHERE name LIKE "g%";
DELETE FROM auth WHERE name LIKE "h%";
DELETE FROM auth WHERE name LIKE "i%";
DELETE FROM auth WHERE name LIKE "j%";
DELETE FROM auth WHERE name LIKE "k%";
DELETE FROM auth WHERE name LIKE "l%";
DELETE FROM auth WHERE name LIKE "m%";
DELETE FROM auth WHERE name LIKE "n%";
DELETE FROM auth WHERE name LIKE "o%";
DELETE FROM auth WHERE name LIKE "p%";
DELETE FROM auth WHERE name LIKE "q%";
DELETE FROM auth WHERE name LIKE "r%";
DELETE FROM auth WHERE name LIKE "s%";
DELETE FROM auth WHERE name LIKE "t%";
DELETE FROM auth WHERE name LIKE "u%";
DELETE FROM auth WHERE name LIKE "v%";
DELETE FROM auth WHERE name LIKE "w%";
DELETE FROM auth WHERE name LIKE "x%";
DELETE FROM auth WHERE name LIKE "y%";
DELETE FROM auth WHERE name LIKE "z%";
DELETE FROM auth WHERE name LIKE "0%";
DELETE FROM auth WHERE name LIKE "1%";
DELETE FROM auth WHERE name LIKE "2%";
DELETE FROM auth WHERE name LIKE "3%";
DELETE FROM auth WHERE name LIKE "4%";
DELETE FROM auth WHERE name LIKE "5%";
DELETE FROM auth WHERE name LIKE "6%";
DELETE FROM auth WHERE name LIKE "7%";
DELETE FROM auth WHERE name LIKE "8%";
DELETE FROM auth WHERE name LIKE "9%";

INSERT INTO auth_MISC SELECT * FROM auth;

DROP TABLE auth;

COMMIT;

PRAGMA foreign_keys=on;

VACUUM;
