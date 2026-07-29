# frozen_string_literal: true

module Telegram
  class DocumentLoader
    class UnsupportedFormat < StandardError; end
    class OcrFailed < StandardError; end

    SUPPORTED_FORMATS = %w[text/plain application/pdf application/vnd.openxmlformats-officedocument.spreadsheetml.sheet application/vnd.ms-excel text/csv image/jpeg image/png image/gif].freeze
    PDF_CONTENT_TYPE = 'application/pdf'.freeze
    IMAGE_CONTENT_TYPES = %w[image/jpeg image/png image/gif].freeze

    def initialize(file_path_or_blob, content_type: nil)
      @file_path = file_path_or_blob.is_a?(String) ? file_path_or_blob : file_path_or_blob.path
      @content_type = content_type || detect_content_type(file_path_or_blob)
    end

    def load
      validate_format
      extract_content
    end

    def self.supported_formats
      SUPPORTED_FORMATS
    end

    private

    attr_reader :file_path, :content_type

    def detect_content_type(blob)
      if blob.respond_to?(:content_type)
        blob.content_type
      else
        Marcel::MimeType.for(file_path)
      end
    end

    def validate_format
      return if SUPPORTED_FORMATS.include?(content_type)
      return if pdf_file?
      return if image_file?
      return if excel_file?
      return if csv_file?

      raise UnsupportedFormat, "Unsupported format: #{content_type}"
    end

    def extract_content
      return extract_from_text if text_file?
      return extract_from_pdf if pdf_file?
      return extract_from_excel if excel_file?
      return extract_from_csv if csv_file?
      return extract_from_image if image_file?

      raise UnsupportedFormat, "Cannot extract from #{content_type}"
    end

    def text_file?
      content_type&.start_with?('text/')
    end

    def pdf_file?
      content_type == PDF_CONTENT_TYPE || file_path.end_with?('.pdf')
    end

    def excel_file?
      content_type&.include?('excel') || content_type&.include?('spreadsheetml') || file_path.end_with?('.xlsx', '.xls')
    end

    def csv_file?
      content_type == 'text/csv' || file_path.end_with?('.csv')
    end

    def image_file?
      IMAGE_CONTENT_TYPES.include?(content_type) || file_path.match?(/\.(jpg|jpeg|png|gif)$/i)
    end

    def extract_from_text
      content = File.read(file_path, encoding: 'UTF-8', invalid: :replace, replace: '?')
      [{ content: content, type: 'text', source: file_path }]
    rescue StandardError => e
      Rails.logger.error "Text extraction failed: #{e.message}"
      []
    end

    def extract_from_pdf
      extract_pdf_text || extract_pdf_ocr
    end

    def extract_pdf_text
      require 'pdf-reader'
      reader = PDF::Reader.new(file_path)
      pages = reader.pages.map(&:text).join("\n\n")
      [{ content: pages, type: 'pdf', source: file_path }]
    rescue LoadError
      extract_pdf_ocr
    rescue StandardError => e
      Rails.logger.warn "PDF text extraction failed: #{e.message}, trying OCR"
      extract_pdf_ocr
    end

    def extract_pdf_ocr
      require 'ruby-tesseract'
      ocr_result = run_ocr(file_path)
      [{ content: ocr_result, type: 'pdf-ocr', source: file_path }]
    rescue LoadError, StandardError => e
      Rails.logger.error "PDF OCR failed: #{e.message}"
      []
    end

    def extract_from_excel
      require 'roo'
      spreadsheet = Roo::Spreadsheet.open(file_path)
      rows = []
      spreadsheet.each do |row|
        rows << row.map(&:to_s).join(' | ')
      end
      [{ content: rows.join("\n"), type: 'excel', source: file_path }]
    rescue LoadError, StandardError => e
      Rails.logger.error "Excel extraction failed: #{e.message}"
      []
    end

    def extract_from_csv
      require 'csv'
      rows = CSV.read(file_path, headers: true, encoding: 'UTF-8', invalid: :replace, replace: '?')
      content = rows.map { |row| row.to_h.to_a.map { |k, v| "#{k}: #{v}" }.join(', ') }.join("\n")
      [{ content: content, type: 'csv', source: file_path }]
    rescue StandardError => e
      Rails.logger.error "CSV extraction failed: #{e.message}"
      []
    end

    def extract_from_image
      run_ocr(file_path)
    end

    def run_ocr(file_path)
      run_tesseract_binary(file_path)
    end

    def run_tesseract_binary(file_path)
      output_base = "#{file_path}_ocr"

      # Use tesseract binary directly (compatible with Ruby 3.4+)
      `tesseract "#{file_path}" "#{output_base}" -l ind+eng 2>/dev/null`
      output_txt = "#{output_base}.txt"

      if File.exist?(output_txt)
        text = File.read(output_txt, encoding: 'UTF-8').strip
        File.delete(output_txt)
        return text if text.present?
      end

      Rails.logger.error "Tesseract OCR returned empty result for: #{file_path}"
      raise OcrFailed, "OCR returned empty result"
    rescue StandardError => e
      Rails.logger.error "Tesseract OCR failed: #{e.message}"
      raise OcrFailed, "OCR failed: #{e.message}"
    end
  end
end