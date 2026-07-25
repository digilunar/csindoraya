class CreateRagBots < ActiveRecord::Migration[7.0]
  def change
    create_table :rag_bots do |t|
      t.string :name, null: false
      t.text :rag_knowledge
      t.string :ai_endpoint_url
      t.string :webhook_token, null: false
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
    add_index :rag_bots, :webhook_token, unique: true
  end
end
