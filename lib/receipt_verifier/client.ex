defmodule ReceiptVerifier.Client do
  @moduledoc false

  alias ReceiptVerifier.Error
  alias Poison.Parser, as: JSONParser

  @endpoints [
    production: 'https://buy.itunes.apple.com/verifyReceipt',
    sandbox: 'https://sandbox.itunes.apple.com/verifyReceipt'
  ]

  @doc """
  Send the iTunes receipt to Apple Store, and parse the response as map
  """
  @spec request(String.t, ReceiptVerifier.options) :: {:ok, map} | {:error, any}
  def request(receipt, opts \\ []) do
    with(
      {:ok, {{_, 200, _}, _, body}} <- do_request(receipt, opts),
      {:ok, json} <- JSONParser.parse(body)
    ) do
      {:ok, json}
    else
      {:error, :invalid} ->
        # Poison error
        {:error, %Error{code: 502, message: "The response from Apple's Server is malformed"}}
      {:error, {:invalid, msg}} ->
        # Poison error
        {:error, %Error{code: 502, message: "The response from Apple's Server is malformed: #{msg}"}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_request(receipt, opts) do
    env = Keyword.get(opts, :env, :production)
    url = get_endpoint_url(env)

    request_body = prepare_request_body(receipt, opts)
    content_type = 'application/json'
    request_headers = [
      {'Accept', 'application/json'}
    ]

    :httpc.request(:post, {url, request_headers, content_type, request_body}, [], [])
  end

  defp get_endpoint_url(env) when env in [:sandbox, :production] do
    @endpoints
    |> Keyword.get(env)
  end

  defp prepare_request_body(receipt, opts) do
    %{
      "receipt-data" => receipt
    }
    |> maybe_set_password(opts)
    |> maybe_set_exclude_old_transactions(opts)
    |> Poison.encode!
  end

  defp maybe_set_password(data, opts) do
    case Keyword.get(opts, :password) do
      nil ->
        data
      password ->
        data
        |> Map.put("password", password)
    end
  end

  defp maybe_set_exclude_old_transactions(data, opts) do
    case Keyword.get(opts, :exclude_old_transactions) do
      nil ->
        data
      exclude_old_transactions ->
        data
        |> Map.put("exclude-old-transactions", exclude_old_transactions)
    end
  end
end
