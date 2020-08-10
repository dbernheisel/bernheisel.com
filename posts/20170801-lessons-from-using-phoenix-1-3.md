%{
  title: "Lessons From Using Phoenix 1.3",
  tags: ["elixir"],
  original_url: "https://robots.thoughtbot.com/lessons-from-using-phoenix-1-3",
  description: """
  Phoenix 1.3 introduces contexts, which has been met with some resistance. I've
  developed an application using it and learned some lessons.
  """
}
---

Phoenix 1.3 introduces contexts, which has been met with some resistance. I've
developed an application using it and learned some lessons.

**[WARNING]** I like contexts.

![me, now, ashamed and hiding because I am probably going against the grain that
other smarter-than-me people likely established already](/images/homer-backing-up.gif)

Phew... I just wanted to admit that up front. Now that I got that out of the
way, I am going to share my journey about using Phoenix 1.3.0 and contexts.

---

- [My context](#experience)
- Lessons:

  - [Don't use the generators](#dontgenerators)
  - [Embrace the domain vocabulary](#dothedomain)
  - [Avoid the bloat](#bloated)
  - [Consider before umbrellas](#maybeumbrella)

- [You should give it a shot](#giveitago)

<a name="experience"></a>

## Experience

I worked on a greenfield project and had an opportunity to use Phoenix
1.3.0-rc2. With Phoenix 1.3.0 just released, I thought it might be timely to
inform other developers what it's like to work with contexts, and some
recommendations I have after working on a project using contexts for several
months.

If you don't know what a context is:

- [watch Chris McCord talk about
  it](https://youtu.be/tMO28ar0lW8?t=12m21s)
- or [read Martin Fowler's explanation of Bounded
  Context](https://martinfowler.com/bliki/BoundedContext.html)
- or [read the Phoenix 1.3 release
  post](http://phoenixframework.org/blog/phoenix-1-3-0-released)
- or read my tldr version:

  > A context is a module that defines the interface between a set of
  > inter-related models/schemas to the rest of the application (like other
  > contexts). A context is an internal API that provides opportunity to name
  > things better and organize code.

A practical example: instead of your controller talking to the database, your
controller will talk to the context, and the context will interface with
necessary functions and schemas and modules to accomplish the task.

**NOTE:** I did not use 1.3.0-rc3 which changes the `Web` namespace, so I will
skip that part. I think that's a good change, but I have no real experience with
those tweaks yet.

## Lessons

<a name="dontgenerators"></a>

### Don't use the generators more than once

With Phoenix 1.3, I only recommend using the `phx` generators ONCE in a
greenfield project. After that, ditch them. Ditch them because once you've
adjusted the code to your liking (and you'll definitely need to edit the
generated code), using the generators again may _**inject**_ generated code into
your existing files, which likely don't follow your patterns anymore.

Since I'm recommending against something, let's jump into examples and find out
why.

Here's what I had to do with the generated files:

- **Rewrite the tests because they setup a fixture for the schema.**

  This isn't a bad idea in itself, but I wanted to use
  [ex_machina](https://github.com/thoughtbot/ex_machina) for setting up test
  scenarios. At first, I thought the generated fixture was a great idea.  I'm
  providing an interface for creating widgets, so I should use it in my tests,
  right?

  Here's the problem:

  Imagine if someone introduced a bug in `create_widget()`-- now all your tests
  that involve inserting a `widget` breaks. That's unreasonable, because I'm not
  testing _getting to that state_ most of the time, I'm testing the unit of
  functionality or integration between functions. Instead, I want the tests for
  `create_widget()` to fail (and any reliant integration tests), as opposed to
  the **WHOLE TEST SUITE** breaking and thus freaking me out. When the whole
  test suite breaks, it's harder to discern where the problem is.

- **Separate the schema-specific tests into their own test file.**

  The new context organization only generates a test file for the _context_, and
  not a schema. As I kept building the application, it became evident that the
  context file and context test file were getting too large. I felt compelled to
  isolate and organize this big bag-o'-functions into smaller bags-o'-functions.
  I decided to start splitting the tests into different schema-related files,
  like `{context}/{schema}_test.exs`. Since I split the test files, it became
  clearer where I should place tests for custom changeset functions as well.

  I also want to be more careful about how I use `describe` and `test` blocks,
  since ExUnit doesn't support nested `describe` or context blocks.  The
  generated test names were also a bit long for my taste, so I moved the
  function name to the `describe` block, and then used the test title to
  describe the context and the expected result.

  Lastly, the generated style was ... different.

  - I don't like aliasing modules in the middle of the file. I feel
    they belong at the top of the file.
  - I keep module attributes near the top of the file.
  - I avoid the function parenthesis unless I need them.

  Here is an example of how I changed things:

  ```elixir
  # BEFORE
  # test/my_app/things_test.exs
  defmodule MyApp.ThingsTest do
    use MyApp.DataCase
    alias MyApp.Things

    describe "widgets" do
      alias MyApp.Things.Widget

      @valid_attrs %{}
      @update_attrs %{}
      @invalid_attrs %{}

      def widget_fixture(attrs \\ %{}) do
        {:ok, widget} =
          attrs
          |> Enum.into(@valid_attrs)
          |> Things.create_widget()

        widget
      end

      test "list_widgets/0 returns all widgets" do
        widget_one = widget_fixture()
        widget_two = widget_fixture()

        assert Things.list_widgets() == [widget_one, widget_two]
      end

      # I added this, just to go along with their style and to show
      # what a typical new developer would do with this existing pattern
      test "list_widgets/1 returns all widgets limited by list of id" do
        widget_one = widget_fixture()
        _widget_two = widget_fixture()

        assert Things.list_widgets([widget_one.id]) == [widget_one]
      end

      #...
    end
  end

  # AFTER
  # test/my_app/things/widget_test.exs
  defmodule MyApp.Things.WidgetTest do
    use MyApp.DataCase
    import MyApp.Factory
    alias MyApp.Things
    alias MyApp.Things.Widget

    describe "list_widgets" do
      test "returns all widgets" do
        [widget_one, widget_two] = insert_pair(:widget)

        assert Things.list_widgets == [widget_one, widget_two]
      end

      test "when given list of ids, returns all widgets in ids" do
        [widget_one, _widget_two] = insert_pair(:widget)

        assert Things.list_widgets([widget_one.id]) == [widget_one]
      end
    end

    #...
  end
  ```

  I like this so much better, and I'm afraid that just going with the generated
  pattern will lead newer developers down a path of bloated files.

It's more apparent to me in Phoenix 1.3.0 that the generators are much more a
teaching tool for new developers than meant to be used in an ongoing fashion
throughout a project's lifetime. If you've formed your opinion, or your
organization has a coding style within Phoenix, then you might appreciate
knowing you can customize the templates that the generators will use. You can do
this by copying them out of `deps/phoenix/priv/templates` and into your
project's `priv/templates` folder. That's pretty awesome.

Recap: for new developers, Phoenix's new generators are a great learning tool,
but I don't recommend using them after the first use.

<a name="dothedomain"></a>

### Embrace the domain vocabulary

I realized that my understanding of contexts at the time was flawed, and that
many of the examples out in the blog-o-sphere were not helpful for me when I was
in the trenches myself.

I imagine that most (all?) projects have their own domain AND vocabulary, and to
be readable for folks in that domain it is helpful to share that vocabulary.

This coming example may not apply to you, but this is the beauty of contexts:
your needs WILL differ and your domain vocabulary will help determine how to
organize your code.

The project I was working on had different terms for their warehouse workers:

- Operators
- Supervisors
- Admins
- SalesAssociate

This roughly corresponds with a typical `User` schema that `belongs_to` a `Role`
schema. I placed both schemas into a new context called `Accounts`, and all
user-related functions are in that context file. I hesitated with the domain
vocabulary thinking that generic terms were going to be more flexible later.

As the project evolved, that decision turned out to be a mistake

Instead of something like this (using a generic term `Accounts` as the context):

```elixir
defmodule MyApp.Accounts do
  alias MyApp.Accounts.User

  @operator_role_id 2
  @supervisor_role_id 1

  def list_operators(queryable \\ User) do
    queryable |> where([u], u.role_id == ^@operator_role)
  end

  def list_supervisors(queryable \\ User) do
    queryable |> where([u], u.role_id == ^@supervisor_role)
  end

  # ...
end
```

I could have done this (using domain vocabulary as context boundaries):

```elixir
defmodule MyApp.Operators do
  alias MyApp.Accounts.User

  @role_id 2

  def list(queryable \\ User) do
    queryable |> where([u], u.role_id == ^@role_id)
  end

  # ...
end

# notice the namespace difference
defmodule MyApp.Supervisors do
  alias MyApp.Accounts.User

  @role_id 1

  def list(queryable \\ User) do
    queryable |> where([u], u.role_id == ^@role_id)
  end

  # ...
end
```

This example is really simple, but it starts to show its strength later when you
have other conditionals and need to ask your data more questions.

With the example above, I'd actually argue that having one combined context is
preferable because it's all we need--but, knowing how the application **will**
grow, and how a lot of questions are asked against the user's role, then it'll
be more apparent having the separated context **will** be helpful.

```elixir
defmodule MyApp.Operators do
  alias MyApp.Activities.Event

  def update_event(event, params) do
    event
    |> prepare_event(params)
    |> Repo.update
  end

  def prepare_event(event, params) do
    event |> Event.operator_changeset(params)
  end

  # ...
end

defmodule MyApp.Supervisors do
  alias MyApp.Activities.Event

  def update_event(event, params) do
    event
    |> prepare_event(params)
    |> Repo.update
  end

  # Notice that we're calling a different changeset
  def prepare_event(event, params) do
    event |> Event.supervisor_changeset(params)
  end

  # ...
end
```

Above we're adding another function that has different permissions regarding
what the user may update on an event. The `supervisor_changeset` will cast all
params, whereas the `operator_changeset` will cast only a subset of params. This
would also be reflected for preparing any forms in templates.

All the above _requires_ you to understand the vocabulary before building, which
is the critique I usually hear about contexts: "It requires more up-front
cognitive thought before I can be productive." Prior to 1.3, not knowing domain
up front might not hurt so much because it's not built into the structure, but
with 1.3 and presumably later, it may hurt more. Despite that, it's _totally_
worth it.

### Avoid the bloat<a name="bloated"></a>

Above, I glossed-over what contexts help us achieve: making interfaces between
your abstractions. A context (aka domain interface) will help organize actions.
I _love_ this.

I decided in this experiment to _really_ give contexts a go and roll with the
philosophy. At the same time, I _hated_ the bloated context that it had become
after needing to interact with several schemas in the same context. At some
point, I had several hundred lines in a context file; it was easy to let the
context file grow. **RESIST**. Use domain-related vocabulary to keep contexts
small. I had to determine how to organize the code better.

A technique that helped keep contexts small was to limit them a set of action
verbs, like `list` `prepare` `create` `update` and `delete` (some semblance to
CRUD actions). Outside of those verbs, I put them into supporting modules. For
example, `def list` actually hits the database and returns the list of things--
it did not return an Ecto query that I could further modify. I saved those
query-building functions for a `Context.Query` module. This helped keep my
`list` function simple, and helped me make composable queries.

My controllers and other services then _only_ call functions in context modules.

For example:

```elixir
defmodule MyApp.Operators do
  # MyApp.Accounts is now a namespace for schemas, not a context
  alias MyApp.Accounts.User
  alias MyApp.Accounts.Role
  alias MyApp.Operators.Query

  def list(queryable \\ User) do
    queryable
    |> Query.where_operator
    |> Repo.all
  end

  def list_by_latest_event(queryable \\ User) do
    queryable
    |> Query.order_by_event_date
    |> list
  end

  def list_currently_assigned(queryable \\ User) do
    queryable
    |> Query.where_assigned
    |> list
  end

  def list_currently_assigned_for_activity(queryable \\ User, activity) do
    queryable
    |> Query.where_activity(activity.id)
    |> list_currently_assigned
  end

  # ...
end

defmodule MyApp.Operators.Query do
  import Ecto.Query
  @role_id 1

  def where_operator(queryable) do
    queryable
    |> where([q], q.role_id == ^@role_id)
  end

  def order_by_event_date(queryable) do
    queryable
    |> join(:left, [q], event in assoc(q, :event))
    |> order_by([_, event], [desc: event.inserted_at])
  end

  def where_assigned(queryable) do
    queryable
    |> where([q], is_nil(q.unassigned_at))
  end

  def where_activity(queryable, activity) do
    queryable
    |> join(:inner, [q], assignment in assoc(q, :assignments))
    |> where([_, assignment], assignment.activity_id == ^activity_id)
  end
end
```

This has been my preferred way of organizing code so far. It encourages less
god-modules that I've learned to dislike so much. I believe that Phoenix will
need to be more careful about their generators accidentally encouraging
god-modules, lest they start to look like monolith Rails applications with
models that know too much about the application, except now in a context.

<a name="maybeumbrella"></a>

### Consider Before Umbrellas

Elixir allows applications to live in umbrellas, which is an awesome concept. If
you're not familiar with umbrellas, [read up about
it](https://elixir-lang.org/getting-started/mix-otp/dependencies-and-umbrella-apps.html).
What I love about umbrellas is that it allows me to draw boundaries between
related applications. This is difficult to do in other frameworks and languages,
so the fact that `mix` gives this tool for free is _incredible_. Before I heard
about Phoenix contexts, I was drawn to organize my application via umbrellas
because I didn't see other tools that made it easy.

Umbrellas, in a sense, help accomplish the same thing as contexts: it helps you
draw boundaries. The difference is that umbrella applications are about
separating applications instead of APIs.

A lot of typical web applications don't need separated sub-applications. If
you're considering one, determine if having separately-deployable applications
fixes or avoids problems, or if the boundaries need to be large enough to
deserve a separation. Avoid jumping to umbrellas like I did earlier if you only
need to organize yourself.

[Chris gives some good examples of when umbrellas could be a good
option](https://youtu.be/tMO28ar0lW8?t=27m54s)

## Give It a Shot<a name="giveitago"></a>

At thoughtbot, we pride ourselves in the practices of designing experiences, and
_then_ developing; [that's what makes thoughtbot
different](https://thoughtbot.com/playbook). That process also helps establish
where these boundaries are up front, and it's up to the artist to determine
whether it's a new context, just a new schema, maybe a new application
altogether, maybe a support module, or none of the above.  Regardless, I believe
Phoenix 1.3 teaches _great_ ideas that will win in the long run and make
developers think before doing.
