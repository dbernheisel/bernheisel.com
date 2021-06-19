%{
  title: "Guide to safe Ecto Migrations",
  tags: ["elixir"],
  description: """
  Not all migrations should be run equally! There are some migrations that may
  require multiple deployments in order to avoid database and application
  issues. Let's look at some scenarios and consider how to avoid traps.
  """
}
---

# Table of Contents

- How to migrate Mix Release projects
- How to check for locks in a query
- Basics of an Ecto migration
- Safeguards in the database
- Scenarios
  - Removing a column
  - Adding a column with a default value
  - Backfilling data
  - Changing a column type
  - Renaming a column
  - Renaming a table
  - Adding a check constraint
  - Setting `NOT NULL` on an existing column
  - (Postgres) Adding an index
  - (Postgres) Adding a reference or foreign key
  - (Postgres) Adding a JSON column
- References

---

# How do I migrate my Mix Release projects?

TODO

See also:

- https://hexdocs.pm/ecto_sql/Ecto.Migrator.html
- https://hexdocs.pm/phoenix/releases.html

# How to check for locks in a query

```sql
BEGIN;

-- Put your actions in here. For example, validating a constraint
ALTER TABLE addresses VALIDATE CONSTRAINT "my_table_locking_constraint";

SELECT locktype, relation::regclass, mode, transactionid AS tid, virtualtransaction AS vtid, pid, granted FROM pg_locks;
COMMIT;
```


# Basics of an Ecto migration





# Safeguards in the database

TODO

## Statement Timeout

> Abort any statement that takes more than the specified amount of time. If
> log_min_error_statement is set to ERROR or lower, the statement that timed out
> will also be logged. If this value is specified without units, it is taken as
> milliseconds. A value of zero (the default) disables the timeout.
>
> The timeout is measured from the time a command arrives at the server until it
> is completed by the server. If multiple SQL statements appear in a single
> simple-Query message, the timeout is applied to each statement separately.
> (PostgreSQL versions before 13 usually treated the timeout as applying to the
> whole query string.) In extended query protocol, the timeout starts running
> when any query-related message (Parse, Bind, Execute, Describe) arrives, and
> it is canceled by completion of an Execute or Sync message.

```sql
ALTER ROLE myuser SET statement_timeout = '1h';
```

## Lock Timeout

> Abort any statement that waits longer than the specified amount of time while
> attempting to acquire a lock on a table, index, row, or other database object.
> The time limit applies separately to each lock acquisition attempt. The limit
> applies both to explicit locking requests (such as LOCK TABLE, or SELECT FOR
> UPDATE without NOWAIT) and to implicitly-acquired locks. If this value is
> specified without units, it is taken as milliseconds. A value of zero (the
> default) disables the timeout.
>
> Unlike statement_timeout, this timeout can only occur while waiting for locks.
> Note that if statement_timeout is nonzero, it is rather pointless to set
> lock_timeout to the same or larger value, since the statement timeout would
> always trigger first. If log_min_error_statement is set to ERROR or lower, the
> statement that timed out will be logged.

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
```

Or, at the migration level, you could use an [Ecto migration transaction
callback] [`after_begin`](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#c:after_begin/0)
to specify lock timeouts to protect the application from runaway locks.

```elixir
def after_begin() do
  repo().query!(
    "SET lock_timeout TO '5s'",  # migrate up
    "SET lock_timeout TO '10s'"  # migrate down
  )
end
```

Another callback is [`before_commit`](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#c:before_commit/0)

[Ecto migration transaction callbacks]: https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-transaction-callbacks

# Removing a column

If Ecto is still configured to read a column, then queries will fail when
loading data into your structs.

## BAD

```elixir
def change
  alter table("posts") do
    remove :no_longer_needed_column
  end
end
```

## GOOD

1. Deploy change to application to remove field from Ecto schema.
2. Deploy migration and run it.

Deploy 1

```diff
schema "posts" do
- column :no_longer_needed_column, :text
end
```

Deploy 2

```elixir
def change
  alter table("posts") do
    remove :no_longer_needed_column
  end
end
```


# Adding a column with a default value

Adding a column with a default value to an existing table causes the table to be
rewritten. During this time, reads and writes are blocked in Postgres, and
writes are blocked in MySQL and MariaDB.

## BAD

Safe in Postgres 11+, MySQL 8.0.12+, MariaDB 10.3.2+

```elixir
def change do
  alter table("comments") do
    add :approved, :boolean, default: false
  end
end
```

## GOOD

```elixir
def change do
  alter table("comments") do
    add :approved, :boolean
  end

  flush()

  alter table("comments") do
    modify :approved, :boolean, default: false
  end
end
```


# Backfilling data

Ecto will create a transaction around each migration, and backfilling in the
same transaction that alters a table keeps the table locked for the duration of
the backfill.

Also, running a single query to update data can cause issues for large tables.

See also:
- https://dashbit.co/blog/automatic-and-manual-ecto-migrations

## BAD

```elixir
import Ecto.Query

def change do
  alter table("posts") do
    add :new_data, :text
  end

  flush()

  MyApp.MySchema
  |> where(new_data: nil)
  |> MyApp.Repo.update_all(set: [new_data: "some data"])
end
```

The referenced `MySchema` is defined in application code, which may change over
time. However, migrations are a snapshot of your app at the time it's written.
In the future, assumptions in query may no longer be true; for example some
fields may not be present anymore causing the query to fail.

Additionally, in your development environment, you might have 10 records to
migrate; in staging, you might have 100; in production, you might have 10
billion to migrate. Batching and throttling may be necessary.

## GOOD

There are three keys to backfilling safely:

  1. batching
  2. throttling
  3. running it outside a transaction

Here are two options for "snapshotting" your schema at the time of the
migration:

  1. Execute pure SQL that represents the table at that moment.
  2. Write a small Ecto schema in the migration that only involves what you
     need, and use that in your data migration.

TODO: (example)


# Changing the type of a column

Changing the type of a column causes the table to be rewritten. During this
time, reads and writes are blocked in Postgres, and writes are blocked in MySQL
and MariaDB.

## BAD

Safe in Postgres:

- increasing length on `varchar` or removing the limit
- changing `varchar` to `text`
- changing `text` to `varchar` with no length limit
- increasing precision of `decimal` or `numeric` columns
- changing `decimal` or `numeric` to be unconstrained
- changing `timestamp` to `timestamptz` when session TZ is UTC (Postgres 12+)

Safe in MySQL/MariaDB:

- increasing length of `varchar` from < 255 up to 255.
- increasing length of `varchar` from > 255 up to max.

```elixir
def change do
  alter table("posts") do
    modify :my_column, :boolean, :text
  end
end
```

## GOOD

Multi deployment strategy:

1. Create a new column
2. In application code, write to both columns
3. Backfill data from old column to new column
4. In application code, move reads from old column to the new column
5. In application code, remove old column from Ecto schemas.
6. Drop the old column.

TODO: (example)


# Renaming a column

The time between when application starts and the migration actually runs will
cause errors in your application. Either the application will think the new name
is in effect, or the migration will run first and the application will still be
looking for the old name.

## BAD

```elixir
def change do
  rename table("posts"), :title, to: :summary
end
```

## GOOD

1. Create a new column
2. In application code, write to both columns
3. [Backfill data] from old column to new column
4. In application code, move reads from old column to the new column
5. In application code, remove old column from Ecto schemas.
6. Drop the old column.

TODO: (example)

[Backfill data]: #backfilling-data


# Renaming a table

The time between when application starts and the migration actually runs will
cause errors in your application. Either the application will think the new name
is in effect, or the migration will run first and the application will still be
looking for the old name.

## BAD

```elixir
def change do
  rename table("posts"), to: table("articles")
end
```

## GOOD

1. Create the new table.
  - This should include creating new constraints (checks and foreign keys) that
    mimic behavior of the old table.
2. In application code, write to both tables
3. [Backfill data] from old table to new table
4. In application code, move reads from old table to the new table
5. In application code, remove old table from Ecto schemas.
6. Drop the old table.

TODO: (example)

[Backfill data]: #backfilling-data


# Adding a check constraint

Adding a check constraint blocks reads and writes to the table in Postgres, and
blocks writes in MySQL/MariaDB while every row is checked.

## BAD

```elixir
def change do
  create constraint("products", :price_must_be_positive, check: "price > 0")
end
```

## GOOD (Postgres)

In one migration:

```elixir
def change do
  create constraint("products", :price_must_be_positive, check: "price > 0"), validate: false
end
```

In the next migration:

```elixir
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive", ""
end
```


# Setting `NOT NULL` on an existing column

Setting NOT NULL on an existing column blocks reads and writes while every row
is checked.

## BAD

```elixir
def change do
  alter table("products") do
    modify :active, :boolean, null: false
  end
end
```

## GOOD

Add a check constraint without validating it, then validate it. This is
functionally equivalent.

In one migration:

```elixir
def change do
  create constraint("products", :active_not_null, check: "active IS NOT NULL"), validate: false
end
```

In next migration:

```elixir
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT active_not_null", ""
end
```

If you're using Postgres 12+, you can add the `NOT NULL` to the column after
validating the constraint.

```elixir
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT active_not_null", ""

  alter table("products") do
    modify :active, :boolean, null: false
  end

  drop constraint("products", :active_not_null)
end
```

If your constraint fails, then you should consider [backfilling data] first to
cover the gaps in your desired data integrity, then revisit validating the
constraint.

[backfilling data]: #backfilling-data

# Adding an index (Postgres)

## BAD

```elixir
def change do
  create index("posts", [:slug])
end
```

## GOOD

```elixir
@disable_ddl_transaction true
@disable_migration_lock true

def change do
  create index("posts", [:slug], concurrently: true)
end
```


# Adding a reference or foreign key (Postgres)

Adding a foreign key blocks writes on both tables.

## BAD

```elixir
def change do
  alter table("posts") do
    add :group_id, references("groups")
  end
end
```

## GOOD

In one migration

```elixir
def change do
  alter table("posts") do
    add :group_id, references("groups", validate: false)
  end
end
```

In the next migration

```elixir
def change do
  execute "ALTER TABLE posts VALIDATE CONSTRAINT group_id_fkey", ""
end
```

# Adding a JSON column (Postgres)

In Postgres, there's no equality operator for the `json` column type, which can
cause errors for existing `SELECT DISTINCT` queries in your application.

## BAD

```elixir
def change do
  alter table("posts") do
    add :extra_data, :json
  end
end
```

## GOOD

Use `jsonb` instead.

```elixir
def change do
  alter table("posts") do
    add :extra_data, :jsonb
  end
end
```

# References

Before you think this is a completely original article, I want you to know that
I took a lot of inspiration from Andrew Kane and his library
[strong_migrations](https://github.com/ankane/strong_migrations). Think of this
as a port of his guide to Elixir and Ecto.

[PostgreSQL at Scale by James Coleman](https://medium.com/braintree-product-technology/postgresql-at-scale-database-schema-changes-without-downtime-20d3749ed680)

[Strong Migrations by Andrew Kane](https://github.com/ankane/strong_migrations)

[Adding a NOT NULL CONSTRAINT on PG Faster with Minimal Locking](https://medium.com/doctolib/adding-a-not-null-constraint-on-pg-faster-with-minimal-locking-38b2c00c4d1c)

[Postgres Runtime Configuration](https://www.postgresql.org/docs/current/runtime-config-client.html)
