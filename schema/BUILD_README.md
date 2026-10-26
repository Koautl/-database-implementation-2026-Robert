# Hair Fix Salon database build

This folder contains the MySQL 8 schema for the Hair Fix Salon appointment
booking project. `build.sh` assembles the component SQL files in dependency
order and can execute the resulting build while saving a timestamped log.

## Warning

This is a destructive development build. `tables.sql` begins with
`DROP SCHEMA IF EXISTS hair_fix_salon`, so a complete run deletes and recreates
the database. Do not run it against data that must be preserved.

## Requirements

- MySQL Server 8.x and the MySQL 8 command-line client, or MySQL Workbench 8.x
- An administrative MySQL account that may create schemas, routines, triggers,
  users, roles, and grants
- Bash when using `build.sh`

This build targets MySQL 8 and is not intended for MariaDB.

## Ordered build sequence

| Order | File | Purpose |
|---:|---|---|
| 1 | `tables.sql` | Recreate the schema and create the 14 InnoDB tables |
| 2 | `keys.sql` | Add unique and foreign-key constraints |
| 3 | `checks.sql` | Add domain and validation checks |
| 4 | `indexes.sql` | Add workload-oriented indexes |
| 5 | `views.sql` | Create the seven reporting/query views |
| 6 | `procedures.sql` | Create the locked definer, functions, and procedures |
| 7 | `sample_data.sql` | Load repeatable demonstration data in a transaction |
| 8 | `triggers.sql` | Add final-state and immutable-history protection |
| 9 | `security.sql` | Create database roles and apply least-privilege grants |
| 10 | `verify.sql` | Check required objects and sample-data consistency |

The order matters. In particular, `procedures.sql` creates the locked definer
used by the triggers, and the procedures must exist before `security.sql`
grants permission to execute them.

## Assemble without changing a database

From the repository's `schema` directory:

```bash
chmod +x build.sh
./build.sh --assemble-only
```

This recreates `Hair_Fix_Salon_Full_Build.sql` but does not connect to MySQL.
Edit the component files and rerun the command whenever the schema changes.

## Build from the command line

```bash
./build.sh --execute -u root -p
```

The client prompts for the password. Never put a database password in this
repository or directly in the script. A configured login path may also be used:

```bash
./build.sh --execute --login-path=hairfix
```

The command returns a nonzero status if assembly, SQL execution, or verification
fails. MySQL output is written to `schema/logs/build_YYYYMMDD_HHMMSS.log`.

