# == Schema Information
#
# Table name: rag_documents
#
#  id             :bigint           not null, primary key
#  file_type      :string           not null
#  last_error     :string
#  name           :string           not null
#  processed_at   :datetime
#  scope          :integer          default("account"), not null
#  status         :integer          default("pending"), not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  account_id     :integer
#  uploaded_by_id :integer
#
# Indexes
#
#  index_rag_documents_on_account_id  (account_id)
#  index_rag_documents_on_scope       (scope)
#  index_rag_documents_on_status      (status)
#

class Rag::Document < ApplicationRecord
  self.table_name = 'rag_documents'

  belongs_to :account, optional: true
  belongs_to :uploaded_by, class_name: 'User', foreign_key: 'uploaded_by_id', optional: true
  belongs_to :rag_bot, optional: true
  has_one_attached :file

  enum status: { pending: 0, processing: 1, completed: 2, failed: 3 }
  enum file_type: { text: 0, pdf: 1, excel: 2, csv: 3, image: 4 }
  enum scope: { account: 0, global: 1 }

  validates :name, presence: true
  validates :file, presence: true

  scope :ordered, -> { order(created_at: :desc) }
  scope :for_account, ->(account_id) { where(account_id: account_id).or(where(scope: :global)) }

  before_validation :set_file_type_from_content_type

  def process
    Rag::DocumentProcessorJob.perform_later(id, scope: scope, account_id: account_id)
  end

  private

  def set_file_type_from_content_type
    return unless file.attached?

    ct = file.content_type
    self.file_type = if ct == 'application/pdf'
                       'pdf'
                     elsif ct.start_with?('text/')
                       'text'
                     elsif ct.include?('excel') || ct.include?('spreadsheetml')
                       'excel'
                     elsif ct == 'text/csv'
                       'csv'
                     elsif ct.start_with?('image/')
                       'image'
                     else
                       'text'
                     end
  end
end
