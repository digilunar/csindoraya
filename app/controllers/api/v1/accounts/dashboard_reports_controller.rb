class Api::V1::Accounts::DashboardReportsController < Api::V1::Accounts::BaseController
  before_action :set_date_range

  def show
    if request.format.csv?
      send_data generate_chat_export_csv, filename: "chat_export_#{@start_date}_to_#{@end_date}.csv", type: 'text/csv'
    else
      render json: generate_dashboard_metrics
    end
  end

  private

  def set_date_range
    @start_date = params[:start_date].present? ? Time.zone.parse(params[:start_date]).beginning_of_day : 30.days.ago.beginning_of_day
    @end_date = params[:end_date].present? ? Time.zone.parse(params[:end_date]).end_of_day : Time.zone.now.end_of_day
  rescue ArgumentError
    @start_date = 30.days.ago.beginning_of_day
    @end_date = Time.zone.now.end_of_day
  end

  def base_conversations
    @base_conversations ||= Current.account.conversations.where(created_at: @start_date..@end_date)
  end

  def base_messages
    @base_messages ||= Current.account.messages.where(created_at: @start_date..@end_date).where.not(message_type: :activity)
  end

  def generate_dashboard_metrics
    # A. Executive Summary
    total_messages = base_messages.incoming.count
    total_users = base_conversations.select(:contact_id).distinct.count
    total_tickets = base_conversations.count
    resolved_conversations = base_conversations.resolved
    resolved_count = resolved_conversations.count
    resolved_rate = total_tickets > 0 ? (resolved_count.to_f / total_tickets * 100).round(2) : 0
    
    # Calculate SLA & Time metrics (simplified)
    # Average First Response Time (in seconds)
    frt_sum = resolved_conversations.where.not(first_reply_created_at: nil).sum("EXTRACT(EPOCH FROM (first_reply_created_at - created_at))")
    frt_count = resolved_conversations.where.not(first_reply_created_at: nil).count
    avg_first_response_time = frt_count > 0 ? (frt_sum / frt_count).to_i : 0

    # B. Volume
    messages_per_day = base_messages.unscope(:order).group('DATE(created_at)').count
    conversations_per_day = base_conversations.unscope(:order).group('DATE(created_at)').count

    # C & E. Helpdesk & Agent Analytics
    agent_stats = {}
    base_conversations.unscope(:order).group(:assignee_id).count.each do |assignee_id, count|
      name = assignee_id ? User.find_by(id: assignee_id)&.name || "Agent #{assignee_id}" : 'Unassigned / AI'
      agent_stats[name] ||= { tickets: 0, resolved: 0 }
      agent_stats[name][:tickets] += count
    end

    resolved_conversations.unscope(:order).group(:assignee_id).count.each do |assignee_id, count|
      name = assignee_id ? User.find_by(id: assignee_id)&.name || "Agent #{assignee_id}" : 'Unassigned / AI'
      agent_stats[name][:resolved] += count if agent_stats[name]
    end

    # F. AI Analytics
    ai_replies_count = base_messages.outgoing.where(sender_id: nil).count
    agent_replies_count = base_messages.outgoing.where.not(sender_id: nil).count
    
    # D. Topic Insights (Basic Keyword extraction)
    # To keep it fast, we just sample recent 500 incoming messages and count word frequencies
    top_words = extract_top_keywords

    {
      executive_summary: {
        total_messages: total_messages,
        total_users: total_users,
        total_tickets: total_tickets,
        resolved_rate_percentage: resolved_rate,
        avg_first_response_time_seconds: avg_first_response_time
      },
      volume: {
        messages_per_day: messages_per_day,
        conversations_per_day: conversations_per_day
      },
      helpdesk_and_agents: agent_stats,
      ai_analytics: {
        ai_replies_count: ai_replies_count,
        agent_replies_count: agent_replies_count
      },
      insights: {
        top_keywords: top_words,
        note: "Top keywords are extracted from incoming messages. For better categorization, use Chatwoot Labels or an AI background job."
      }
    }
  end

  def extract_top_keywords
    stopwords = %w[di ke dari dan yang ini itu untuk pada dengan saya kita kami kamu dia mereka bisa ada tidak ya mau apa bagaimana kenapa]
    text = base_messages.incoming.limit(500).pluck(:content).compact.join(" ").downcase
    words = text.scan(/[a-z]+/)
    word_counts = Hash.new(0)
    words.each do |word|
      word_counts[word] += 1 if word.length > 3 && !stopwords.include?(word)
    end
    word_counts.sort_by { |_, count| -count }.first(10).to_h
  end

  def generate_chat_export_csv
    require 'csv'
    metrics = generate_dashboard_metrics

    CSV.generate(headers: false) do |csv|
      csv << ["DASHBOARD ANALITIK & EXPORT DATA PERCAKAPAN"]
      csv << ["Rentang Waktu:", @start_date.strftime("%Y-%m-%d"), "sampai", @end_date.strftime("%Y-%m-%d")]
      csv << []
      
      csv << ["A. RINGKASAN UTAMA (EXECUTIVE SUMMARY)"]
      csv << ["Metrik", "Nilai"]
      csv << ["Total Pesan Masuk", metrics[:executive_summary][:total_messages]]
      csv << ["Total Pengguna Unik", metrics[:executive_summary][:total_users]]
      csv << ["Total Tiket / Percakapan", metrics[:executive_summary][:total_tickets]]
      csv << ["Tingkat Penyelesaian (%)", metrics[:executive_summary][:resolved_rate_percentage]]
      csv << ["Rata-rata Waktu Respon Pertama (Detik)", metrics[:executive_summary][:avg_first_response_time_seconds]]
      csv << []

      csv << ["B. VOLUME LAYANAN (TREN HARIAN)"]
      csv << ["Tanggal", "Jumlah Pesan Masuk", "Jumlah Tiket Baru"]
      all_dates = (metrics[:volume][:messages_per_day].keys + metrics[:volume][:conversations_per_day].keys).uniq.sort
      all_dates.each do |date|
        csv << [date, metrics[:volume][:messages_per_day][date] || 0, metrics[:volume][:conversations_per_day][date] || 0]
      end
      csv << []

      csv << ["C & E. KINERJA HELPDESK & AGEN"]
      csv << ["Nama Agen", "Total Ditangani", "Total Diselesaikan"]
      metrics[:helpdesk_and_agents].each do |name, stats|
        csv << [name, stats[:tickets], stats[:resolved]]
      end
      csv << []

      csv << ["F. ANALISIS AI BOT"]
      csv << ["Metrik", "Nilai"]
      csv << ["Total Balasan AI / Otomatis", metrics[:ai_analytics][:ai_replies_count]]
      csv << ["Total Balasan Agen Manusia", metrics[:ai_analytics][:agent_replies_count]]
      csv << []

      csv << ["D. ANALISIS PERTANYAAN (TOP KATA KUNCI)"]
      csv << ["Kata Kunci", "Frekuensi Kemunculan"]
      metrics[:insights][:top_keywords].each do |word, count|
        csv << [word, count]
      end
      csv << []
      csv << []

      csv << ["======================================================="]
      csv << ["DATA MENTAH PERCAKAPAN (UNTUK DATA TRAINING AI / EXPORT)"]
      csv << ['Conversation ID', 'Timestamp', 'Sender Type', 'Sender Name', 'Message Content']
      
      base_messages.includes(:sender).find_each do |message|
        sender_type = message.message_type == 'incoming' ? 'User' : (message.sender_id.nil? ? 'AI' : 'Agent')
        sender_name = message.sender&.name || 'Unknown'
        csv << [
          message.conversation_id,
          message.created_at.iso8601,
          sender_type,
          sender_name,
          message.content
        ]
      end
    end
  end
end
