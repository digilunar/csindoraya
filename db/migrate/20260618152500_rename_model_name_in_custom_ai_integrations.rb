class RenameModelNameInCustomAiIntegrations < ActiveRecord::Migration[7.0]
  def change
    rename_column :custom_ai_integrations, :model_name, :ai_model
  end
end
