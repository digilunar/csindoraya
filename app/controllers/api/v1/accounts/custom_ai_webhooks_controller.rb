class Api::V1::Accounts::CustomAiWebhooksController < ActionController::API
  def create
    event = params[:event]
    
    if event == 'message_created' && params[:message_type] == 'incoming'
      account_id = params.dig(:account, :id) || params[:account_id]
      conversation_id = params.dig(:conversation, :id)
      message_content = params[:content]
      
      # Process asynchronously to not block the webhook response
      Rag::CustomAiResponseJob.perform_later(account_id, conversation_id, message_content)
    end
    
    render json: { status: 'success' }
  end
end
