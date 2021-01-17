defmodule Bern.LambdaTopic do
  use Ecto.Schema
  import Ecto.Changeset
  alias Bern.{Cache, LambdaTopicVote}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lambda_topic" do
    field :topic, :string
    field :approved, :boolean, default: false
    field :covered, :boolean, default: false
    field :suggested_at, :utc_datetime
    has_many :votes, LambdaTopicVote, foreign_key: :topic_id
    field :votes_count, :integer, default: 0, virtual: true
  end

  @one_kb 1024
  def changeset(params) do
    %__MODULE__{}
    |> cast(params, ~w[suggested_at topic]a)
    |> validate_required(~w[topic suggested_at]a)
    |> unsafe_validate_unique(:topic, Cache, message: "is already a topic")
    |> validate_length(:topic, max: @one_kb)
  end

  def all() do
    __MODULE__
    |> Cache.all()
    |> Cache.preload(:votes)
    |> Enum.map(fn topic -> %{topic | votes_count: length(topic.votes)} end)
    |> Enum.sort_by(& &1.suggested_at, {:asc, DateTime})
    |> Enum.sort_by(& &1.votes_count, :desc)
  end

  def approve(topic) do
    topic
    |> cast(%{approved: true}, ~w[approved]a)
    |> Cache.update()
    |> case do
      {:ok, topic} ->
        Phoenix.PubSub.broadcast(Bern.PubSub, "lambda", [:topic, :update, topic])
      error ->
        error
    end
  end

  def cover(topic) do
    topic
    |> cast(%{covered: true}, ~w[covered]a)
    |> Cache.update()
    |> case do
      {:ok, topic} ->
        LambdaTopicVote.for(topic_id: topic.id) |> Enum.each(&Cache.delete/1)
        Phoenix.PubSub.broadcast(Bern.PubSub, "lambda", [:topic, :update, topic])
      error ->
        error
    end
  end

  def create(topic_param) do
    %{topic: topic_param, suggested_at: DateTime.utc_now()}
    |> changeset()
    |> Cache.insert()
    |> case do
      {:ok, topic} ->
        Phoenix.PubSub.broadcast(Bern.PubSub, "lambda", [:topic, :new, topic])
      error ->
        error
    end
  end
end
