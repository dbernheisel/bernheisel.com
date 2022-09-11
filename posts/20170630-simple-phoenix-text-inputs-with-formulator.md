%{
  title: "Simple Phoenix Text Inputs with Formulator",
  tags: ["elixir"],
  canonical_url: "https://robots.thoughtbot.com/simple-phoenix-text-inputs-with-formulator",
  description: """
  Ugh... three lines for a simple text input for a form in Phoenix? How about
  one with Formulator?
  """
}
---

Ugh... three lines for a simple text input for a form in Phoenix? How about one
with Formulator?

tldr:

instead of

```elixir
<%= label form, :email_address %>
<%= email_input form, :email_address %>
<%= error_tag form, :email_address %>

<%= label form, :first_name %>
<%= text_input form, :first_name %>
<%= error_tag form, :first_name %>

<%= label form, :last_name %>
<%= text_input form, :last_name %>
<%= error_tag form, :last_name %>
```

do this with Formulator:

```elixir
<%= input form, :email_address, as: :email %>
<%= input form, :first_name %>
<%= input form, :last_name %>
```
<!--excerpt-->

[Platformatec has a great post about dynamic forms with
Phoenix](http://blog.plataformatec.com.br/2016/09/dynamic-forms-with-phoenix/)
that teaches developers how to extract some common steps out to their own
functions.  This is helpful because developers can skip the tedious parts that
they tend to repeat, which also helps keep style consistent across a larger
framework for an application.

Other times, developers don't need (or want) to build CSS classes into the
back-end, or they want to give more flexibility to designers later, or they just
don't want to start from scratch again when they start another application.
(It's hard to find that balance sometimes, isn't it?)

Enter: [Formulator](https://hexdocs.pm/formulator/index.html)

Formulator brings some simplicity to making form inputs for Phoenix, while still
giving the developer some customization options.

For example, need a specific class for an input field?

```elixir
<%= input form, :email_address, as: :email, class: "magical-email-input" %>
```

or need to class up a label?

```elixir
<%= input form, :email_address, as: :email, class: "magical-email-input", label: [class:
"magical-email-label" %>
```

If you're a Rails developer and new to Phoenix, you'll soon discover that
Phoenix tries to get the form errors closer to the input tags themselves, as
opposed to Rails where error messages are typically flashed near the top of a
page. Getting used to this difference is like putting my toothbrush on the other
side of the sink, I tend to forget the `error_tag` when making a new form and
wonder for about 5 minutes why my test can't find the error text I'm expecting.
Formulator saves me some keystrokes and keeps me from forgetting error tags.

We made Formulator because we realized we were repeating ourselves waaaay too
much for simple stuff. It's a ridiculously simple library (just check out the
[source code](https://github.com/thoughtbot/formulator)). Give it and try and
let us know what you think!
