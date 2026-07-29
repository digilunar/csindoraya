class AddUseGeneralAiSettingToRagBots < ActiveRecord::Migration[7.0]
  def change
    add_column :rag_bots, :use_general_ai_setting, :boolean, default: false
  end
end
