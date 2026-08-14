class AddBotResponseToMessageIdToMessages < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    add_column :messages, :bot_response_to_message_id, :integer
    add_index :messages, [:conversation_id, :bot_response_to_message_id],
              unique: true,
              where: 'bot_response_to_message_id IS NOT NULL',
              name: 'index_messages_on_conversation_and_bot_response',
              algorithm: :concurrently
  end
end
