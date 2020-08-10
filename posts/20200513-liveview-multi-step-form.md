%{
  title: "Phoenix LiveView: Multi-step forms",
  tags: ["elixir", "ecto", "phoenix"],
  description: """
  Big forms are a pain to manage-- even harder to manage when you need to change
  values based on previous input and compute data based on that new selection.
  Phoenix LiveView can make this easier. Check out some techniques I used to
  help organize these forms.
  """
}
---

[Phoenix LiveView] has been a dream to work with so far. I *really* recommend
looking at it for your next web application. Building Tailwind, Elixir, and
Phoenix LiveView with some Vue sprinklings has been the most enjoyable tech
stack I've used in a long while.

[Phoenix LiveView]: https://github.com/phoenixframework/phoenix_live_view

One of the benefits I love about LiveView is that it enables me to consolidate
some of common front-end logic into the backend, where the source of truth
belongs. A great example is a form, especially long-running or multi-step forms.

Let me show you what I mean.

<video controls="true" src="/video/long-form-demo.mp4" width="auto" height="auto" preload="auto" muted="true" title="Demo of Multi-step form"></video>

This is accomplished without any AJAX calls, no SPAs, and no page reloads.

I coded this form twice. Let me share with you my journey and some techniques I
used to help organize code.

## The Ugly Way (First pass)

I coded it all with a single LiveView.

It become quite ugly.

I was still trying to figure out what I wanted on the form and still learning
LiveView generally. Eventually, this LiveView became an ugly 1000+-line horror
show that managed state in multiple places.

It was a single `<form>` that handled all the fields for the database-backed
record, and each step was hidden until you hit "next", so every change in the
form sends the entire form values.

The EEX was something like this:

```eex
<div class="container">
  <%= f = form_for(@changeset, phx_validate: :validate, phx_save: :save %>

  <div class="<%= unless @progress.name == "who", do: "hidden" %>">
    <%# my Who-related form inputs %>
  </div>

  <div class="<%= unless @progress.name == "what", do: "hidden" %>">
    <%# my What-related form inputs %>
  </div>

  <div class="<%= unless @progress.name == "when", do: "hidden" %>">
    <%# my When-related form inputs %>
  </div>

  </form>
</div>
```

I found that this approach has several drawbacks:

- When the user hits "enter", the form will try to submit. If you're on the
    first step, you probably don't want that to submitted yet until they're
    on the last step. You can override this with some JavaScript, but this
    non-standard behavior made things more complicated than it should be. I'll
    need the JavaScript to know which step is last, and track which step it's
    currently on. Ugh... I did this and it wasn't great. I wanted to delete
    myself.
- When the user is on a different step, you still need to manage all the "state"
    of other steps. This is a lot of "weight" to worry about and ensure
    _doesn't_ change.
- As soon as the user interacts with the form on the first step, validations
    will occur for the entire form, **even for those inputs on hidden steps**.
    This means errors will already be populated before the user even interacted
    with them.
- Testing the big form was difficult. The tools were great-- I just
    bad-developered and didn't break it down well.

Generally, I found it harder to "reason about", especially when I have computed
fields and help text based on user input.

For example, I need to persist two DateTimes with timezones, but I don't want to
present that to the user as `datetime_select`s and have them select a timezone
from a drop-down.

Instead I want a date picker, and then separately collect the times and merge it
with the user's detected timezone (this will later be improved to allow them to
select a timezone and prefer a user's set timezone while registering). Something
like this:

```eex
<%= date_select f, :date %>
<%= time_input f, :start_time %>
<%= time_input f, :end_time %>
Your duration is <%= @duration %>
```

so in my params, I would receive something like this:

```elixir
def handle_event("validate", %{"myform" => params}, socket) do
  IO.inspect params, label: "PARAMS"
  {:noreply, socket}
end

#=> PARAMS: %{
#  "date" => %{"year" => 2020, "month" => 1, "day" => 1},
#  "start_time" => "08:00",
# " end_time" => "10:00"
# }
```

There's a complicated mechanism in the time pickers that made it harder. I
needed to detect what changed:

1. Was it the `end_time`? Then let's extend the duration as well and accept the
   new `end_time`.
1. Was it the `start_time`? Then let's back the `end_time` up to the same
   duration away from the `start_time`.
1. At some point, if we accept user input for `duration`, then we we'd want to
   extend the `end_time` with the new duration.

Now I have some fields, I need to compute them into my event struct somehow.
This is how it needs to end up:

```elixir
record.start_at_tz #=> "America/New_York"
record.start_at_wall #=> ~N[2020-01-01T08:00:00]
record.start_at_utc #=> ~U[2020-01-01T13:00:00Z]

record.end_at_tz #=> "America/New_York"
record.end_at_wall #=> ~N[2020-01-01T10:00:00]
record.end_at_utc #=> ~U[2020-01-01T15:00:00Z]

record.duration #=> 7200 # seconds which is 2 hours
```

This is going to be a lot of work!

Let's not have the giant form all be in one template, or even partials; let's
split the form up into components. These components will let me manage these
computed fields easier, as well as solve some other UX issues mentioned above.

## Let's break it down:

- [Manage form progress in the parent LiveView.](#formprogress)
- [Split the multi-step form into LiveComponents. At least one for each visible step.](#extract)
- [Send input supplied client-side via `phx-hook`.](#clientside)
- [Handle input changes from the users from the component](#clientinput)
- [Handle stepped-form submission](#subformsubmission)
- [Handle final form submission.](#formsubmission)

<a aria-hidden="true" name="formprogress"></a>

## Managing the form progress

I managed the form step progress by defining a `%Step{}` and then writing the
order out in the liveview as a module attribute.

```elixir
defmodule MyAppWeb.EventLive.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."
  defstruct [:name, :prev, :next]
end

# in the liveview

defmodule MyAppWeb.EventLive.New do
  # ...snip...

  @steps [
    %Step{name: "who", prev: nil, next: "what"},
    %Step{name: "what", prev: "who", next: "when"},
    %Step{name: "when", prev: "what", next: "where"},
    %Step{name: "where", prev: "when", next: nil},
  ]

  def mount(_params, session, socket) do
    socket = authenticate(socket, session, [:with_organizations, :with_profile])
    first_step = List.first(@steps)
    event = %Event{}
    params = %{creator_id: socket.assigns.current_user.id}

    {:ok,
      socket
      |> assign(:event, event)
      |> assign(:params, params)
      |> assign(:changeset, Event.changeset(event, params))
      |> assign(:progress, first_step)}
  end

  # ...snip...
end
```

When the underlying live components are finished, they'll send a message to the
parent LiveView which will re-assign `:progress`; the conditionals in the
template will apply/remove the "hidden" class for the next appropriate step, or
previous step. You'll see that as you read on.

Let's chop up the form.

<a aria-hidden="true" name="extract"></a>

## Extract to LiveComponents

All this ugly-but-necessary logic should live in "form objects". In Ecto-land
these can be managed with embedded schemas. These form objects are responsible
for the state of their own fields, and compute their own values without
affecting other steps' values. The domain becomes much clearer.

When the form is submitted, it will trigger the "save" event from the
LiveComponent. The LiveComponent can then pass the completed params up to its
parent LiveView if the changeset is valid. The parent LiveView can track these
params separately, sitting on it until final save, persisted as a draft, or
whatever you need.

This has some benefits:

- form submission (hitting enter) no longer needs to override default behavior.
- isolates testing to it's own form and LiveComponent.
- your form's "domain" has clearer boundaries.
- user interaction and form validation makes more sense; only the visible form
    is "tainted" when the user changes it (opposed to it being tainted before
    the user even sees it).

The multi-step form now looks like this:

```eex
<div class="container">
  <div class="<%= unless @progress.name == "who", do: "hidden" %>">
    <%= live_component @socket, WhoComponent,
      id: "who",
      event: @event,
      current_user: @current_user
    %>
  </div>

  <div class="<%= unless @progress.name == "what", do: "hidden" %>">
    <%= live_component @socket, WhatComponent, id: "what", event: @event %>
  </div>

  <div class="<%= unless @progress.name == "when", do: "hidden" %>">
    <%= live_component @socket, WhenComponent,
      id: "when",
      event: @event,
      current_user: @current_user
    %>
  </div>

  <div class="<%= unless @progress.name == "where", do: "hidden" %>">
    <%= live_component @socket, WhereComponent,
      id: "where",
      submit_text: t("Create"),
      event: @event
    %>
  </div>
</div>
```

Let's focus on the `WhenComponent`.

Here's the big idea:

- Inside of the WhenComponent, we need our `embedded_schema` to represent and
    store the fields we care about on the step.

- When loading/updating the component itself, we're going to initialize the
    changeset with the fields from the record.

- When handling validation events, we're going to throw the params into the
    changeset and assign the new changeset back.

- The computed values will be updated from the changeset and/or pulled out of
    the changeset and assigned into the socket.

- When handling the save event, we're going to ensure the changeset is valid,
    and if so, tell the parent LiveView that we're good to proceed. We'll send
    the struct up to the parent LiveView. This struct will contain the computed
    fields so it should be easier for the parent to stitch these steps' params
    together into the final changeset that's actually persisted.

Again, the flow should look like this:

1. On mounting, take the Event and pluck the relevant fields out of it to create
   a WhenComponent form backed by an `embedded_schema`.
1. When the user is on the step, take the changes as they come and let the user
   iterate on the form until it's valid.
1. When the changeset is valid and the user tries to submit it, pass the final
   struct up to the parent LiveView. The parent LiveView can then switch to the
   next step.

Here is the component code:

```elixir
defmodule MyAppWeb.EventLive.WhenComponent do
  use MyAppWeb, :live_component
  alias Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :timezone, :string
    field :start_at_date, :date
    field :start_at_time, :time
    field :start_at, :utc_datetime  # Not on the form. This is computed

    field :end_at_date, :date
    field :end_at_time, :time
    field :end_at, :utc_datetime  # Not on the form. This is computed

    field :duration, :integer  # Not on the form. This is computed and displayed
  end

  @impl Phoenix.LiveComponent
  def update(assigns, socket) do
    whenevent = from_event(assigns.event, assigns.current_user.profile.timezone)
    params = %{}
    changeset = changeset(whenevent, params)

    {:ok,
      socket
      |> assign(assigns)
      |> assign(:when, whenevent)
      |> assign(:when_changeset, changeset)
      |> assign_computed(changeset)
    }
  end

  @impl Phoenix.LiveComponent
  def handle_event("validate", %{"when_component" => params}, socket) do
    adjusted_params = adjust_time_params(params, socket.assigns.when_changeset)
    changeset = changeset(socket.assigns.when, adjusted_params)

    {:noreply,
      socket
      |> assign(:when_changeset, changeset)
      |> assign_computed(changeset)
    }
  end

  @impl Phoenix.LiveComponent
  def handle_event("save", %{"when_component" => params}, socket) do
    socket.assigns.when
    |> changeset(params)
    |> Changeset.apply_action(:insert)
    |> case do
      {:ok, record} ->
        send(self(), {:proceed, record})
        {:noreply, socket}
      {:error, changeset} ->
        {:noreply,
          socket
          |> assign(:when_changeset, changeset)
          |> assign_computed(changeset)
        }
    end
  end

  @impl Phoenix.LiveComponent
  def handle_event("timezone", detected_timezone, socket) do
    params = Map.put(socket.assigns.when_changeset.params, "timezone", detected_timezone)
    changeset = changeset(socket.assigns.when_changeset, params)
    {:noreply,
      socket
      |> assign(:when_changeset, changeset)
      |> assign_computed(changeset)
    }
  end

  @fields ~w[timezone start_at_date start_at_time end_at_date end_at_time duration]a
  def changeset(whenevent, params) do
    whenevent
    |> Changeset.cast(params, @fields)
    |> put_stitched_datetime(:start_at)
    |> put_stitched_datetime(:end_at)
    |> ensure_duration()
  end

  defp put_stitched_datetime(changeset, field) do
    timezone = Changeset.get_field(changeset, :timezone)
    date = Changeset.get_field(changeset, :"#{field}_date")
    time = Changeset.get_field(changeset, :"#{field}_time", ~T[00:00:00])
    {:ok, ndt} = NaiveDateTime.new(date, time)

    Changeset.put_change(changeset, field, DateTime.from_naive!(ndt, timezone))
  end

  def from_event(event, profile_timezone) do
    %__MODULE__{timezone: event.start_at_tz || profile_timezone || "Etc/UTC"}
    |> put_start_at_date(to_date(event.start_at))
    |> put_start_at_time(to_time(event.start_at))
    |> put_end_at_date(to_date(event.end_at))
    |> put_end_at_time(to_time(event.end_at))
    |> put_end_at(event.end_at)
    |> put_start_at(event.start_at)
    |> put_duration(calc_duration(event.start_at, event.end_at))
  end

  defp ensure_duration(changeset) do
    if Changeset.get_field(changeset, :duration) do
      changeset
    else
      start_at = Changeset.get_field(changeset, :start_at)
      end_at = Changeset.get_field(changeset, :end_at)
      Changeset.put_change(changeset, :duration, calc_duration(start_at, end_at))
    end
  end

  defp assign_computed(socket, changeset) do
    # I need the start_at for the DatePicker component that I render from this
    # component. I render the timezone and duration on the form. Lastly I
    # compute and render some autocomplete suggestions from the values in the
    # changeset.
    socket
    |> assign(:timezone, Changeset.get_field(changeset, :timezone))
    |> assign(:start_at, Changeset.get_field(changeset, :start_at))
    |> assign(:duration, Changeset.get_field(changeset, :duration))
    |> assign(:start_time_autocomplete, start_autocompletes(changeset))
    |> assign(:end_time_autocomplete, end_autocompletes(changeset))
  end

  # I'll leave some of these helper functions out, but they're essentially
  # providing nil-safety, applying defaults, and calculating from other fields
end
```


<a aria-hidden="true" name="clientside"></a>

## Getting the user's timezone with `phx-hook`

We can estimate what the user's timezone is by asking the browser. **NOTE** _I
don't recommend you use this as your only source of user timezone._ Use this as
an example for how to get JavaScript-sourced input

Let's get the timezone. We'll need some JavaScript.

```javascript
window.userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone

// initialize the Phoenix LiveView socket, and pass this in as a hook:

hooks.UserTimeZone = {
  mounted() {
    const phoenix = this;
    const target = this.el.dataset.phoenixTarget;
    const els = phoenix.el.querySelectorAll("input")
    for (let el of els) { el.value = window.userTimezone; }
    phoenix.pushEventTo(target, "timezone", window.userTimezone)
  }
}
```

```eex
<%# Timezone in the WhenComponent form %>
<div phx-hook="UserTimeZone" data-phoenix-target="#<%= @id %>" id="user-time-zone">
  <div phx-update="ignore">
    <%= hidden_input f, :timezone %>
  </div>
</div>
```

When the page is rendered, I'll get a `hidden_input` populated with the detected
timezone. This will be included in further form changes and params sent to the
LiveView process. Remember to wrap it with a `phx-update="ignore"` so the
JavaScript-mutated value isn't overwritten by LiveView.

You'll notice that I'm also using `pushEventTo` after mounting. This is needed
because the user may not have interacted with the form yet to trigger a change,
so until then, I won't have user's timezone! I want it pushed immediately so I
can update the form's changeset. Also, `pushEventTo` is used instead of
`pushEvent` because this is a LiveComponent, so I want the event pushed to the
LiveComponent and not the parent LiveView. I pass the target in via a data
attribute so I don't confuse it with Phoenix's own `phx-target`.

When handling the event, we'll merge the timezone with the existing params of
the changeset, and then re-apply the changeset and re-compute fields.

```elixir
@impl Phoenix.LiveComponent
def handle_event("timezone", detected_timezone, socket) do
  params = Map.put(socket.assigns.when_changeset.params, "timezone", detected_timezone)
  changeset = changeset(socket.assigns.when_changeset, params)
  {:noreply,
    socket
    |> assign(:when_changeset, changeset)
    |> assign_computed(changeset)
  }
end
```

<a aria-hidden="true" name="clientinput"></a>

## Handling sub-form change events

Handling form change events doesn't change with this `embedded_schema` and
component-ized approach. It's standard Phoenix and Ecto changeset forms, so it's
not very interesting to look at. But remember that you'll need to use
`phx-target` to send  changes to the LiveComponent, otherwise they may bubble up
to your parent LiveView.

In my case, I also need to adjust the parameters that come in, so we'll look at
that! I need to check to see what field is changing and apply new parameters
based on what is changing.

```elixir
@impl Phoenix.LiveComponent
def handle_event("validate", %{"when_component" => params}, socket) do
  adjusted_params = adjust_time_params(params, socket.assigns.when_changeset)
  changeset = changeset(socket.assigns.when, adjusted_params)

  {:noreply,
    socket
    |> assign(:when_changeset, changeset)
    |> assign_computed(changeset)
  }
end

defp assign_computed(socket, changeset) do
  # I need the start_at for the DatePicker component that I render from this
  # component. I render the timezone and duration on the form. Lastly I
  # compute and render some autocomplete suggestions from the values in the
  # changeset
  socket
  |> assign(:timezone, Changeset.get_field(changeset, :timezone))
  |> assign(:start_at, Changeset.get_field(changeset, :start_at))
  |> assign(:duration, Changeset.get_field(changeset, :duration))
  |> assign(:start_time_autocomplete, start_autocompletes(changeset))
  |> assign(:end_time_autocomplete, end_autocompletes(changeset))
end

defp adjust_time_params(params, changeset) do
  start_at_time = params_to_time(params["start_at_time"])
  end_at_time = params_to_time(params["end_at_time"])

  cond do
    end_at_time != Changeset.get_field(changeset, :end_at_time) ->
      params_from_new_end_time(start_at_time, end_at_time, params)

    start_at_time != Changeset.get_field(changeset, :start_at_time) ->
      duration = Changeset.get_field(changeset, :duration)
      params_from_new_start_time(start_at_time, duration, params)

    true ->
      params
  end
end
```

Remember, we're in a LiveComponent so we want to target the changes to itself
and not the parent LiveView. This is accomplished with `phx-target` on the form.

```eex
<%= f = form_for @when_changeset, "#",
  phx_change: :validate,
  phx_target: "##{@id}",
  phx_submit: :save,
  id: @id %>

  <%# ... timezone input mentioned above ... %>

  <%= date_select f, :date %>
  <%= time_input f, :start_time %>
  <%= time_input f, :end_time %>
  Your duration is <%= @duration %>

</form>
```

<a aria-hidden="true" name="subformsubmission"></a>

## Handling the sub-form submission

When the user tries to submit the form, either by hitting "enter" or clicking on
the submit button, I need to validate the form once again, and if it's good tell
the parent LiveView that it's ok to proceed and supply all the
helpfully-computed values.

This time we'll check if the changeset is valid with
[`Ecto.Changeset.apply_action/2`]. Based on that result, we'll let the
LiveComponent send a message to ~~itself~~. Actually, a LiveComponent doesn't
run in its own process, instead it's running inside the parent LiveView's
process. So `self()` is actually the LiveView and not the LiveComponent. This is
how we can send the parent LiveView the result!

You can [read more about LiveComponent and sources of truth in the docs](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveComponent.html#module-liveview-as-the-source-of-truth).

[`Ecto.Changeset.apply_action/2`]: https://hexdocs.pm/ecto/Ecto.Changeset.html#apply_action/2

```elixir
@impl Phoenix.LiveComponent
def handle_event("save", %{"when_component" => params}, socket) do
  socket.assigns.when
  |> changeset(params)
  |> Changeset.apply_action(:insert)
  |> case do
    {:ok, record} ->
      send(self(), {:proceed, record})
      {:noreply, socket}
    {:error, changeset} ->
      {:noreply,
        socket
        |> assign(:when_changeset, changeset)
        |> assign_computed(changeset)
      }
  end
end

# and caught in the parent LiveView:

@impl Phoenix.LiveView
def handle_info({:proceed, %MyAppWeb.EventLive.WhenComponent{} = form}, socket) do
  {:ok, start_at_wall} = NaiveDateTime.new(form.start_at_date, form.start_at_time)
  {:ok, end_at_wall} = NaiveDateTime.new(form.end_at_date, form.end_at_time)

  params = %{
    start_at_utc: form.start_at,
    start_at_wall: start_at_wall,
    start_at_tz: form.timezone,
    end_at_utc: form.end_at,
    end_at_wall: end_at_wall,
    end_at_tz: form.timezone
  }

  {:noreply,
    socket
    |> assign(:params, Map.merge(socket.assigns.params, params))
    |> assign_step(:next)
  }
end
```

<a aria-hidden="true" name="formsubmission"></a>

## Handling the overall form submission

You'll notice that I have a function `assign_step` above. Let's go to the parent
LiveView and figure out how to change steps, except on the last step we want to
persist. We'll look for the steps in the `@steps` module attribute, assign it,
and that should swap-out the form for the next one!

If there isn't a next step, then that must mean that we're finished, so we
should try to save.

```elixir
defmodule MyAppWeb.EventLive.Step do
  @moduledoc "Describe a step in the multi-step form and where it can go."
  defstruct [:name, :prev, :next]
end

defmodule MyAppWeb.EventLive.New do
  use MyAppWeb, :live_view
  alias Ecto.Changeset
  # ...snip...

  defp assign_step(socket, step) do
    if new_step = Enum.find(@steps, & &1.name == Map.get(socket.assigns.progress, step)) do
      assign(socket, :progress, new_step)
    else
      save(socket)
    end
  end

  def save(socket) do
    # remember we've merged all params together, so this should be the complete
    # picture.
    case Schedule.create_event(socket.assigns.params) do
      {:ok, event} ->
          socket
          |> put_flash(:info, t("Event Created"))
          |> push_redirect(to: Routes.live_path(socket, EventLive.Show, event.id))

      {:error, %Changeset{} = changeset} ->
         socket
         |> assign(:changeset, changeset)
         |> put_flash(:error, "There is an issue with what you filled in")
    end
  end

  @impl Phoenix.LiveView
  def handle_event("prev-step", _content, socket) do
    {:noreply, assign_step(socket, :prev)}
  end
end
```

```eex
<%= MyAppWeb.Components.secondary_button(t("Back"), phx_click: "prev-step") %>
<%= MyAppWeb.Components.primary_button(t("Next"), phx_disable_with: "...", submit: true) %>
```

Back buttons are easy too. Add `phx-click="prev-step"` and handle the event in
the same way, except using `:prev`. Make sure there's no back button on the
first step! (otherwise you'll mistakenly try to save).

## Conclusion

I hope this helps you out in your endeavors to tackle long and complicated
forms. Tweet me [@bernheisel] if you have suggestions or enjoyed this post!


## Update

You might want to persist a draft record in-between steps. This is a great idea!
If you do this, then you can leverage LiveView's `handle_params` to navigate to
the appropriate step depending on the draft's progress.

Also, some of my code examples aren't very good for managing existing resources.
Keep that in mind when developing your own multi-step form. This was written for
the context of _creating a new event_, and not editing an existing event.
Subscribe to my RSS feed to check for a new post that revisits this problem.

[@bernheisel]: https://twitter.com/bernheisel
