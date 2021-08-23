%{
  title: "Guide to Safe Ecto Migrations",
  tags: ["elixir"],
  published: false,
  discussion_url: "https://github.com/dbernheisel/bernheisel.com/discussions/11",
  description: """
  Not all migrations should be run equally! There are some migrations that may
  require multiple deployments in order to avoid database and application
  issues. Let's look at some scenarios and consider how to avoid traps.
  """
}
---

# Table of Contents

- [PART 1 - Anatomy of an Ecto migration](#anatomy-of-an-ecto-migration)
  - [Inspect SQL](#inspect-sql)
  - [Migration Options](#migration-options)
  - [How to inspect locks in a query](#how-to-inspect-locks-in-a-query)
  - [Safeguards in the database](#safeguards-in-the-database)
- [PART 2 - How to migrate Mix Release projects](#how-to-migrate-mix-release-projects)
  - [Create Release module](#create-release-module)
  - [Assemble the release](#assemble-release)
  - [Check migration status](#check-migration-status)
  - [Run the migration](#run-the-migration)
  - [Rollback migrations](#rollback-migrations)
- [PART 3 - Scenarios](#scenarios)
  - [Adding an index](#adding-an-index)
  - [Adding a reference or foreign key](#adding-a-reference-or-foreign-key)
  - [Adding a column with a default value](#adding-a-column-with-a-default-value)
  - [Changing a column type](#changing-a-column-type)
  - [Removing a column](#removing-a-column)
  - [Renaming a column](#renaming-a-column)
  - [Renaming a table](#renaming-a-table)
  - [Adding a check constraint](#adding-a-check-constraint)
  - [Setting `NOT NULL` on an existing column](#setting-not-null-on-an-existing-column)
  - [Adding a JSON column](#adding-a-json-column)
- [PART 4 - Backfilling data](#backfilling-data)
  - [Throttling deterministic set of data](#throttling-deterministic-data)
  - [Throttling arbitrary set of data](#throttling-arbitrary-data)
- [References](#references)
- [Reference Material](#reference-material)

---

<a name="part-1"></a>

> This is a 4-part series:
>
> - [Part 1 - Anatomy of an Ecto migration](#part-1) (You are here)
> - [Part 2 - How to migrate Mix Release projects](#how-to-migrate-mix-release-projects)
> - [Part 3 - Migration Scenarios](#scenarios)
> - [Part 4 - Backfilling Data](#backfilling-data)

Not long ago, deploying and managing Elixir projects was not as straight-forward
as we can enjoy today; some would say it was downright painful. Thankfully,
since Elixir 1.9, Mix now ships with tools to help us developers assemble
applications for deployment. How you get that binary to its destination it still
entirely up to you, but now it's a simpler and common task!

Before the wider adoption of pre-compiled releases (thanks to [Mix Release] and
before Mix was [Distillery]), it was more common to install Elixir (and
therefore mix), copy your code, and use `mix` to start your application _on the
target servers_. Along with starting your application, another common operation
is to create and migrate databases. Push your code, run `mix ecto.migrate && mix
phx.server` and you're done! Just like you would in development and tests.

However, now that it's more common to run compiled Mix releases, which implies
that your application cannot rely on the `Mix` module being present and no
longer need the `mix` binary on the target server, developers need another way
to manage the application's database.

This guide should help you:

1. Understand an Ecto migration
1. Migrate and rollback the database using Mix releases
1. Avoid pitfalls during migrations

Note: This guide uses **Postgres** and may differ if you're using a different
database. I'll note where differences may be, but I do not go into depth on
different database systems. This was also written using **Ecto 3.6.x**.

Ok! Let's go

![Ready for an adventure](/images/ready-for-an-adventure.gif)

[Mix Release]: https://hexdocs.pm/mix/1.9.0/Mix.Release.html
[Distillery]: https://hexdocs.pm/distillery


<a name="anatomy-of-an-ecto-migration"></a>
# PART 1 - Anatomy of an Ecto migration

To generate a migration, we'll use `mix ecto.gen.migration`.

> **Tip** If you're using Phoenix, you might consider `mix phx.gen.schema` which
> will generate a migration and also allows you to pass in fields and types. See
> `mix help phx.gen.schema` for more information.

```shell
mix ecto.gen.migration create_test_table
```

This command will generate a file in `priv/repo/migrations` given the repo name
of `Repo`. If you named it `OtherRepo` the file would be in
`priv/other_repo/migrations`.

Let's look at that file:

```elixir
defmodule MyApp.Repo.Migrations.CreateTestTable do
  use Ecto.Migration

  def change do

  end
end
```

Let's make some changes; how about create a table about tracking weather?

```elixir
defmodule MyApp.Repo.Migrations.CreateTestTable do
  use Ecto.Migration

  def change do
    create table("test") do
      add :city,    :string, size: 40
      add :temp_lo, :integer
      add :temp_hi, :integer
      add :prcp,    :float

      timestamps()
    end
  end
end
```

Now that we have a migration, let's run it! Run `mix ecto.migrate`.

```shell
❯ mix ecto.migrate
21:26:18.992 [info]  == Running 20210702012346 MyApp.Repo.Migrations.CreateTestTable.change/0 forward
21:26:18.994 [info]  create table test
21:26:19.004 [info]  == Migrated 20210702012346 in 0.0s
```

<a name="inspect-sql"></a>
## Inspect SQL

We really want to see the SQL that runs though, so let's zoom in on the
migration. By default, Ecto will not log the raw SQL. First, I'll rollback, and
then re-migrate but with an additional flag `--log-sql` so we can see what
actually runs.

```shell
❯ mix ecto.rollback
21:29:32.287 [info]  == Running 20210702012346 MyApp.Repo.Migrations.CreateTestTable.change/0 backward
21:29:32.289 [info]  drop table test
21:29:32.292 [info]  == Migrated 20210702012346 in 0.0s

❯ mix ecto.migrate --log-sql
21:29:36.461 [info]  == Running 20210702012346 MyApp.Repo.Migrations.CreateTestTable.change/0 forward
21:29:36.462 [info]  create table test
21:29:36.466 [debug] QUERY OK db=3.2ms
CREATE TABLE "test" ("id" bigserial, "city" varchar(40), "temp_lo" integer, "temp_hi" integer, "prcp" float, "inserted_at" timestamp(0) NOT NULL, "updated_at" timestamp(0) NOT NULL, PRIMARY KEY ("id")) []
21:29:36.467 [info]  == Migrated 20210702012346 in 0.0s
```

Ecto is cheating the logs a bit here; yes, we do see the raw SQL for _our own
changes_, but we're not seeing the SQL that Ecto is running for the entire
migration. We're missing the SQL that are specific to the adapter. To get these
missing logs, I'll set Postgres to log everything and then tail the Postgres
logs and re-run the migration:

```
LOG:  statement: BEGIN
LOG:  execute <unnamed>: LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE
LOG:  execute ecto_3: SELECT s0."version"::bigint FROM "schema_migrations" AS s0
LOG:  statement: BEGIN
LOG:  execute <unnamed>: CREATE TABLE "weather" ("id" bigserial, "city" varchar(40), "temp_lo" integer, "temp_hi" integer, "prcp" float, "inserted_at" timestamp(0) NOT NULL, "updated_at" timestamp(0) NOT NULL, PRIMARY KEY ("id"))
LOG:  execute ecto_insert_schema_migrations: INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2)
DETAIL:  parameters: $1 = '20210718204657', $2 = '2021-07-18 20:53:49'
LOG:  statement: COMMIT
LOG:  statement: COMMIT
```

As you can see, Ecto will actually run the migration wrapped in a transaction in
Postgres. This part is unlogged by Ecto, so we'll have to reference the code or
the Postgres logs.

Let's trace the code: when running migrations, Ecto will travel through these
functions:
  - [Ecto.Migrator.run/4](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/migrator.ex#L384)
  - [Ecto.Migrator.lock_for_migrations/4](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/migrator.ex#L464)
  - [The adapter's lock_for_migrations implementation](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/adapters/postgres.ex#L207)
  - [Wrapped in another transaction](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/adapters/postgres.ex#L217)

Inside the transaction, the Ecto Postgres adapter is also obtaining a `SHARE
UPDATE EXCLUSIVE` lock of the "schema_migrations" table.

**Why this lock is important**: Elixir excels at distributed deployments, which
means there could be multiple nodes connected to the same database. These nodes
may also try to migrate the database all at the same time! Ecto leverages this
`SHARE UPDATE EXCLUSIVE` lock as a way to ensure that only one node is running a
migration at a time and only once.

This is what the **migration actually looks like**:

```sql
BEGIN;
LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
BEGIN;
CREATE TABLE "test" ("id" bigserial, "city" varchar(40), "temp_lo" integer, "temp_hi" integer, "prcp" float, "inserted_at" timestamp(0) NOT NULL, "updated_at" timestamp(0) NOT NULL, PRIMARY KEY ("id"));
INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ('20210718204657','2021-07-18 20:53:49');
COMMIT;
COMMIT;
```

If the migration fails, the transaction is rolled back and no changes actually
occur in the database. In most scenarios, these are great defaults.

There are also some options we can set in a given Ecto migration. Let's explore
some of those options next.

[Ecto.Migration]: https://hexdocs.pm/ecto_sql/Ecto.Migration.html

<a name="migration-options"></a>
## Migration Options

Usually your migration will have this structure (reminder: this guide is using
Postgres; different adapters will vary):

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
  BEGIN;
    -- after_begin callback
    -- my changes
    -- before_commit callback
    INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
  COMMIT;
COMMIT;
```

`my_changes` refers to the changes you specify in each of your migrations.

**`@disable_migration_lock`**

By default, Ecto will acquire a lock on the "schema_migrations" table during
migration transaction:

```sql
BEGIN;
  -- ↓ THIS LOCK ↓
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE
  BEGIN;
    -- my changes
    INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
  COMMIT;
COMMIT;
```

You want this lock for most migrations because running multiple migrations at
once concurrently could have unpredictable results. To facilitate releasing this
lock, the command is wrapped in a transaction.

However, there are some scenarios where you don't want a lock. We'll explore
these scenarios later on (for example, [backfilling data](#backfilling-data) and
[creating indexes](#adding-an-index)).

You can skip this lock in Ecto by setting the module attribute
`@disable_migration_lock true` in your migration. If the migration lock is
disabled, the migration will look like this:

```sql
BEGIN;
  -- my changes
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
COMMIT;
```

**`@disable_ddl_transaction`**

By default, Ecto will wrap your changes in a transaction:

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE
  -- ↓ THIS TRANSACTION ↓
  BEGIN;
    -- after_begin callback
    -- my changes
    -- before_commit callback
    INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
  COMMIT;
  -- ↑ THIS TRANSACTION ↑
COMMIT;
```

This helps ensure that if failures occur during the migration, it does not leave
your database in an incomplete and confusing state.

There are some scenarios where you may not want a migration to occur inside a
transaction, such as [data migrations] or commands such as `CREATE INDEX
CONCURRENTLY` that can work asynchronously on the database side after you issue
the command and cannot be inside a transaction.

[data migrations]: #backfilling-data

You can disable this transaction by setting the module attribute
`@disable_ddl_transaction true` in your migration. The migration will look like
this:

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE
  -- my changes
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
COMMIT;
```

> **Tip**: For Postgres, when disabling transactions, you'll **also want to
> disable the migration lock** since that uses yet another transaction. When
> running these migrations in a multi-node environment, you'll need a process to
> ensure these migrations are only kicked-off once since there is no protection
> against multiple nodes running the same migration at the same exact time.

Disabling both the migration lock and the DDL transaction, your migration will
be pretty simple:

```sql
-- my changes
INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
```

**Transaction Callbacks**

In the examples above, you'll notice there are `after_begin` and `before_commit`
hooks if the migration is occurring within a transaction:

```sql
BEGIN;
  -- after_begin hook  ← THIS HOOK
  -- my changes
  -- before_commit hook  ← AND THIS HOOK
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
COMMIT;
```

You can use these hooks by defining `after_begin/0` and `before_commit/0` in
your migration. A good use case for this is setting migration lock timeouts as
safeguards ([see later Safeguards section](#safeguards-in-the-database)).

```elixir
defmodule MyApp.Repo.Migrations.CreateTestTable do
  use Ecto.Migration

  def change do
    # ... my potentially long-locking migration
  end

  def after_begin do
    execute "SET lock_timeout TO '5s'", "SET lock_timeout TO '10s'"
  end
end
```

Be mindful that these callbacks are only called if `@disable_ddl_transaction` is
not set to `true` since it relies on the transaction being present.

<a name="how-to-inspect-locks-in-a-query"></a>
## How to inspect locks in a query

Before we dive into safer practices of migrations, we should equip some
knowledge about how to check if a migration could potentially block your
application. In Postgres, there is a `pg_locks` table that we can query that
will reveal the locks occurring in the system. Let's query that table alongside
our migrations.

```sql
BEGIN;
  -- Put your actions in here. For example, validating a constraint
  ALTER TABLE addresses VALIDATE CONSTRAINT "my_table_locking_constraint";

  -- end your transaction with a SELECT on pg_locks so you can see the locks
  -- that occurred during the transaction
  SELECT locktype, relation::regclass, mode, transactionid AS tid, virtualtransaction AS vtid, pid, granted FROM pg_locks;
COMMIT;
```

The result from this SQL command should return the locks obtained during the
operation. Let's see an example: We'll add a unique index and create the index
naively without concurrency so we can see the locks it obtains:

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
  -- we are going to squash the embedded transaction here for simplicity
  CREATE UNIQUE INDEX IF NOT EXISTS "weather_city_index" ON "weather" ("city");
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ('20210718210952',NOW());
  SELECT locktype, relation::regclass, mode, transactionid AS tid, virtualtransaction AS vtid, pid, granted FROM pg_locks;
COMMIT;

--    locktype    |      relation      |           mode           |  tid   | vtid  | pid | granted
-- ---------------+--------------------+--------------------------+--------+-------+-----+---------
--  relation      | pg_locks           | AccessShareLock          |        | 2/321 | 253 | t
--  relation      | schema_migrations  | RowExclusiveLock         |        | 2/321 | 253 | t
--  virtualxid    |                    | ExclusiveLock            |        | 2/321 | 253 | t
--  relation      | weather_city_index | AccessExclusiveLock      |        | 2/321 | 253 | t
--  relation      | schema_migrations  | ShareUpdateExclusiveLock |        | 2/321 | 253 | t
--  transactionid |                    | ExclusiveLock            | 283863 | 2/321 | 253 | t
--  relation      | weather            | ShareLock                |        | 2/321 | 253 | t
-- (7 rows)
```

Let's go through each of these:

1. `relation | pg_locks | AccessShareLock` - This is us querying the pg_locks
   table in the transaction so we can see which locks are taken. It has the
   weakest lock which only conflicts with `Access Exclusive` which should never
   happen on the internal pg_locks table itself.
1. `relation | schema_migrations | RowExclusiveLock` - This is because we're
   inserting a row into the "schema_migrations" table. Reads are still allowed,
   but mutation on this table is blocked until the transaction is done.
1. `virtualxid | _ | ExlusiveLock` - Querying `pg_locks` created a virtual
   transaction on the SELECT query. We can ignore this.
1. `relation | weather_city_index | AccessExclusiveLock` - We're creating the
   index, so this new index will be completely locked to any reads and writes
   until this transaction is complete.
1. `relation | schema_migrations | ShareUpdateExclusiveLock` - This lock is
   acquired by Ecto to ensure that only one mutable operation is happening on
   the table. This is what allows multiple nodes able to run migrations at the
   same time safely. Other processes can still read the schema_migrations table,
   but you cannot write to it.
1. `transactionid | _ | ExclusiveLock` - This lock is on a transaction that is
   happening; in this case, it has an Exclusive Lock on _itself_; meaning that
   if another transaction occurring at the same time conflicts with this
   transaction, the _other_ transaction will acquire a lock on _this_
   transaction so it knows when it's done. I call this lockception 🙂🤯
1. `relation | weather | ShareLock` - **Finally**, the reason why we're here.
   Remember, we're creating a unique index on the "weather" table naively
   without concurrency. This lock is our red flag 🚩. **You'll see that it is
   acquiring a ShareLock on the table which means that it will block
   writes! It won't be good if we deploy this** if we have processes or web
   requests that regularly write to this table. `UPDATE` `DELETE` and `INSERT`
   acquire a RowExclusiveLock which conflicts with the ShareLock.

To avoid this lock, we'll instead change the command to `CREATE INDEX
CONCURRENTLY ...`; when using `CONCURRENTLY`, it prevents us from using
`BEGIN/COMMIT` transactions which is unfortunate because now we cannot easily
see the locks the command obtains. We know this will be safer because `CREATE
INDEX CONCURRENTLY` acquires a ShareUpdateExclusiveLock which does not conflict
with RowExclusiveLock.

[This scenario](#adding-an-index) is revisited later in [Part 3 - Scenarios](#scenarios).

<a name="safeguards-in-the-database"></a>
## Safeguards in the database

It's a good idea to add safeguards so no developer on the team accidentally
locks up the database for too long. Even if you know all about databases and
locks, you might have a forgetful day and try to add an index non-concurrently
and bring down production. Safeguards are good.

We can add one or several safeguards:

1. Automatically cancel a statement if its lock is held for too long. There are
   two ways to apply this:
  1. Apply to migrations. This can be done with a `lock_timeout` inside a
     transaction.
  2. Apply to any statements. This can be done by setting a `lock_timeout` to a
     Postgres role.
2. Automatically cancel statements that take too long. This is broader than #1
   because it includes _any_ statement, not just locks.

Let's dive into these safeguards.

## Add a `lock_timeout`

One safeguard we can add to migrations is a lock timeout. A lock timeout will
ensure a lock should not last more than `n` seconds. This way, if an unsafe
migration does sneak in, it should only lock tables and their subsequent updates
and writes and possibly reads for `n` seconds instead of indefinitely until the
migration finishes.

From the Postgres docs:

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

There are two ways to apply this lock:

1. localized to the transaction.
1. default for the user/role.

### Transaction `lock_timeout`

In SQL:

```sql
SET lock_timeout to '5s';
```

Let's move that to a [Ecto migration transaction callback](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-transaction-callbacks).

You can set a lock timeout in every migration:

```elixir
def after_begin do
  execute("SET lock_timeout TO '5s'", "SET lock_timeout TO '10s'")
end
```

But this can get tedious, and you'll likely want this for every migration. Let's
write a little macro to help with this boilerplate code.

In every migration, you'll notice that we `use Ecto.Migration` which inserts
some code into your migration. Let's use this same idea to inject boilerplate of
our own and leverage an option to set a lock timeout. We define the
[`after_begin`](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#c:after_begin/0)
callback to set the lock timeout.

```elixir
defmodule MyApp.Migration do
  defmacro __using__(opts) do
    lock_timeout = Keyword.get(opts, :lock_timeout, [up: "5s", down: "10s"])

    quote do
      use Ecto.Migration

      if unquote(lock_timeout) do
        def after_begin do
          execute(
            "SET lock_timeout TO '#{Keyword.fetch!(unquote(lock_timeout), :up)}'",
            "SET lock_timeout TO '#{Keyword.fetch!(unquote(lock_timeout), :down)}'"
          )
        end
      end
    end
  end
end
```

And adjust our migration:

```diff
defmodule MyApp.Repo.Migrations.CreateTestTable do
-  use Ecto.Migration
+  use MyApp.Migration

  def change do
    # my changes
  end
end
```

Now the migrations will only be allowed to acquire locks up to 5 seconds when
migrating up and 10 seconds when rolling back. Remember, these callbacks are
only called when `@disable_ddl_transaction` is not set to `true`.

You can override the lock timeout if needed by setting `use MyApp.Migration,
lock_timeout: false` or change the timeouts `use MyApp.Migration, lock_timeout:
[up: "10s", down: "20s"]`.

### Role-level `lock_timeout`

Alternatively, you can set a lock timeout for the user in all commands:

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
```

If you have a different user that runs migrations, this could be a good option
for that migration-specific Postgres user. The trade-off is that Elixir
developers won't see this timeout as they write migrations and explore the call
stack, versus role settings in the database that developers don't usually
monitor.

## Statement Timeout

Another way to ensure safety is to configure your Postgres database to have
statement timeouts. These timeouts will apply to all statements, including
migrations and the locks they obtain.

From Postgres docs:

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

You can specify this configuration for the Postgres user. For example:

```sql
ALTER ROLE myuser SET statement_timeout = '10m';
```

Now any statement will automatically time out if it runs for more than 10
minutes; opposed to indefinitely running. This could be helpful if you
accidentally run a query that runs the database CPU hot, slowing everything else
down; now that unoptimized query will be limited to 10 minutes or else it will
fail and be canceled.

Setting this `statement_timeout` will require discipline from the team; if there
are runaway queries that fail at (for example) 10 minutes, an exception will
likely occur somewhere. You will want to equip your application with sufficient
logging, tracing, and reporting so you can replicate the query and the
parameters it took to hit the timeout, and ultimately optimize the query.
Without this discipline, you will risk gaining a culture that ignores
exceptions.

---

<a name="how-to-migrate-mix-release-projects"></a>
# PART 2 - How to migrate Mix Release projects

> This is a 4-part series:
>
> - [Part 1 - Anatomy of an Ecto migration](#part-1)
> - [Part 2 - How to migrate Mix Release projects](#how-to-migrate-mix-release-projects) (You are here)
> - [Part 3 - Migration Scenarios](#scenarios)
> - [Part 4 - Backfilling Data](#backfilling-data)

In Mix Release projects, we need to give ourselves easy access to commands to
facilitate migrations. Here's a couple of use cases:

1. Check the status of migrations.
1. Migrate repos up to x migration. Default to the latest migration.
1. Rollback to x migration for a specific Repo.

The common and documented way to encapsulate these commands is with a
`MyApp.Release` module.

<a name="create-release-module"></a>
## Create Release Module

- [Phoenix has examples](https://hexdocs.pm/phoenix/releases.html#ecto-migrations-and-custom-commands)
- [EctoSQL has examples](https://hexdocs.pm/ecto_sql/Ecto.Migrator.html#module-example-running-migrations-in-a-release)

Here is the EctoSQL example:

```elixir
defmodule MyApp.Release do
  @app :my_app

  def migrate do
    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end
end
```

Most of the work is happening in `Ecto.Migrator`, which is great because it
keeps our own code slim and neat. Let's add a little bit to it:

- There isn't a function that prints out the migrations' status. This is helpful
  for sanity checks. You should know what is the _next_ migration is going to be
  before you run migrations.

- In most cases you should only deploy one migration at a time. However in some
  cases, you might have heavy deployment that includes multiple migrations.
  Deployers may only want to execute one at a time so they can monitor them
  separately. Currently, the function does not allow us to only run one
  migration.

- You may need a way to run manual data-oriented migrations.

**Adding options to `MyApp.Release.migrate`**

Let's adjust the `migrate` function to accept options that we can pass into
`Ecto.Migrator`.

```diff
+  @doc """
+  Migrate the database. Defaults to migrating to the latest, `[all: true]`
+  Also accepts `[step: 1]`, or `[to: 20200118045751]`
+  """
-  def migrate do
+  def migrate(opts \\ [all: true]) do
    for repo <- repos() do
-     {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
+     {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, opts))
    end
  end
```

Now we can pass in options to allow us migrate by 1 step or to specific
versions. For example, `migrate(step: 1)` or `migrate(to: 20210719021232)`.

For rolling back, it's most likely a terrible scenario where you don't want to
migrate _all_ possible databases back; therefore you'll want to be more explicit
in this command. You'll require deployers to pass in the specific repo and
version to rollback to.

[See available options](https://hexdocs.pm/ecto_sql/Ecto.Migrator.html#run/4)

**Adding `MyApp.Release.migration_status/0`**

Before I run migrations, I like to check if the application and I both agree
which migration is up next to execute. Locally, you can run `mix
ecto.migrations` to check the status of migrations; I want this same experience
but compatible with deployed releases.

Let's adapt it for Mix Releases:

```elixir
@doc """
Print the migration status for configured Repos' migrations.
"""
def migration_status do
  for repo <- repos(), do: print_migrations_for(repo)
end

defp print_migrations_for(repo) do
  paths = repo_migrations_path(repo)

  {:ok, repo_status, _} =
    Ecto.Migrator.with_repo(repo, &Ecto.Migrator.migrations(&1, paths), mode: :temporary)

  IO.puts(
    """
    Repo: #{inspect(repo)}
      Status    Migration ID    Migration Name
    --------------------------------------------------
    """ <>
      Enum.map_join(repo_status, "\n", fn {status, number, description} ->
        "  #{pad(status, 10)}#{pad(number, 16)}#{description}"
      end) <> "\n"
  )
end

defp repo_migrations_path(repo) do
  config = repo.config()
  priv = config[:priv] || "priv/#{repo |> Module.split() |> List.last() |> Macro.underscore()}"
  config |> Keyword.fetch!(:otp_app) |> Application.app_dir() |> Path.join(priv)
end

defp pad(content, pad) do
  content
  |> to_string
  |> String.pad_trailing(pad)
end
```

A lot of this code is borrowed from the Mix task `mix ecto.migrations`, but
adapted to not require the `Mix` module.

When you run `bin/my_app eval "MyApp.Release.migration_status()"`, this
should be the output:

```
Repo: MyApp.Repo
  Status    Migration ID    Migration Name
--------------------------------------------------
  up        20210718153339  add_test_table1
  down      20210718153341  add_test_table2
```

**Adding an option for data migrations**

Data migrations need to happen separately and trigger manually to ensure that
automatic processes don't try to run on multiple nodes. This is a case where a
singleton in your workflow is necessary 😉. To facilitate data migrations, we're
going to store these migrations in a different folder. When generating a
migration with `mix ecto.gen.migration`, you can use the
`--migrations-path=MY_PATH` flag, eg

```shell
❯ mix ecto.gen.migration --migrations-path=priv/repo/data_migrations backfill_foo
* creating priv/repo/data_migrations
* creating priv/repo/data_migrations/20210811035222_backfill_foo.exs
```

To run these migrations in a Mix Release, we'll need a new function to look in
this custom folder of data migrations.

```elixir
@doc """
Migrate data in the database. Defaults to migrating to the latest, `[all: true]`
Also accepts `[step: 1]`, or `[to: 20200118045751]`
"""
def migrate_data(opts \\ [all: true]) do
  for repo <- repos() do
    path = Ecto.Migrator.migrations_path(repo, "data_migrations")
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, path, :up, opts))
  end
end
```

Now you can manually start data migrations through a Mix Release:

```shell
bin/my_app eval 'MyApp.Release.migrate_data()'
```

If you'd like more inspiration, read [Wojtek Mach's Automatic and Manual Ecto
Migrations](https://dashbit.co/blog/automatic-and-manual-ecto-migrations).

<a name="assemble-the-release"></a>
## Assemble the Release

Now it's time to assemble the release with `mix release`. Great! Done! ...now
what?

...well, it depends on how you're starting the application. Let's ask some
questions:

1. Does the deployed _code_ rely on the migrations already being ran? If so,
   then **no you cannot start your application!** It will crash! The code
   already assumes the database to be in the state after migration. You need to
   run your migrations first and start the application after.

1. Does it contain migrations that aren't yet utilized? For example, you already
   have your database created and `profiles` table created, and you _only have a
   migration_ to add a column to the profiles table but your Ecto schema doesn't
   yet try to load it. **Yes you can go ahead and start your application** since
   the code does not yet rely on that column to exist. Run the migrations at
   your convenience.

1. Do you use Kubernetes? Then you should **consider [Init Containers]**. Init
   containers run to completion _before_ the application containers in the pod.
   This is a perfect opportunity to start your Ecto Repo and migrate it before
   starting the rest of your application. Make sure you exclude data migrations
   from this process however, since those usually will not be safe to
   automatically run in multi-node environments.

[Init Containers]: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/

Now that you've determined which order to start the application or run the
migration, let's start running stuff!

<a name="check-migration-status"></a>
## Check migration status

We can inspect the database migration statuses with `bin/my_app eval
'MyApp.Release.migration_status()'`.

```
Repo: MyApp.Repo
  Status    Migration ID    Migration Name
--------------------------------------------------
  up        20210718153339  add_test_table1
  down      20210718153341  add_test_table2
```

<a name="run-the-migration"></a>
## Run the migration

The database can migrate with `bin/my_app eval 'MyApp.Release.migrate()'`.

When running `bin/my_app eval`, a separate slim instance of the Erlang VM is
started. Your app is loaded _but not started_. Only the Repo is started, and
it's only started with 2 database connections. Since this is a new instance
booting, this implies that it will also need the same environment variables as
your running application. If you rely on environment variables to know which
database to connect to and its credentials, ensure they're present when running
this command.

To run data migrations, run `bin/my_app eval 'MyApp.Release.migrate_data()'`.

<a name="rollback-migrations"></a>
## OMG ROLL IT BACK

Before you roll back, you should consider if there's a safer way to continue
forward and fix the bug. I have never needed to roll back the database

If necessary, the app can rollback with `bin/my_app eval
'MyApp.Release.rollback(MyApp.Repo, 20210709121212)'`

---

<a name="scenarios"></a>
# PART 3 - Scenarios

> This is a 4-part series:
>
> - [Part 1 - Anatomy of an Ecto migration](#part-1)
> - [Part 2 - How to migrate Mix Release projects](#how-to-migrate-mix-release-projects)
> - [Part 3 - Migration Scenarios](#scenarios) (You are here)
> - [Part 4 - Backfilling Data](#backfilling-data)

Here is a non-prescriptive guide on common migration scenarios and how to avoid
trouble.

---

<a name="adding-an-index"></a>
## Adding an index

Creating an index will block both reads and writes. This scenario is used as an
example in the [How to inspect locks in a query
section](#how-to-inspect-locks-in-a-query)

### BAD

```elixir
def change do
  create index("posts", [:slug])

  # This obtains a ShareLock on "posts" which will block writes to the table
end
```

### GOOD

Instead, have Postgres create the index concurrently which does not block reads.
You will need to disable the migration transactions to use `CONCURRENTLY`.

```elixir
@disable_ddl_transaction true
@disable_migration_lock true

def change do
  create index("posts", [:slug], concurrently: true)
end
```

The migration may still take a while in Ecto, but reads and updates to rows will
continue to work. For example, for 100,000,000 rows it took 165 seconds to add
run the migration, but SELECTS and UPDATES could occur while it was running.

---

<a name="adding-a-reference-or-foreign-key"></a>
## Adding a reference or foreign key

Adding a foreign key blocks writes on both tables.

### BAD

```elixir
def change do
  alter table("posts") do
    add :group_id, references("groups")
  end
end
```

### GOOD

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

---

<a name="adding-a-column-with-a-default-value"></a>
## Adding a column with a default value

Adding a column with a default value to an existing table may cause the table to
be rewritten. During this time, reads and writes are blocked in Postgres, and
writes are blocked in MySQL and MariaDB.

### BAD

**Note:** This becomes safe in:

  - [Postgres 11+](https://www.postgresql.org/docs/11/release-11.html),
  - [MySQL 8.0.12+](https://dev.mysql.com/doc/relnotes/mysql/8.0/en/news-8-0-12.html),
  - [MariaDB 10.3.2+](https://mariadb.com/kb/en/instant-add-column-for-innodb/)

```elixir
def change do
  alter table("comments") do
    add :approved, :boolean, default: false
    # This took 34 seconds on my machine for 10 million rows with no fkeys,
    # This took 10 minutes on my machine for 100 million rows with no fkeys,

    # Obtained an AccessExclusiveLock on the table, which blocks reads and
    # writes.
  end
end
```

### GOOD

Add the column first, then alter it to include the default.

First migration:

```elixir
def change do
  alter table("comments") do
    add :approved, :boolean
    # This took 0.27 milliseconds for 100 million rows with no fkeys,
  end
end
```

Second migration:

```elixir
def change do
  alter table("comments") do
    modify :approved, :boolean, default: false
    # This took 0.28 milliseconds for 100 million rows with no fkeys,
  end
end
```

Schema change to read the new column:

```diff
schema "comments" do
+ field :approved, :boolean, default: false
end
```

---

<a name="changing-the-type-of-a-column"></a>
## Changing the type of a column

Changing the type of a column may cause the table to be rewritten. During this
time, reads and writes are blocked in Postgres, and writes are blocked in MySQL
and MariaDB.

### BAD

Safe in Postgres:

- increasing length on `varchar` or removing the limit
- changing `varchar` to `text`
- changing `text` to `varchar` with no length limit
- [Postgres 9.2+](https://www.postgresql.org/docs/9.2/release-9-2.html) - increasing precision (NOTE: not scale) of `decimal` or `numeric` columns. eg, increasing 8,2 to 10,2 is safe. Increasing 8,2 to 8,4 is **not safe**.
- [Postgres 9.2+](https://www.postgresql.org/docs/9.2/release-9-2.html) - changing `decimal` or `numeric` to be unconstrained
- [Postgres 12+](https://www.postgresql.org/docs/release/12.0/) - changing `timestamp` to `timestamptz` when session TZ is UTC

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

### GOOD

Multi deployment strategy:

1. Create a new column
2. In application code, write to both columns
3. [Backfill data] from old column to new column
4. In application code, move reads from old column to the new column
5. In application code, remove old column from Ecto schemas.
6. Drop the old column.

[Backfill data]: #backfilling-data

---

<a name="removing-a-column"></a>
## Removing a column

If Ecto is still configured to read a column in any running instances of the
application, then queries will fail when loading data into your structs. This
can happen in multi-node deployments or if you start the application before
running migrations.

### BAD

```elixir
# Without a code change to the Ecto Schema

def change
  alter table("posts") do
    remove :no_longer_needed_column

    # Obtained an AccessExclusiveLock on the table, which blocks reads and
    # writes, but was instantaneous.
  end
end
```

### GOOD

Safety can be assured if the application code is first updated to remove
references to the column so it's no longer loaded or queried. Then, the column
can safely be removed from the table.

**Strategy 1:**

If your deployment process must run migrations before starting the application,
this means you need a 2-deploy strategy:

1. Deploy code change to remove references the field.
1. Deploy migration change to remove the column.
1. Run the migration to remove the column.

**Strategy 2:**

1. Deploy change to application to remove field from Ecto schema.
1. Start the application. No instances of the app should remain with code
   references to the column about to be removed.
1. Run migration to remove the column from the database.

```diff
# In the Ecto schema

defmodule MyApp.Post do
  schema "posts" do
-   column :no_longer_needed_column, :text
  end
end
```

```elixir
# In the migration

def change
  alter table("posts") do
    remove :no_longer_needed_column
  end
end
```

---

<a name="renaming-a-column"></a>
## Renaming a column

Ask yourself: "Do I _really_ need to rename a column?". Probably not, but if you
must, read on and be aware it requires time and effort.

If Ecto is still configured to read a column in any running instances of the
application, then queries will fail when loading data into your structs. This
can happen in multi-node deployments or if you start the application before
running migrations.

### BAD

```elixir
# In your schema

schema "posts" do
  field :summary, :text
end

# In your migration

def change do
  rename table("posts"), :title, to: :summary
end
```

### GOOD

1. Create a new column
2. In application code, write to both columns
3. [Backfill data] from old column to new column
4. In application code, move reads from old column to the new column
5. In application code, remove old column from Ecto schemas.
6. Drop the old column.

[Backfill data]: #backfilling-data

---

<a name="renaming-a-table"></a>
## Renaming a table

Ask yourself: "Do I _really_ need to rename a table?". Probably not, but if you
must, read on and be aware it requires time and effort.

If Ecto is still configured to read a table in any running instances of the
application, then queries will fail when loading data into your structs. This
can happen in multi-node deployments or if you start the application before
running migrations.

### BAD

```elixir
def change do
  rename table("posts"), to: table("articles")
end
```

### GOOD

1. Create the new table. This should include creating new constraints (checks
   and foreign keys) that mimic behavior of the old table.
2. In application code, write to both tables, continuing to read from old table.
3. [Backfill data] from old table to new table
4. In application code, move reads from old table to the new table
5. In application code, remove old table from Ecto schemas.
6. Drop the old table.

[Backfill data]: #backfilling-data

---

<a name="adding-a-check-constraint"></a>
## Adding a check constraint

Adding a check constraint blocks reads and writes to the table in Postgres, and
blocks writes in MySQL/MariaDB while every row is checked.

### BAD

```elixir
def change do
  create constraint("products", :price_must_be_positive, check: "price > 0")
  # Creating the constraint with validate: true (the default when unspecified)
  # will perform a full table scan and acquires a lock preventing updates
end
```

### GOOD

There are two operations that are occurring:

1. Creating a new constraint
1. Validating the new constraint

If these commands are happening at the same time, it obtains a lock on the table
as it validates the entire table. To avoid this lock, we can separate the
operations.

In one migration:

```elixir
def change do
  create constraint("products", :price_must_be_positive, check: "price > 0"), validate: false
  # Setting validate: false will prevent a full table scan, and therefore
  # commits immediately.
end
```

In the next migration:

```elixir
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT price_must_be_positive", ""
  # Acquires SHARE UPDATE EXCLUSIVE lock, which allows updates to continue
end
```

These can be in the same deployment, but just ensure there are 2 separate
migrations.

---

<a name="setting-not-null-on-an-existing-column"></a>
## Setting `NOT NULL` on an existing column

Setting NOT NULL on an existing column blocks reads and writes while every row
is checked.

### BAD

```elixir
def change do
  alter table("products") do
    modify :active, :boolean, null: false
  end
end
```

### GOOD

Add a check constraint without validating it, [backfill data] to satiate the
constraint, then validate it. This will be functionally equivalent.

In the first migration:

```elixir
def change do
  create constraint("products", :active_not_null, check: "active IS NOT NULL"), validate: false
end
```

This will enforce the constraint in all new rows, but not care about existing
rows until that row is updated. You'll likely need a [data migration] at this
point to ensure that the constraint is satisfied.

[data migration]: #backfilling-data

Then, in the next deployment's migration, we'll enforce the constraint on all
rows:

```elixir
def change do
  execute "ALTER TABLE products VALIDATE CONSTRAINT active_not_null", ""
end
```

If you're using Postgres 12+, you can add the `NOT NULL` to the column after
validating the constraint. From the Postgres 12 docs:

> SET NOT NULL may only be applied to a column provided none of the records in
> the table contain a NULL value for the column. Ordinarily this is checked
> during the ALTER TABLE by scanning the entire table; however, if a valid CHECK
> constraint is found which proves no NULL can exist, then the table scan is
> skipped.

```elixir
# **Postgres 12+ only**

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
[backfill data]: #backfilling-data

---

<a name="adding-a-json-column"></a>
## Adding a JSON column

In Postgres, there is no equality operator for the `json` column type, which can
cause errors for existing `SELECT DISTINCT` queries in your application.

### BAD

```elixir
def change do
  alter table("posts") do
    add :extra_data, :json
  end
end
```

### GOOD

Use `jsonb` instead.

```elixir
def change do
  alter table("posts") do
    add :extra_data, :jsonb
  end
end
```

---

<a name="backfilling-data"></a>
# PART 4 - Backfilling data

> This is a 4-part series:
>
> - [Part 1 - Anatomy of an Ecto migration](#part-1)
> - [Part 2 - How to migrate Mix Release projects](#how-to-migrate-mix-release-projects)
> - [Part 3 - Migration Scenarios](#scenarios)
> - [Part 4 - Backfilling Data](#backfilling-data) (You are here)

### BAD

```elixir
defmodule MyApp.Repo.Migrations.BackfillPosts do
  use Ecto.Migration
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
end
```

The referenced `MyApp.MySchema` is defined in application code, which may change
over time. However, migrations are a snapshot of your schemas at the time it's
written. In the future, assumptions in the query may no longer be true; for
example, the `new_data` column may not be present anymore in the schema causing
the query to fail if this migration is ran later.

Additionally, in your development environment, you might have 10 records to
migrate; in staging, you might have 100; in production, you might have 10
billion to migrate. Scaling your approach matters.

Ultimately, there are several bad practices here:

1. The Ecto schema of the query is subject to change after the given migration.

2. Backfilling data inside a transaction will lock the rows for the duration of
   the migration

3. If you were to backfilling all the data all at once, it may exhaust the
   database memory and/or CPU if it's changing a large data set.

4. Only batching updates may still spike the database CPU to 100%, causing other
   concurrent reads or writes to time out.

### GOOD

There are three keys to backfilling safely:

  1. running outside a transaction
  2. batching
  3. throttling

As we've learned in this guide, it's straight-forward to disable the migration
transactions. Add these options to the migration:

```elixir
@disable_ddl_transaction true
@disable_migration_lock true
```

Batching and throttling data migrations still has several challenges:

* `LIMIT/OFFSET` is an expensive query for large tables, so we must find
  another way to paginate.

* Sine we cannot use a database transactions, this also implies we cannot
  leverage cursors since they require a transaction.

* This leaves us with keyset pagination

For querying and updating the data, there are two options for "snapshotting"
your schema at the time of the migration:

1. Execute SQL that represents the table at that moment. Do not reference in-app
   Ecto schemas.

2. Write a small Ecto schema module inside the migration that only involves what
   you need, and use that in your data migration. This is helpful if you prefer
   the Ecto API for querying.

Finally, to manage these data migrations separately, see section [Create Release
Module](#create-release-module). Put simply:

1. Store data migrations separately from your normal schema migrations.

1. Run these data migrations manually.

<a name="throttling-deterministic-data"></a>
### Throttling deterministic set of data

If the data can be queried with a condition that is removed after update, for
example if a column is currently null and will be updated to not be null, then
you can repeatedly query the data and update the data until the query result is
empty.

Here's how we can manage the backfill:

1. Disable migration transactions.
1. Use keyset pagination: Order the data, find rows greater than the last mutated
   row and limit by batch size.
1. For each page, mutate the records.
1. Check for failed updates and handle it appropriately.
1. Use the last mutated record's ID as the starting point for the next page
1. Arbitrarily sleep to throttle and prevent exhausting the database.
1. Rinse and repeat until there are no more records

For example:

```elixir
defmodule MyApp.Repo.Migrations.BackfillPosts do
  use Ecto.Migration
  import Ecto.Query

  @disable_ddl_transaction true
  @disable_migration_lock true
  @batch_size 1000
  @throttle_ms 100

  def up do
    throttle_change_in_batches(&page_query/1, &do_change/1)
  end

  def down, do: :ok

  def do_change(batch_of_ids) do
    {_updated, results} = repo().update_all(
      from(r in "weather", select: r.id, where: r.id in ^batch_of_ids),
      [set: [approved: true]],
      log: :info
    )
    not_updated = MapSet.difference(MapSet.new(batch_of_ids), MapSet.new(results)) |> MapSet.to_list()
    Enum.each(not_updated, &handle_non_update/1)
    results
  end

  def page_query(last_id) do
    from(
      r in "weather",
      select: r.id,
      where: is_nil(r.approved) and r.id > ^last_id,
      order_by: [asc: r.id],
      limit: @batch_size
    )
  end

  # If you have BigInt IDs, fallback last_pod = 0
  # If you have UUID IDs, fallback last_pos = "00000000-0000-0000-0000-000000000000"
  # If you have Int IDs, you should consider updating it to BigInt or UUID :)
  defp throttle_change_in_batches(query_fun, change_fun, last_pos \\ 0)
  defp throttle_change_in_batches(_query_fun, _change_fun, nil), do: :ok
  defp throttle_change_in_batches(query_fun, change_fun, last_pos) do
    case repo().all(query_fun.(last_pos), [log: :info]) do
      [] ->
        :ok

      ids ->
        results = change_fun.(List.flatten(ids))
        next_page = results |> Enum.reverse() |> List.first()
        Process.sleep(@throttle_ms)
        throttle_change_in_batches(query_fun, change_fun, next_page)
    end
  end

  defp handle_non_update(id) do
    raise "#{inspect(id)} was not updated"
  end
end
```

---

<a name="throttling-arbitrary-data"></a>
### Throttling Arbitrary set of data

If the data being updated cannot indicate it's already been updated, for example
if all a column's values must be incremented by 10, then we need to take a
snapshot of the current data and store it temporarily. Instead of pulling IDs
into the application during the migration, we're instead going to keep the data
in the database.

**This requires new records going forward to not need adjustment**, so we
should query up to a certain point in history. In this example, we'll use
`inserted_at` as our marker (let's say that we fixed the bug on a midnight
deploy on 2021-08-22).

Here's how we'll manage the backfill:

1. Create a "temporary" table. In this example, we're creating a real table that
   we'll drop at the end of the data migration. In Postgres, there are [actual
   temporary tables](https://www.postgresql.org/docs/12/sql-createtable.html)
   that are discarded after the session is over; we're _not_ using those because
   we need resiliency in case the data migration encounters an error. The error
   would cause the session to be over, and therefore the temporary table
   tracking progress would be lost 🙁. Real tables don't have this problem.
   Likewise, we don't want to store IDs in application memory during the
   migration for the same reason.
1. Populate that temporary table with IDs of records that need to update. This
   query only requires a read of the current records, so there are no
   consequential locks occurring when populating, but be aware this could be a
   lengthy query. Populating this table can occur at creation or afterwards; in
   this example we'll populate it at table creation.
1. Ensure there's an index on the temporary table so it's fast to delete IDs
   from it. I use an index instead of a primary key because it's easier to
   re-run the migration in case there's an error. There isn't a straight-forward
   way to `CREATE IF NOT EXIST` on a primary key; but you can do that easily
   with an index.
1. Pull batches of IDs from the temporary table. Do this inside a database
   transaction and lock those records for updates. Each batch should be read and
   update within milliseconds, so this should have little consequence on
   concurrent reads and writes.
1. For each batch of records, determine the mutations of the data that need to
   occur. This can happen for each record.
1. Upsert those changes to the real table. This insert will include the ID of
   the record that already exists and a list of attributes to change for that
   record. Since these insertions will conflict with existing records, we'll
   instruct Postgres to replace certain fields on conflicts.
1. Delete those IDs from the temporary table since they're updated on the real
   table. Close the database transaction for that batch.
1. Throttle so we don't overwhelm the database.
1. Rinse and repeat until the temporary table is empty.
1. Finally, drop the temporary table.

Let's see how this can work:

```elixir
# Both of these modules are in the same migration file

defmodule MyApp.Repo.Migrations.BackfillWeather.MigratingSchema do
  use Ecto.Schema

  # Copy of the schema at the time of migration
  schema "weather" do
    field :temp_lo, :integer
    field :temp_hi, :integer
    field :prcp, :float
    field :city, :string

    timestamps(type: :naive_datetime_usec)
  end
end

defmodule MyApp.Repo.Migrations.BackfillWeather do
  use Ecto.Migration
  import Ecto.Query
  alias MyApp.Repo.Migrations.BackfillWeather.MigratingSchema

  @disable_ddl_transaction true
  @disable_migration_lock true
  @temp_table_name "records_to_update"
  @batch_size 1000
  @throttle_ms 100

  def up do
    repo().query!("""
    CREATE TABLE IF NOT EXISTS "#{@temp_table_name}" AS
    SELECT id FROM weather WHERE inserted_at < '2021-08-21T00:00:00'
    """, [], log: :info, timeout: :infinity)
    flush()
    create_if_not_exists index(@temp_table_name, [:id])
    flush()
    throttle_change_in_batches(&page_query/0, &do_change/1)
    drop table(@temp_table_name)
  end

  def down, do: :ok

  def do_change(batch_of_ids) do
    # Wrap in a transaction to mementarily lock records during read/update
    repo().transaction(fn ->
      mutations =
        from(
          r in MigratingSchema,
          where: r.id in ^batch_of_ids,
          lock: "FOR UPDATE"
        )
        |> repo().all()
        |> Enum.map(&mutation/1)

      # Don't be fooled by `insert_all`, this is actually an upsert that will
      # update existing records when conflicting; they should all conflict
      # since the ID is included in the update.

      {_updated, results} = repo().insert_all(
        MigratingSchema,
        mutations,
        returning: [:id],
        # Alternatively, {:replace_all_except, [:id, :inserted_at]}
        on_conflict: {:replace, [:temp_lo, :updated_at]},
        conflict_target: [:id],
        placeholders: %{now: NaiveDateTime.utc_now()},
        log: :info
      )
      results = Enum.map(results, & &1.id)

      not_updated =
        mutations
        |> Enum.map(& &1[:id])
        |> MapSet.new()
        |> MapSet.difference(MapSet.new(results))
        |> MapSet.to_list()

      Enum.each(not_updated, &handle_non_update/1)
      repo().delete_all(from(r in @temp_table_name, where: r.id in ^results))

      results
    end)
  end

  def mutation(record, mutations_acc) do
    # This logic can be whathever you need; we'll just do something simple
    # here to illustrate
    if record.temp_hi > 1 do
      # No updated needed
      mutations_acc
    else
      # Upserts don't update autogenerated fields like timestamps, so be sure
      # to update them yourself. The inserted_at value should never be used
      # since all these records are already inserted, and we won't replace
      # this field on conflicts; we just need it to satisfy table constraints.
      [%{
        id: record.id,
        temp_lo: record.temp_hi - 10,
        inserted_at: {:placeholder, :now},
        updated_at: {:placeholder, :now}
      } | mutations_acc]
    end
  end

  def page_query do
    from(
      r in @temp_table_name,
      select: r.id,
      limit: @batch_size
    )
  end

  defp handle_non_update(id) do
    raise "#{inspect(id)} was not updated"
  end

  defp throttle_change_in_batches(query_fun, change_fun) do
    case repo().all(query_fun.(), [log: :info]) do
      [] ->
        :ok

      ids ->
        case change_fun.(List.flatten(ids)) do
          {:ok, _results} ->
            Process.sleep(@throttle_ms)
            throttle_change_in_batches(query_fun, change_fun)
          error ->
            raise error
        end
    end
  end
end
```

<a name="references"></a>
# References

Before you think this is a completely original article, I want you to know that
I took a lot of inspiration from Andrew Kane and his library
[strong_migrations](https://github.com/ankane/strong_migrations). Think of this
article as a port of his and his contributors' guide to Elixir and Ecto.

[PostgreSQL at Scale by James Coleman](https://medium.com/braintree-product-technology/postgresql-at-scale-database-schema-changes-without-downtime-20d3749ed680)

[Strong Migrations by Andrew Kane](https://github.com/ankane/strong_migrations)

[Adding a NOT NULL CONSTRAINT on PG Faster with Minimal Locking](https://medium.com/doctolib/adding-a-not-null-constraint-on-pg-faster-with-minimal-locking-38b2c00c4d1c)

[Postgres Runtime Configuration](https://www.postgresql.org/docs/current/runtime-config-client.html)

[Wojtek Mach's Automatic and Manual Ecto Migrations](https://dashbit.co/blog/automatic-and-manual-ecto-migrations)

Special thanks for these reviewers:

* Steve Bussey

<a name="reference-material"></a>
# Reference Material

## [Postgres Lock Conflicts](https://www.postgresql.org/docs/12/explicit-locking.html)

|  | | **Current Lock →** | | | | | |
|---------------------|-------------------|-|-|-|-|-|-|
| **Requested Lock ↓** | ACCESS SHARE | ROW SHARE | ROW EXCLUSIVE | SHARE UPDATE EXCLUSIVE | SHARE | SHARE ROW EXCLUSIVE | EXCLUSIVE | ACCESS EXCLUSIVE |
| ACCESS SHARE           |   |   |   |   |   |   |   | X |
| ROW SHARE              |   |   |   |   |   |   | X | X |
| ROW EXCLUSIVE          |   |   |   |   | X | X | X | X |
| SHARE UPDATE EXCLUSIVE |   |   |   | X | X | X | X | X |
| SHARE                  |   |   | X | X |   | X | X | X |
| SHARE ROW EXCLUSIVE    |   |   | X | X | X | X | X | X |
| EXCLUSIVE              |   | X | X | X | X | X | X | X |
| ACCESS EXCLUSIVE       | X | X | X | X | X | X | X | X |

- `SELECT` acquires a `ACCESS SHARE` lock
- `SELECT FOR UPDATE` acquires a `ROW SHARE` lock
- `UPDATE`, `DELETE`, and `INSERT` will acquire a `ROW EXCLUSIVE` lock
- `CREATE INDEX CONCURRENTLY` and `VALIDATE CONSTRAINT` acquires `SHARE UPDATE EXCLUSIVE`
- `CREATE INDEX` acquires `SHARE` lock
