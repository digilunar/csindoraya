class Whatsapp::IncomingMessageLunarsenderService
  include ::Whatsapp::IncomingMessageServiceHelpers

  pattr_initialize [:inbox!, :params!]

  def perform
    return if params[:message].blank? || params[:participant].blank?

    # participant looks like "62899999999@s.whatsapp.net" or "62899999999@g.us"
    # For now we'll just parse the number
    @sender_number = params[:participant].split('@').first
    # Ensure it has +
    @sender_number = "+#{@sender_number}" unless @sender_number.start_with?('+')

    @contact = ContactBuilder.new(
      source_id: @sender_number,
      inbox: inbox,
      contact_attributes: {
        name: params[:pushName].presence || @sender_number,
        phone_number: @sender_number
      }
    ).perform

    return unless @contact

    ActiveRecord::Base.transaction do
      set_conversation
      create_message
    end
  end

  private

  def set_conversation
    @contact_inbox = @contact.contact_inboxes.find_by!(inbox_id: inbox.id)
    @conversation = if inbox.lock_to_single_conversation
                      @contact_inbox.conversations.last
                    else
                      @contact_inbox.conversations.where.not(status: :resolved).last
                    end
    return if @conversation

    @conversation = ::Conversation.create!(
      inbox_id: inbox.id,
      contact_inbox_id: @contact_inbox.id,
      account_id: inbox.account_id
    )
  end

  def create_message
    # Use AllData.key.id if present as the source_id, otherwise generate one
    source_id = params.dig('AllData', 'key', 'id') || SecureRandom.uuid

    # Prevent duplicate messages
    return if Message.find_by(source_id: source_id)

    @message = @conversation.messages.build(
      content: params[:message],
      account_id: inbox.account_id,
      inbox_id: inbox.id,
      message_type: params[:fromMe] ? :outgoing : :incoming,
      status: :sent,
      sender: params[:fromMe] ? nil : @contact,
      source_id: source_id
    )

    # Attach any media
    if params[:mediaUrl].present? && params[:messageType] != 'text'
      attach_file(params[:mediaUrl])
    end

    @message.save!
  end

  def attach_file(url)
    begin
      attachment_file = Down.download(url)
      @message.attachments.new(
        account_id: @message.account_id,
        file_type: :image,
        file: {
          io: attachment_file,
          filename: attachment_file.original_filename,
          content_type: attachment_file.content_type
        }
      )
    rescue StandardError => e
      Rails.logger.error "Lunarsender attachment download failed: #{e.message}"
    end
  end
end
