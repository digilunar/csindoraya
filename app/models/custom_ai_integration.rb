# == Schema Information
#
# Table name: custom_ai_integrations
#
#  id            :bigint           not null, primary key
#  api_key       :string
#  endpoint_url  :string
#  model_name    :string
#  system_prompt :text
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#  account_id    :bigint           not null
#
# Indexes
#
#  index_custom_ai_integrations_on_account_id  (account_id)
#
class CustomAiIntegration < ApplicationRecord
  belongs_to :account

  validates :endpoint_url, presence: true
end
