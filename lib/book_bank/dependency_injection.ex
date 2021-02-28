defmodule BookBank.DI.Services do
  @services [
    {BookBank.AuthBehavior, BookBank.MongoAuth, :auth_service},
    {BookBank.DatabaseBehavior, BookBank.MongoDatabase, :database_service},
    {BookBank.ThumbnailBehavior, BookBank.ImageMagickThumbnail, :thumbnail_service},
    {BookBank.SearchBehavior, BookBank.ElasticSearch, :search_service},
    {BookBank.Auth.UserWhitelistBehavior, BookBank.Auth.UserWhitelist, :whitelist_service},
    {BookBankWeb.Utils.ChunkBehavior, BookBankWeb.Utils.Chunk, :chunk_service},
    {BookBankWeb.Utils.JwtBehavior, BookBankWeb.Utils.Jwt, :jwt_service},
    {Joken.CurrentTime, BookBankWeb.Utils.JwtTime, :time_service}
  ]

  defp behavior_to_mock(Joken.CurrentTime) do
    Test.StubTime
  end

  defp behavior_to_mock(behavior) do
    Regex.replace(
      ~r/^(.*)\.(.*)Behavior$/,
      behavior |> Atom.to_string(),
      "\\1.Mock\\2"
    )
    |> String.to_atom()
  end

  defmacro __using__(_opts) do
    service_asts =
      Enum.map(@services, fn {behavior, service, func_name} ->
        quote do
          @spec unquote(func_name)() :: atom()
          def unquote(func_name)() do
            if Application.get_env(:book_bank, :env) === :test do
              unquote(behavior_to_mock(behavior))
            else
              unquote(service)
            end
          end
        end
      end)

    service_list_ast =
      quote do
        @spec services() :: [{atom(), atom()}]
        def services() do
          if Application.get_env(:book_bank, :env) === :test do
            unquote(
              @services
              |> Enum.map(fn {behavior, _service, _fn_name} ->
                {behavior, behavior_to_mock(behavior)}
              end)
            )
          else
            unquote(
              @services
              |> Enum.map(fn {behavior, service, _fn_name} -> {behavior, service} end)
            )
          end
        end
      end

    [service_asts, service_list_ast]
  end
end

defmodule BookBank.DI do
  use BookBank.DI.Services
end
