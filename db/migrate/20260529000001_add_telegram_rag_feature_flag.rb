# frozen_string_literal: true

class AddTelegramRagFeatureFlag < ActiveRecord::Migration[7.0]
  def change
    # Add feature flag for Telegram RAG
    # FeatureFlag.add_feature(:telegram_rag, default: false)
  end
end