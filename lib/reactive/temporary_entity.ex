defmodule Reactive.TemporaryEntity do
  defmacro __using__(_opts) do
    quote location: :keep do
      use Reactive.Entity

      def retrive(id) do
        :not_found
      end

      def save(id,state,container) do
      end

      @spec observe(entity::entity_ref(), what::term()) :: entity_ref()
      def observe(entity,what) do
        Reactive.Entity.sendToEntity entity, {:observe,what,self()}
        entity
      end

      @spec unobserve(entity::entity_ref(), what::term()) :: entity_ref()
      def unobserve(entity,what) do
        Reactive.Entity.sendToEntity entity, {:unobserve,what,self()}
        entity
      end
    end
  end
end