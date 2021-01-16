defmodule Bern.LambdaTopicVote do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  alias Bern.{Cache, LambdaTopic}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "lambda_topic_vote" do
    field :ip, :string
    belongs_to :topic, LambdaTopic
  end

  def create(topic_id, ip) do
    case Cache.one(from t in LambdaTopic, where: t.id == ^topic_id and t.approved == true) do
      nil -> :error
      _topic ->
        %__MODULE__{}
        |> cast(%{topic_id: topic_id, ip: ip}, ~w[topic_id ip]a)
        |> unsafe_validate_unique([:topic_id, :ip], Cache)
        |> Cache.insert()
        |> case do
          {:ok, vote} ->
            {Phoenix.PubSub.broadcast(Bern.PubSub, "lambda", [:topic, :vote, vote, 1]), vote}
          error ->
            error
        end
    end
  end

  def delete(topic_id, ip) do
    __MODULE__
    |> where([q], q.topic_id == ^topic_id and q.ip == ^ip)
    |> Cache.one()
    |> case do
      nil ->
        :ok
      vote ->
        Cache.delete!(vote)
        Phoenix.PubSub.broadcast(Bern.PubSub, "lambda", [:topic, :vote, vote.topic_id, -1])
    end
  end

  def for(ip: ip) do
    __MODULE__
    |> where([q], q.ip == ^ip)
    |> Cache.all()
  end

  def for(topic_id: topic_id) do
    __MODULE__
    |> where([q], q.topic_id == ^topic_id)
    |> Cache.all()
  end
end
