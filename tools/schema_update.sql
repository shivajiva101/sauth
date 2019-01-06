PRAGMA foreign_keys=off;

BEGIN TRANSACTION;

ALTER TABLE auth RENAME auth_temp;
CREATE TABLE IF NOT EXISTS auth (name VARCHAR (32) PRIMARY KEY ON CONFLICT IGNORE, password VARCHAR (512), privileges VARCHAR (512), last_login INTEGER);
INSERT INTO auth SELECT name, password, privileges, last_login FROM auth_temp;
DROP TABLE auth_temp;
 
COMMIT;
 
PRAGMA foreign_keys=on;

VACUUM;
