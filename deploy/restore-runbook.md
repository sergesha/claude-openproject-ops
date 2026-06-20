# Restore runbook (and rehearsal)

Restore must use the **same format** the backup was taken in. The canonical format is a logical
`pg_dump -Fc` (custom format) plus an assets tarball — see
`skills/openproject-devops/SKILL.md` → *Backup / restore*.

> Conventions below: `$C` = your `docker compose` invocation from the compose dir; `<ts>` = the
> backup timestamp; the DB service is `db`, app services are `web` + `worker`. No instance-specific
> hosts/ports/credentials appear here by design.

## Full restore (destructive — maintenance window)

```bash
# 1. stop the app (keep the DB up)
$C stop web worker

# 2. recreate the database
$C exec -T db dropdb -U postgres --if-exists openproject
$C exec -T db createdb -U postgres openproject

# 3. load the logical dump
$C exec -T db pg_restore -U postgres -d openproject --clean --if-exists < backup/op-<ts>.dump

# 4. restore assets
tar xzf backup/assets-<ts>.tar.gz -C /var/openproject

# 5. bring the app back
$C up -d
```

If your backup is instead the overlay's raw `$PGDATA` tar, do **not** use the steps above: stop
Postgres and extract the tar back over the data directory volume, then start.

## Non-destructive rehearsal (run this regularly; safe on a live box)

Proves the dump restores cleanly **without touching the live `openproject` database** — it loads
into a throwaway DB and compares row counts, then drops it.

```bash
# take/locate a dump, then:
$C exec -T db dropdb -U postgres --if-exists op_restore_test
$C exec -T db createdb -U postgres op_restore_test
$C exec -T db pg_restore -U postgres -d op_restore_test --clean --if-exists < backup/op-<ts>.dump

# parity check: counts in the restored copy should match the live DB
for t in work_packages projects users; do
  live=$($C exec -T db psql -U postgres -tAc "select count(*) from $t" openproject)
  rest=$($C exec -T db psql -U postgres -tAc "select count(*) from $t" op_restore_test)
  echo "$t live=$live restored=$rest $([ "$live" = "$rest" ] && echo OK || echo MISMATCH)"
done

# clean up the scratch DB
$C exec -T db dropdb -U postgres --if-exists op_restore_test
```

A green rehearsal (all `OK`) is the only thing that lets you trust a backup. Run it after the
first backup and before every upgrade.
