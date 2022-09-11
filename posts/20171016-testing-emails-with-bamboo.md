%{
  title: "Testing Random Data in Emails with Bamboo",
  tags: ["elixir"],
  canonical_url: "https://robots.thoughtbot.com/testing-emails-with-bamboo",
  description: """
  Testing a scenario where an app sends an email is easy, but how do you
  test something random in an email, like a password reset token? When we
  test a function that intentionally returns random data, it's a little
  tougher.
  """
}
---

Testing a scenario where an app sends an email is easy, but how do you
test something random in an email, like a password reset token? When we
test a function that intentionally returns random data, it's a little
tougher.

In those times, we often tackle the problem by:

1. Testing behavior and static data, ignoring the dynamic data.
2. Using a mock to rid the randomized data, and then test everything.

Let's walk through how to do this with
[Bamboo](https://github.com/thoughtbot/bamboo).

Bamboo provides test helpers to help you assert behavior and data in
your app. A really common email scenario is sending users password reset
links. The idea behind these reset links is that they're _secure_ and
_unique_, and we ensure this by generating a random token and signing it
with user's data to make it secure. How do we test this then?

There are two ways!

## Use regex to cover the static text and skip dynamic text.

Here we are testing the behavior and static data, ignoring the dynamic
data.  Bamboo provides `assert_email_delivered_with()` which accepts a
keyword list of parts of the email, and what those parts should match.
We can match the email entirely by supplying a string like `[subject:
"Password reset link for MyApp"]`, or we can supply a regex, `[text:
~r/reset_token=/)`, and the assertion will check if the regex matches.

Here's a fuller integration test example:

```elixir
test "customers can request a password reset link", %{session: session} do
  customer = insert(:customer)
  session =
    session
    |> visit(password_reset_path(MyApp.Endpoint, :new))
    |> fill_in(:password_reset, :email, with: customer.email)
    |> click_on("Send link")

  assert_email_delivered_with(subject: "Password reset link for MyApp")
  assert_email_delivered_with(text_body: ~r/reset_token=/)
  assert_email_delivered_with(html_body: ~r/reset_token=/)
end
```

## Use a mock to rid the random data, and test the whole thing!

Here you can guarantee the behavior and (mocked) data, but it's a little
more setup.

Here's an example:

```elixir
# lib/mock_token_generator.ex
defmodule MyApp.MockTokenGenerator do
  @token "123"

  # This should match the interface of the real TokenGenerator
  def generate, do: @token

  # We're going to expose this in the mock so we can get the assertion
  # right
  def token, do: @token
end


# config/config.exs
config :my_app, token_generator: MyApp.TokenGenerator


# config/test.exs
config :my_app, token_generator: MyApp.MockTokenGenerator


# web/controllers/password_reset_controller.ex
defmodule MyApp.PasswordResetController do
  @generator Application.get_env(:my_app, :token_generator)

  def create(conn, params) do
    #...
    # use the @generator.generate function
    # do your email thing
    #...
  end
end


# test/features/password_reset_test.exs
# ...
alias MyApp.MockTokenGenerator

test "customers can request a password reset link", %{session: session} do
  customer = insert(:customer)
  session =
    session
    |> visit(password_reset_path(MyApp.Endpoint, :new))
    |> fill_in(:password_reset, :email, with: customer.email)
    |> click_on("Send link")

  assert_email_delivered_with(subject: "Password reset link for MyApp")
  assert_email_delivered_with(text_body: """
    Here's the entire body of the text email. You might test the entire
    text version of the email, and use regex to test the HTML version

    Here's your password reset link: https://myapp.com/password?reset_token=#{MockTokenGenerator.token}
  """)
  assert_email_delivered_with(html_body: ~r|https://myapp.com/password?reset_token=#{MockTokenGenerator.token}|)
end
```

See? [Bamboo](https://github.com/thoughtbot/bamboo) makes it easy. Give
it a shot and let us know what you think.
