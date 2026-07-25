class CreateCustomAiIntegrations < ActiveRecord::Migration[7.0]
  def change
    create_table :custom_ai_integrations do |t|
      t.references :account, null: false, index: true
      t.string :endpoint_url
      t.string :api_key
      t.string :model_name
      t.text :system_prompt

      t.timestamps
    end
  end
end
