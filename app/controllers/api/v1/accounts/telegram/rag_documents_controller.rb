# frozen_string_literal: true

module Api
  module V1
    module Accounts
      module Telegram
        class RagDocumentsController < ApplicationController
          before_action :check_authorization
          before_action :ensure_telegram_rag_enabled

          def index
            @documents = current_account.telegram_rag_documents.ordered
          end

          def create
            @document = current_account.telegram_rag_documents.build!(document_params)
            process_document
          end

          def show
            @document = current_account.telegram_rag_documents.find(params[:id])
          end

          def destroy
            @document = current_account.telegram_rag_documents.find(params[:id])
            @document.destroy
            head :no_content
          end

          def bulk_upload
            files = params[:files]
            raise ArgumentError, 'No files provided' unless files.is_a?(Array) && files.any?

            uploaded = []
            failed = []

            files.each do |file|
              document = current_account.telegram_rag_documents.build(
                name: file.original_filename,
                file_type: file.content_type,
                file: file
              )

              if document.save
                Telegram::RagDocumentProcessorJob.perform_later(document.id)
                uploaded << { id: document.id, name: document.name }
              else
                failed << { name: file.original_filename, errors: document.errors.full_messages }
              end
            end

            render json: { uploaded: uploaded, failed: failed }, status: :ok
          end

          private

          def ensure_telegram_rag_enabled
            return if current_account.feature_enabled?('telegram_rag')

            render json: { error: 'Telegram RAG feature is not enabled for this account' }, status: :forbidden
          end

          def check_authorization
            raise Pundit::NotAuthorizedError unless current_user
          end

          def document_params
            params.require(:document).permit(:name, :file, :content, :file_type)
          end

          def process_document
            Telegram::RagDocumentProcessorJob.perform_later(@document.id)
            render json: { id: @document.id, name: @document.name, status: 'processing' }, status: :created
          end
        end
      end
    end
  end
end