defmodule Reactive.RangeScaler do
  require Logger

  @main_table :entity_range_scaler
  @backup_tables [:entity_range_scaler_backup1,:entity_range_scaler_backup2]

  def get_node(id) do
    bid=Reactive.EntitiesDb.entity_db_id(id)
    node()
  end

  def get_backups(id) do
    []
  end

end