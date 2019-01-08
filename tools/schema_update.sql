PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

ALTER TABLE auth RENAME TO auth_temp;
CREATE TABLE IF NOT EXISTS auth (name VARCHAR (32) PRIMARY KEY ON CONFLICT IGNORE, password VARCHAR (512), privileges VARCHAR (512), last_login INTEGER);
INSERT INTO auth SELECT name, password, privileges, last_login FROM auth_temp;
DROP TABLE auth_temp;

DROP TABLE _s;
CREATE TABLE _s (import BOOLEAN, db_version VARCHAR (6));
INSERT INTO _s VALUES ('true', '1.1');

COMMIT;
 
PRAGMA foreign_keys=on;

VACUUM;
