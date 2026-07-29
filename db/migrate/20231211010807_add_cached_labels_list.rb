class AddCachedLabelsList < ActiveRecord::Migration[7.0]
  def change
    add_column :conversations, :cached_label_list, :string
    Conversation.reset_column_information
    begin
      ActsAsTaggableOn::Taggable::Cache.included(Conversation)
    rescue NameError
      # Ignore on newer versions of acts-as-taggable-on where this was renamed/removed
    end
  end
end
