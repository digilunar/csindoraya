# frozen_string_literal: true

module Api
  module V1
    module Accounts
      module Rag
        class DocumentsController < Api::V1::Accounts::BaseController
          before_action :check_authorization
          before_action :ensure_rag_enabled

          def index
            @documents = current_account.rag_documents.ordered
            @documents = @documents.where(rag_bot_id: params[:rag_bot_id]) if params[:rag_bot_id].present?
            render json: @documents
          end

          def create
            @document = current_account.rag_documents.build(document_params)
            @document.uploaded_by_id = current_user.id
            @document.save!
            # Forward to Python Microservice
            begin
              file_path = params[:document][:file].tempfile.path
              filename = params[:document][:file].original_filename
              
              # Using curl as a reliable fallback to upload multipart/form-data
              result = `curl -s -X POST -F "file=@#{file_path};filename=#{filename}" http://172.17.0.1:8000/upload_document`
              parsed_result = JSON.parse(result)
              
              unless parsed_result["status"] == "success"
                Rails.logger.error "Python RAG Error: #{result}"
              end
            rescue => e
              Rails.logger.error "Failed to upload to Python RAG: #{e.message}"
            end
            
            @document.process if @document.respond_to?(:process)
            render json: { id: @document.id, name: @document.name, status: 'processing' }, status: :created
          end

          def show
            @document = current_account.rag_documents.find(params[:id])
            render json: @document
          end

          def destroy
            @document = current_account.rag_documents.find(params[:id])
            @document.destroy
            head :no_content
          end

          def bulk_upload
            files = params[:files]
            raise ArgumentError, 'No files provided' unless files.is_a?(Array) && files.any?

            scope = params[:scope] || 'account'
            rag_bot_id = params[:rag_bot_id]

            uploaded = []
            failed = []

            files.each do |file|
              document = current_account.rag_documents.build(
                name: file.original_filename,
                file: file,
                scope: scope,
                rag_bot_id: rag_bot_id
              )
              document.uploaded_by_id = current_user.id

              if document.save
                # Forward to Python Microservice
                begin
                  file_path = file.tempfile.path
                  filename = file.original_filename
                  
                  result = `curl -s -X POST -F "file=@#{file_path};filename=#{filename}" http://172.17.0.1:8000/upload_document`
                  parsed_result = JSON.parse(result)
                  
                  unless parsed_result["status"] == "success"
                    Rails.logger.error "Python RAG Error: #{result}"
                  end
                rescue => e
                  Rails.logger.error "Failed to upload to Python RAG: #{e.message}"
                end

                document.process if document.respond_to?(:process)
                uploaded << { id: document.id, name: document.name }
              else
                failed << { name: file.original_filename, errors: document.errors.full_messages }
              end
            end

            render json: { uploaded: uploaded, failed: failed }, status: :ok
          end

          private

          def ensure_rag_enabled
            return true
            # return if current_account.feature_enabled?('rag') || current_user.is_a?(SuperAdmin)
            #
            # render json: { error: 'RAG feature is not enabled for this account' }, status: :forbidden
          end

          def check_authorization
            raise Pundit::NotAuthorizedError unless current_user
          end

          def document_params
            params.require(:document).permit(:name, :file, :scope, :rag_bot_id)
          end
        end
      end
    end
  end
end