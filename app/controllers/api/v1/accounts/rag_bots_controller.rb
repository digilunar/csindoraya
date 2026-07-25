class Api::V1::Accounts::RagBotsController < Api::V1::Accounts::BaseController
  before_action :fetch_rag_bot, only: [:show, :update, :destroy]

  def index
    @rag_bots = Current.account.rag_bots
  end

  def show
  end

  def create
    @rag_bot = Current.account.rag_bots.new(rag_bot_params)
    if @rag_bot.save
      render 'api/v1/accounts/rag_bots/show', status: :created
    else
      render json: { error: @rag_bot.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @rag_bot.update(rag_bot_params)
      render 'api/v1/accounts/rag_bots/show', status: :ok
    else
      render json: { error: @rag_bot.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def destroy
    @rag_bot.destroy
    head :ok
  end

  private

  def fetch_rag_bot
    @rag_bot = Current.account.rag_bots.find(params[:id])
  end

  def rag_bot_params
    params.require(:rag_bot).permit(:name, :rag_knowledge, :ai_endpoint_url, :use_general_ai_setting)
  end
end
