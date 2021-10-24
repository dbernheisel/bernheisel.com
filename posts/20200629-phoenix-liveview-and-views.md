%{
  title: "Phoenix LiveView and Views",
  tags: ["elixir", "phoenix"],
  discussion_url: "https://github.com/dbernheisel/bernheisel.com/discussions/6",
  description: """
  Every time I build a LiveView application, I learn something new and find a
  new pattern, and some concept finally _clicks_. Today, that concept that
  cemented in my mind is how Phoenix and Phoenix LiveView renders templates.

  I want to show you a couple different View-rendering strategies. This should
  help you decide which strategy to use.
  """
}
---

I've written a couple LiveView applications now,

1. [Elixir Regex Tester]
1. A request logger, much like [Phoenix Live Dashboard]'s
1. An internal webmail server, for me to receive and send email through
   SendGrid. I hope to open-source this soon when it's ready.
1. Another private work-related project.

[Elixir Regex Tester]: https://utils.zest.dev/regex
[Phoenix Live Dashboard]: https://github.com/phoenixframework/phoenix_live_dashboard

Everytime I build one, I learn something new and find a new pattern, and some
concept finally _clicks_. Today, that concept that cemented in my mind is how
Phoenix and Phoenix LiveView renders templates.

I want to show you a couple different View-rendering strategies. This should
help you decide which strategy to use.

All of these strategies work, this is purely about opinionated code organizing,
_but who doesn't love reading opinions_? Plus we'll learn how the views are
rendered.

This is written while using Phoenix LiveView 0.13.3.

## TL;DR

Glossary of examples:
  1. `MyLive` = The LiveView module
  2. `MyView` = The standard Phoenix View module, not a LiveView.
  3. `my_live.html.leex` = The template rendered by `MyLive` or `MyView`

**If you have a simple LiveView**, then you can implement `render(assigns)`
and inline your html with the `~L` sigil. No `my_live.html.leex` file needed.

**If you have a LiveView with lots of HTML**, then you should use the standard
LiveView placement, and put your `my_live.ex` and `my_live.html.leex` next to
each other under `lib/my_app_web/live`. You don't need to define `render/1`
because the default will work. Omit it.

**If you have a LiveView with lots of HTML helper functions** that you want to
separate from business logic in the LiveView:

1. Add your own standard Phoenix view `MyView` (or a better name).
2. Move your `my_live.html.leex` file to the standard Phoenix locations (ie,
   `lib/my_app_web/templates/my`).
3. Implement your own `render(assigns)` that calls
   `MyAppWeb.MyView.render("my_live.html", assigns)`. Phoenix LiveView will
   still work; just remember to keep the html file named with an `.html.leex`
   extension so the LiveView rendering engine kicks in.

**Remember that you can create shared Views**. Alternatively, if your
helpers are used across multiple views and are generic, you can create a plain
module that encapsulates your HTML helpers. I usually call mine `ComponentView`
and use it inside any of my templates, for example:
`Component.primary_button("My Link", to: "yadayada")`.

**If you want to use a regular View, but co-locate the template to the LiveView module**,
as in you don't want to go back to the vanilla Phoenix file structure but still
need a separate `MyView` for your HTML helpers, you can specify the root
folder and path to look in when creating your `MyView` by supplying an option:
`use Phoenix.View, root: "lib/my_app_web/live", path: ""`. This is [explained in the
`Phoenix.View`
docs](https://hexdocs.pm/phoenix/1.5.13/Phoenix.View.html#__using__/1-options). This
can be wrapped up into a convenience macro though. Read on for more info.

**This totally ignores LiveComponent** as an option. If your LiveView can be
broken up into interactive components, then breaking out into a LiveComponent is
a good option to look into and works just like a LiveView. For the purpose of
this post and exploring how rendering works, we're going to treat LiveComponents
the same as a LiveView.

## ToC

- [Phoenix Controller/View/Template](#default-phoenix)
- [Phoenix LiveView with a template Part 1](#default-liveview)
- [Pluggy Controllers](#pluggy-controllers)
- [Phoenix LiveView with a template Part 2](#default-liveview)
- [Phoenix LiveView with an inline template](#liveview-inline)
- [Phoenix LiveView with an external template](#liveview-external)

<a name="default-phoenix"></a>
## Default Phoenix Controller/View/Template

First, to remember where we came from, I want to show a standard Phoenix
Controller/View/Template pattern. There are several modules involved that the
`Plug.Conn` travels through in order to turn into a response for the end-user.

1. Incoming request via `:cowboy`
2. Endpoint
3. Router
4. Controller
5. View
6. Template (not a module)
7. Outgoing response via `:cowboy`

```elixir
### Router - lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # ...snip...
  scope "/", MyAppWeb do
    pipe_through :browser

    get "/", PageController, :home
  end
  # ...snip...
end


### Controller - lib/my_app_web/controllers/page_controller.ex
defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller  #<-- injects some logic to handle receiving
  # the conn and passing the conn on to cowboy

  def home(conn, _params) do
    render(conn, "home.html")
  end
end


### View - lib/my_app_web/views/page_view.ex
defmodule MyAppWeb.PageView do
  use MyAppWeb, :view  #<-- injects some logic to handle evaluating
  # the embedded elixir in your templates
end
```

```html
<!-- Template - lib/my_app_web/templates/page/home.html.eex
We're going to ignore the layout stuff for now. Just know that it's
also evaluated and this template is a part of it -->
<p>Yo! You're rendering the home page</p>
```

In my mind, the template is the end of the show, though that's not technically
correct; the real **end of the line is the controller**. The controller is using
the view module to evaluate the HTML and puts the result into the Plug.Conn's
`resp_body`. The controller terminates the flow and the
once-a-request-and-now-a-response `Plug.Conn` is returned to the to the
underlying web server, which delivers the payload to the end-user through the
HTTP connection.

<a name="default-liveview"></a>
## Default Phoenix LiveView without `render/1`

We're here to learn about LiveView though, so let's see an example of a LiveView
without a `render/1` function.

```elixir
### lib/my_app_web/live/my_live.ex
defmodule MyAppWeb.MyLive do
  use MyAppWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # do stuff

    {:ok, socket}
  end
end
```
```html
<!-- lib/my_app_web/live/my_live.html.leex -->
<p>Yo! I'm rendered by a LiveView</p>
```

Ok, without a controller, how does a given Phoenix LiveView handle the request?
Here's a secret: **a LiveView is also an ordinary controller**.

Now... we may not use it like an ordinary Phoenix controller, but the request is
firstly handled like an ordinary web request; one with a Plug.Conn and a full
HTML response back to the user. The LiveView spices are garnished _after_ the
HTML is delivered to the user and a new websocket is initiated to the server to
the page updates to the page.

As said in the LiveView docs:

> A LiveView begins as a regular HTTP request and HTML response,
> and then upgrades to a stateful view on client connect,
> guaranteeing a regular HTML page even if JavaScript is disabled.
> Any time a stateful view changes or updates its socket assigns, it is
> automatically re-rendered and the updates are pushed to the client.

> Prove it!
>
>  -- you

ok ok.. I'll prove it. To prove that it's a regular controller, we'll need to
look at some of Phoenix LiveView's source code. Let's look at the code that
makes `live("/my-route", MyLive)` work in the router.

```elixir
defmacro live(path, live_view, action \\ nil, opts \\ []) do
  quote bind_quoted: binding() do
    {action, router_options} =
      Phoenix.LiveView.Router.__live__(__MODULE__, live_view, action, opts)

    # vvvvv THIS PART
    Phoenix.Router.get(path, Phoenix.LiveView.Plug, action, router_options)
    # ^^^^^ THIS PART
  end
end
```

You see it?! `live()` is calling this function:

```elixir
Phoenix.Router.get("/my-route", Phoenix.LiveView.Plug, _action, _options)
```

You may recognize this as:

```elixir
get "/my-route", MyController, :show
```

in your own router. We're going to ignore the action and options for this post,
but the important part is that the `live()` macro is adding a GET route and
calls the `Phoenix.LiveView.Plug`

> But, that plug isn't a controller...
>
> -- you

Ah, but it is! A Phoenix Controller, even the ones you make, are indeed all just
plugs underneath. [**All Phoenix controllers are
plugs**](https://hexdocs.pm/phoenix/plug.html).

<a name="pluggy-controllers"></a>
## Pluggy Controllers

When your controllers call `use MyAppWeb, :controller`, it's _injecting code_
into your controller at compile-time. Let's explore how that works.

First at step 0 we need to understand that when Elixir code calls `use
MyUsingModule` it's actually calling `MyUsingModule.__using__(opts)` at
compile-time, and that resulting code is put into the module that called it.
Knowing that, let's follow the `use` trail.

Starting at the top in our own code:

```elixir
######################################
### Inside MyAppWeb.PageController ###
######################################

defmodule MyAppWeb.PageController do
  use MyAppWeb, :controller

  def home(conn, _) do
    render(conn, "home.html")
  end
end

#######################
### Inside MyAppWeb ###
#######################

defmacro __using__(which) when is_atom(which) do
  apply(__MODULE__, which, [])
end

def controller do
  quote do
    # vvv let's look in here vvv
    use Phoenix.Controller, namespace: MyAppWeb
    # ^^^ let's look in here ^^^
  end
end


#################################
### Inside Phoenix.Controller ###
#################################

defmacro __using__(opts) do
  quote bind_quoted: [opts: opts] do
    import Phoenix.Controller

    # vvv let's look in here vvv
    use Phoenix.Controller.Pipeline, opts
    # ^^^ let's look in here ^^^

    if Keyword.get(opts, :put_default_views, true) do
      plug :put_new_layout, {Phoenix.Controller.__layout__(__MODULE__, opts), :app}
      plug :put_new_view, Phoenix.Controller.__view__(__MODULE__)
    end
  end
end


##########################################
### Inside Phoenix.Controller.Pipeline ###
##########################################

defmacro __using__(opts) do
  quote bind_quoted: [opts: opts] do

    @behaviour Plug
    ## AHA! HERE'S YOUR CONTROLLER PLUG BEHAVIOUR

    require Phoenix.Endpoint
    import Phoenix.Controller.Pipeline

    Module.register_attribute(__MODULE__, :plugs, accumulate: true)
    @before_compile Phoenix.Controller.Pipeline
    @phoenix_log_level Keyword.get(opts, :log, :debug)
    @phoenix_fallback :unregistered

    @doc false
    def init(opts), do: opts

    @doc false
    def call(conn, action) when is_atom(action) do
      conn
      |> merge_private(
        phoenix_controller: __MODULE__,
        phoenix_action: action
      )
      # fun fact, this function below was introduced
      # ~6 years ago in Phoenix 0.5.0 and utilizes unhygienic functions.
      # (as in you're in deep macro-land and your normal rules don't apply)
      |> phoenix_controller_pipeline(action)
    end

    @doc false
    def action(%Plug.Conn{private: %{phoenix_action: action}} = conn, _options) do
      apply(__MODULE__, action, [conn, conn.params])
    end

    defoverridable init: 1, call: 2, action: 2
  end
end
```

Wow! Wild. All this means our slim controllers actually have a lot more code in
it than it appears, and that's ok because it makes working in Phoenix much more
convenient.

[All plugs must implement `call/2` which accepts a conn and returns a
conn](https://hexdocs.pm/plug/Plug.html). In our case, we're looking for a conn
that has some rendered HTML.

<a name="liveview-default-2"></a>
## Back to Default Phoenix LiveView without `render/1`

Now that we know that LiveViews are a `GET` request using a standard
controller/plug underneath, let's look at the `Phoenix.LiveView.Plug`. We're
still looking for how a LiveView gets to the template.

LiveView has a similar `__using__` code-path. Let's look at LiveView's plug:

```elixir
def call(%{private: %{phoenix_live_view: {view, opts}}} = conn, _) do
  opts = maybe_dispatch_session(conn, opts)

  # ...snip... there's a lot of code here we're going to skip
  conn
  |> Phoenix.Controller.put_layout(false)
  |> put_root_layout_from_router(opts)
  # this actually is piped into `Controller.live_render(view, opts)`
  # but I'm going to cut/paste what that ends up doing
  |> LiveView.Static.render(conn, view, opts)
  # ... more snipping...
  |> to_rendered_content_tag(socket, tag, view, attrs)
  # ... more snipping...
  |> view.render()  #<-- here here here!
end
```

Cool; this isn't anything new so far. This is just confirming that Phoenix
LiveView starts off as a regular HTTP request with a full HTML response. _How
does it render?_

We see that it's calling `view.render()` where `view` is our own LiveView, but
we didn't define `render/1` yet! Where's it coming from?

When we called `use MyAppWeb, :live_view` it kicked off a series of `__using__`,
which includes `use Phoenix.LiveView`. Inside `Phoenix.LiveView` it included a
`@before_compile Phoenix.LiveView.Renderer` hook. Let's check that out.

```elixir
render? = Module.defines?(env.module, {:render, 1})
root = Path.dirname(env.file)
filename = template_filename(env)
templates = Phoenix.Template.find_all(root, filename)

case {render?, templates} do
  {false, [template]} ->
    ext = template |> Path.extname() |> String.trim_leading(".") |> String.to_atom()
    engine = Map.fetch!(Phoenix.Template.engines(), ext)
    ast = engine.compile(template, filename)

    quote do
      @file unquote(template)
      @external_resource unquote(template)
      def render(var!(assigns)) do
        unquote(ast)
      end
    end
  # ... other clauses
end
```

Finally! This is where the default `render/1` function comes from. Before our
LiveView compiles, it checks to see if a `render/1` is defined, and if not, it
will drop one in for us. The default location for LiveView templates is right
next to the LiveView file itself. We see this from the `root = Path.dirname(env.file)`.

<a name="liveview-inline"></a>
## Phoenix LiveView with inline `render/1`

Another option is to implement `render/1` ourselves. [The docs make this pretty
clear how to do that](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#module-life-cycle).

```elixir
### lib/my_app_web/live/my_live.ex
defmodule MyAppWeb.MyLive do
  use MyAppWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # do stuff

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    ~L"""
    <p>Yo! I'm rendered from a <%= my_helper("vanilla") %> view</p>
    """
  end

  def my_helper("vanilla"), do: "whoops no this is actually live"
end
```

This feels the most similar to frontend frameworks such as Vue with
single-file-components (SFCs), or React.

This is a great option in case your LiveView doesn't have a lot of HTML. Perhaps
you're implementing a small widget. At some point, however, it becomes a little
crowded if you have a lot of business logic handling changes in the LiveView as
well as hundreds of lines of HTML and functions to conditionally render some
HTML or apply CSS classes; so you might consider separating the HTML out into
its own file.

<a name="liveview-external"></a>
## Phoenix LiveView with external `render/1`

```elixir
### lib/my_app_web/live/my_live.ex
defmodule MyAppWeb.MyLive do
  use MyAppWeb, :live_view

  @impl Phoenix.LiveView
  def mount(_params, _session, socket) do
    # do stuff

    {:ok, socket}
  end

  @impl Phoenix.LiveView
  def render(assigns) do
    MyAppWeb.MyView.render("my_live.html", assigns)
  end
end


### lib/my_app_web/views/my_view.ex
defmodule MyAppWeb.MyView do
  use MyAppWeb, :view

  def my_helper("vanilla"), do: "whoops no this is actually live"
end
```
```eex
<!-- lib/my_app_web/templates/my/my_live.html.leex -->
<p>Yo! I'm rendered from a <%= my_helper("vanilla") %> view</p>
<!-- this renders "whoops no this is actually live" instead of "vanilla" -->
```

If I have a lot of HTML helpers, then I tend to prefer separating that into a
View module. It's a little tedious to setup and separate the files, and then
jump between them when developing, but it's clear where functions should go.

This bugged me though, I have HTML floating in `./templates` and sometimes in
`./live` and sometimes inline. Can we consolidate?

Sure we can! `Phoenix.View` [provides an option to look for templates in a
different folder](https://hexdocs.pm/phoenix/1.5.13/Phoenix.View.html?#__using__/1).
Let's try it out. We need to supply `root` and `path` with `use Phoenix.View`:

```elixir
### lib/my_app_web/views/my_view.ex
defmodule MyAppWeb.MyView do
  use Phoenix.View,
    root: "lib/my_app_web/live",
    path: "",
    namespace: MyAppWeb
  # and all the other imports that come with `use MyAppWeb, :view`

  def my_helper("vanilla"), do: "whoops no this is actually live"
end
```
```eex
<!-- lib/my_app_web/live/my_live.html.leex -->
<p>Yo! I'm rendered from a <%= my_helper("vanilla") %> view</p>
<!-- this renders "whoops no this is actually live" instead of "vanilla" -->
```

It's exactly the same, except where the HTML is on disk and that we can't use
our `use MyAppWeb, :view` as-is anymore without some further adjustment. To
prove the concept though, copy out all the additional imports you find for views
in `my_app_web.ex` and place it here for now. If it works out, then you can add
another clause in `my_app_web.ex` to handle these kinds of views. Maybe
something like this.

```elixir
### lib/my_app_web.ex

def view_for_live do
  quote do
    use Phoenix.View,
      root: "lib/my_app_web/live",
      path: "",
      namespace: MyAppWeb

    # Import convenience functions from controllers
    import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

    # Use all HTML functionality (forms, tags, etc)
    use Phoenix.HTML

    import MyAppWeb.ErrorHelpers
    import MyAppWeb.Gettext
    import Phoenix.LiveView.Helpers
    import MyAppWeb.LiveHelpers
    alias MyAppWeb.Router.Helpers, as: Routes
  end
end

# and then use this instead for your LiveView-centric Views
### lib/my_app_web/views/my_view.ex
defmodule MyAppWeb.MyView do
  use MyAppWeb, :view_for_live

  def my_helper("vanilla"), do: "whoops no this is actually live"
end
```

## What about LiveComponents?

LiveComponents are totally ignored in this article. They're another great option
for organizing interactive partials from your LiveViews. Their rendering
strategy is very similar to LiveViews though, and most of this applies to them
as well.

Hope these tips help you out! If you have any more tips, tweet at me
[@bernheisel](https://twitter.com/bernheisel)

Thank you [zporter](https://zachporter.dev/) for helping me with the post by
proof-reading!
