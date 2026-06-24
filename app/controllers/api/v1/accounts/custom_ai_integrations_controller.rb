class Api::V1::Accounts::CustomAiIntegrationsController < Api::V1::Accounts::BaseController
  before_action :check_admin_authorization?
  before_action :fetch_custom_ai_integration, only: [:show, :update]

  def show
    if @custom_ai_integration
      render json: @custom_ai_integration
    else
      render json: {}
    end
  end

  def create
    @custom_ai_integration = Current.account.build_custom_ai_integration(custom_ai_integration_params)
    if @custom_ai_integration.save
      render json: @custom_ai_integration
    else
      render json: { error: @custom_ai_integration.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def update
    if @custom_ai_integration.update(custom_ai_integration_params)
      render json: @custom_ai_integration
    else
      render json: { error: @custom_ai_integration.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  end

  def test
    endpoint = params[:endpoint_url]
    api_key = params[:api_key]
    model = params[:ai_model]
    system_prompt = params[:system_prompt]

    require 'net/http'
    require 'uri'

    uri = URI.parse(endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')

    request = Net::HTTP::Post.new(uri.request_uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = "Bearer #{api_key}" if api_key.present?

    payload = {}
    if endpoint.include?('api/generate')
      payload = { model: model, prompt: "helo", stream: false }
      payload[:system] = system_prompt if system_prompt.present?
    else
      payload = {
        model: model,
        stream: false,
        messages: [
          { role: 'system', content: system_prompt.presence || 'You are a helpful assistant.' },
          { role: 'user', content: 'helo' }
        ]
      }
    end

    request.body = payload.to_json

    begin
      response = http.request(request)
      if response.is_a?(Net::HTTPSuccess)
        parsed = JSON.parse(response.body)
        reply = endpoint.include?('api/generate') ? parsed['response'] : parsed.dig('choices', 0, 'message', 'content')
        render json: { success: true, reply: reply }
      else
        render json: { success: false, error: "HTTP Error #{response.code}: #{response.body}" }, status: :bad_request
      end
    rescue => e
      render json: { success: false, error: e.message }, status: :unprocessable_entity
    end
  end

  private

  def fetch_custom_ai_integration
    @custom_ai_integration = Current.account.custom_ai_integration
  end

  def custom_ai_integration_params
    params.require(:custom_ai_integration).permit(:endpoint_url, :api_key, :ai_model, :system_prompt)
  end
end
