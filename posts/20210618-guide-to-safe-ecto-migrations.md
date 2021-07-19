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

- [Anatomy of an Ecto migration](#anatomy-of-an-ecto-migration)
  - [Inspect SQL](#inspect-sql)
  - [Migration Options](#migration-options)
- [How to migrate Mix Release projects](#how-to-migrate-mix-release-projects)
  - [Create Release module](#create-release-module)
  - [Assemble the release](#assemble-release)
  - [Check migration status](#check-migration-status)
  - [Run the migration](#run-the-migration)
  - [Rollback migrations](#omg-roll-it-back)
- [How to check for locks in a query](#how-to-inspect-locks-in-a-query)
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
database. I'll note where differences may be.

Ok! Let's go

![Ready for an adventure](/images/ready-for-an-adventure.gif)

[Mix Release]: https://hexdocs.pm/mix/1.9.0/Mix.Release.html
[Distillery]: https://hexdocs.pm/distillery


# Anatomy of an Ecto migration

To generate a migration, we'll use `mix ecto.gen.migration`.

> **Tip** If you're using Phoenix, you might consider `mix phx.gen.schema` which
> will generate a migration and also allows you to pass in fields and types. See
> `mix help phx.gen.schema` for more information.

```shell
mix ecto.gen.migration create_test_table
```

This command will generate file in `priv/repo/migrations` given the repo name of
`Repo`. If you named it `OtherRepo` the file would be in
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

## Inspect SQL

Let's zoom in on the migration. By default, Ecto will not log the raw SQL. Let's
look at what actually runs. First, I'll rollback, and then re-migrate but with
an additional flag `--log-sql` so we can see what actually runs.

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
missing logs, I'll tail the Postgres logs and reveal here.

```
LOG:  statement: BEGIN
LOG:  execute ecto_642: SELECT s0."version"::bigint FROM "schema_migrations" AS s0 FOR UPDATE
LOG:  execute ecto_674: SELECT s0."version"::bigint FROM "schema_migrations" AS s0
LOG:  statement: BEGIN
LOG:  execute <unnamed>: CREATE TABLE "weather" ("id" bigserial, "city" varchar(40), "temp_lo" integer, "temp_hi" integer, "prcp" float, "inserted_at" timestamp(0) NOT NULL, "updated_at" timestamp(0) NOT NULL, PRIMARY KEY ("id"))
LOG:  execute ecto_insert_schema_migrations: INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2)
DETAIL:  parameters: $1 = '20210718204657', $2 = '2021-07-18 20:53:49'
LOG:  statement: COMMIT
LOG:  statement: COMMIT
```

**Postgres difference**. Here, Postgres will actually run the migration wrapped
in a transaction. This part is unlogged, so we'll have to reference the code.

When running migrations, Ecto will travel through these functions:
  - [Ecto.Migrator.run/4](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/migrator.ex#L384)
  - [Ecto.Migrator.lock_for_migrations/4](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/migrator.ex#L464)
  - [The adapter's lock_for_migrations implementation](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/adapters/postgres.ex#L207)
  - [Wrap the migration in a transaction](https://github.com/elixir-ecto/ecto_sql/blob/557335f9a2a1e6950c1d761063e84aa5d03cb312/lib/ecto/adapters/postgres.ex#L217)

Inside the transaction, the Postgres adapter is also obtaining a `SHARE UPDATE
EXCLUSIVE` lock of the "schema_migrations" table.

**Why this lock is important**: Elixir excels at distributed deployments, which
means there could be multiple nodes connected to the same database. These nodes
may also all try to migrate the database at the same time! Ecto leverages this
`SHARE UPDATE EXCLUSIVE` lock as a way to ensure that only one node is running a
migration at a time and only once.

This is what the **migration actually looks like**:

```sql
BEGIN;
LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
BEGIN;
CREATE TABLE "test" ("id" bigserial, "city" varchar(40), "temp_lo" integer, "temp_hi" integer, "prcp" float, "inserted_at" timestamp(0) NOT NULL, "updated_at" timestamp(0) NOT NULL, PRIMARY KEY ("id"));
COMMIT;
INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ('20210718204657','2021-07-18 20:53:49');
COMMIT;
```

If the migration fails, the transaction is rolled back and no changes actually
occur in the database. In most scenarios, these are great defaults.

There's also some options we can set in a given Ecto migration. Let's explore
some of those options next.

[Ecto.Migration]: https://hexdocs.pm/ecto_sql/Ecto.Migration.html

## Migration Options

By default, your migration will have this structure (reminder: this guide is
using Postgres; different adapters will vary):

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
  BEGIN;
    -- after_begin callback
    -- my changes
    -- before_commit callback
  COMMIT;
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
COMMIT;
```

`my_changes` refers to the changes you specify in each of your migrations.

**`@disable_migration_lock`**

By default, Ecto will acquire a lock on the "schema_migrations" table during
migration transaction:

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE -- THIS LOCK
  -- BEGIN;
    -- my changes
  -- COMMIT;
  -- INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ($1,$2);
COMMIT;
```

You want this lock for most migrations because running multiple migrations at
once concurrently could have unpredictable results. To facilitate releasing this
lock, the command is wrapped in a transaction.

However, there are some scenarios where you don't want a lock, for example if
you're running data migrations that are kicked-off manually. You can skip this
lock in Ecto by setting the module attribute `@disable_migration_lock true` in
your migration. Keep in mind there is another transaction occurring in the
migration (see next point).

You can also disable this migration lock for all migrations by configuring the
Repo:

```elixir
# config/config.exs
config :my_app, MyApp.Repo, migration_lock: false
# But this is not recommended for Postgres users. See next point.
```

**`@disable_ddl_transaction`**

By default, Ecto will wrap your changes in a transaction:

```sql
BEGIN;
  -- my migration
COMMIT;
```

This helps ensure that if failures occur during the migration, it does not leave
your database in an incomplete and confusing state.

There are some scenarios where you may not want a migration to occur inside a
transaction, such as data migrations or commands such as `CREATE INDEX
CONCURRENTLY` that can work asynchronously on the database side after you issue
the command and cannot be inside a transaction.

You can disable this transaction by setting the module attribute
`@disable_ddl_transaction true` in your migration.

> **Tip**: For Postgres, usually when disabling transactions, you'll **also want
> to disable the migration lock** since that uses yet another transaction. When
> running these migrations in a multi-node environment, you'll need a process to
> ensure these migrations are only kicked-off once since there is no protection
> against multiple nodes running the same migration at the same exact time.

**Transaction Callbacks**

If the migration is occurring within a transaction, you might appreciate hooks
before and after your changes.

```sql
BEGIN;
  -- after_begin hook
  -- my changes
  -- before_commit hook
COMMIT;
```

You can use these hooks by defining `after_begin/0` and `before_commit/0` in
your migration. A good use case for this is setting migration lock timeouts as
safeguards (see [next section](#safeguards-in-the-database))

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

# How to migrate Mix Release projects

In Mix Release projects, we need to give ourselves easy access to commands to
facilitate migrations. Here's a couple of use cases:

1. Check the status of migrations.
1. Migrate repos up to x migration. Default to the latest migration.
1. Rollback to x migration for a specific Repo.

The common and documented way to encapsulate these commands is with a
`MyApp.Release` module.

## Create `MyApp.Release`

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
  Deployers may only want to execute one at a time. Currently, the function does
  not allow us to only run one migration.

**Adding options to `MyApp.Release.migrate`**

Let's adjust the `migrate` function to accept options that we can pass into
`Ecto.Migrator`.

```diff
+  @doc """
+  Migrate the database. Defaults to migrating to the latest, ie `[all: true]`
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
in this command. You'll require yourself to pass in the specific repo and
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

A lot of this code is borrowed from the mix task `mix ecto.migrations`, but
adapted to not require the `Mix` module.

When you run `bin/my_app eval "MyApp.Release.migration_status()"`, this
should be the output:

```
Repo: MyApp.Repo
  Status    Migration ID    Migration Name
--------------------------------------------------
  down      20210718153339  add_test_table1
  down      20210718153341  add_test_table2
```

## Assemble the Release

Now it's time to assemble the release with `mix release`. Great! Done! ...now
what?

...well, it depends on how you're starting the application. Let's ask some
questions:

1. Does the deployed code rely on the migrations already being ran? If so, then
   **no you cannot start your application!** It will crash! The code already
   assumes the database to be in the state after migration. You need to run your
   migrations first and start the application after.

1. Does it contain migrations that aren't yet utilized? For example, you already
   have your database created and `profiles` table created, and you _only have a
   migration_ to add a column to the profiles table. **Yes you can go ahead and
   start your application** since the code does not yet rely on that column to
   exist. Then run the migrations at your convenience.

1. Do you use Kubernetes? Then you should **consider [Init Containers]**. Init
   containers run to completion _before_ the application containers in the pod.
   This is a perfect opportunity to start your Ecto Repo and migrate it before
   starting the rest of your application. Make sure you exclude data migrations
   from this process however, since those usually will not be safe to
   automatically run in multi-node environments.

[Init Containers]: https://kubernetes.io/docs/concepts/workloads/pods/init-containers/

Now that you've determined which order to start the application or run the
migration, let's start running stuff!

## Check migration status

We can inspect the database migration statuses with `bin/my_app eval
'MyApp.Release.migration_status()'`.

```
Repo: MyApp.Repo
  Status    Migration ID    Migration Name
--------------------------------------------------
  down      20210718153339  add_test_table1
  down      20210718153341  add_test_table2
```

## Run the migration

The database can migrate with `bin/my_app eval 'MyApp.Release.migrate()'`.

When running `bin/my_app eval`, a separate slim instance of the Erlang VM is
started. Your app is loaded _but not started_. Only the Repo is started, and
it's only started with 2 database connections. Since this is a new instance
booting, this implies that it will also need the same environment variables as
your running application. If you rely on environment variables to know which
database to connect to and its credentials, ensure they're present when running
this command.

## OMG ROLL IT BACK

The app can rollback with `bin/my_app eval 'MyApp.Release.rollback(MyApp.Repo,
20210709121212)'`

# How to inspect locks in a query

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

The result from this SQL command should return to you the locks obtained during
the operation. Let's see an example.

First, we'll create a table. We'll do it the way that Ecto does it so we're not
missing anything.

```sql
BEGIN;
  LOCK TABLE "schema_migrations" IN SHARE UPDATE EXCLUSIVE MODE;
  BEGIN;
    CREATE UNIQUE INDEX IF NOT EXISTS "weather_city_index" ON "weather" ("city");
  COMMIT;
  INSERT INTO "schema_migrations" ("version","inserted_at") VALUES ('20210718210952',NOW());
COMMIT;
```

Now, we'll add a unique index. We'll create the index naively without
concurrency so we can see the locks it obtains.

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
   writes! This won't be good if we deploy this** if we have processes or web
   requests that regularly write to this table. `UPDATE` `DELETE` and `INSERT`
   acquire a RowExclusiveLock which conflicts with the ShareLock.

To fix this lock, we'll instead change the command to `CREATE INDEX CONCURRENTLY
...`; when using `CONCURRENTLY`, it prevents us from using `BEGIN/COMMIT`
transactions which is unfortunate because now we cannot easily see the locks the
command obtains. We know this will be safer because `CREATE INDEX CONCURRENTLY`
acquires a ShareUpdateExclusiveLock which does not conflict with
RowExclusiveLock.

# Safeguards in the database

It's a good idea to add safe guards so no developer on the team accidentally
locks up the database for too long.

## Add `lock_timeout` to all migrations

One safe guard we can add to migrations is a lock timeout. A lock timeout will
ensure a lock should not last more than n seconds. This way, if an unsafe
migration does sneak in, it should only lock tables and their subsequent updates
and writes, and possibly reads for n seconds instead of indefinitely until the
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
1. globally for the user.

### Transaction `lock_timeout`

In SQL:

```sql
SET lock_timeout to '5s';
```

Let's move this to Ecto migration transactions.

In every migration, you'll notice that we `use Ecto.Migration` which inserts
some code into your migration. Let's use this same idea to inject some
boilerplate of our own, and leverage an option to set a lock timeout. We'll an
[`after_begin`](https://hexdocs.pm/ecto_sql/Ecto.Migration.html#c:after_begin/0)
callback to set the lock_timeout.

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

### Role `lock_timeout`

Alternatively, you can set the lock_timeout for the user in all commands:

```sql
ALTER ROLE myuser SET lock_timeout = '10s';
```

[Ecto migration transaction callbacks]: https://hexdocs.pm/ecto_sql/Ecto.Migration.html#module-transaction-callbacks

## Statement Timeout

Another way to ensure safety is to configure your Postgres database to have
statement timeouts. These timeouts will apply to all statements, including
migrations.

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

You can specify this configuration for the postgres user. For example:

```sql
ALTER ROLE myuser SET statement_timeout = '10m';
```

Now any statement will automatically time out if it runs for more than 10
minutes; opposed to indefinitely running. This could be helpful if you
accidentally run a query that runs the database CPU hot, slowing everything else
down; now that unoptimized query will be limited to 10 minutes or else it will
fail.

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
