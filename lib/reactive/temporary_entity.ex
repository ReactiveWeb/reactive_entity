defmodule Reactive.TemporaryEntity do
  defmacro __using__(_opts) do
    quote location: :keep do
      use Reactive.Entity

      def retrive(id) do
        :not_found
      end
      def save(id,state,container) do
      end
    end
  end
end