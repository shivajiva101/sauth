PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

CREATE TABLE IF NOT EXISTS auth (name VARCHAR(32) PRIMARY KEY ON CONFLICT IGNORE, password VARCHAR(512), privileges VARCHAR(512), last_login INTEGER);

INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_ABC;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_DEF;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_GHI;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_JKL;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_MNO;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_PQR;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_STU;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_VWX;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_YZ;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_09;
INSERT INTO auth (name, password, privileges, last_login) SELECT name, password, privileges, last_login FROM auth_MISC;

DROP TABLE auth_ABC;
DROP TABLE auth_DEF;
DROP TABLE auth_GHI;
DROP TABLE auth_JKL;
DROP TABLE auth_MNO;
DROP TABLE auth_PQR;
DROP TABLE auth_STU;
DROP TABLE auth_VWX;
DROP TABLE auth_YZ;
DROP TABLE auth_09;
DROP TABLE auth_MISC;

DROP TABLE _s;
CREATE TABLE _s (import BOOLEAN, db_version VARCHAR (6));
INSERT INTO _s VALUES ('true', '1.1');
                                                     
COMMIT;

PRAGMA foreign_keys=on;

VACUUM;
