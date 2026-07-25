# frozen_string_literal: true

module Api
  module V1
    class RagKnowledgeController < ApplicationController
      before_action :check_authorization
      before_action :ensure_rag_enabled

      def index
        @knowledge = if current_user.super_admin?
                       Rag::KnowledgeEntry.all
                     else
                       Rag::KnowledgeEntry.for_account(current_account.id)
                     end.ordered.limit(100)
      end

      def create
        @entry = Rag::KnowledgeEntry.new(knowledge_params)
        @entry.account_id = current_user.super_admin? ? nil : current_account.id
        @entry.uploaded_by = current_user
        @entry.save!
        render json: @entry, status: :created
      end

      def update
        @entry = Rag::KnowledgeEntry.find(params[:id])
        raise Pundit::NotAuthorizedError unless @entry.can_edit?(current_user)

        @entry.update!(knowledge_params)
        render json: @entry
      end

      def destroy
        @entry = Rag::KnowledgeEntry.find(params[:id])
        raise Pundit::NotAuthorizedError unless @entry.can_edit?(current_user)

        @entry.destroy
        head :no_content
      end

      def search
        query = params[:q]
        raise ArgumentError, 'Query required' unless query.present?

        knowledge_base = Rag::KnowledgeBase.new(account_id: current_account.id)
        results = knowledge_base.search(query, limit: 10)

        render json: { results: results.map { |r| { question: r.question, answer: r.answer, scope: r.scope } } }
      end

      private

      def ensure_rag_enabled
        return if current_account.feature_enabled?('rag') || current_user.super_admin?

        render json: { error: 'RAG feature is not enabled for this account' }, status: :forbidden
      end

      def check_authorization
        raise Pundit::NotAuthorizedError unless current_user
      end

      def knowledge_params
        params.require(:knowledge).permit(:question, :answer, :scope, metadata: {})
      end
    end
  end
end