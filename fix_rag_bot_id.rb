Rag::KnowledgeEntry.where(rag_bot_id: nil).find_each do |e|
  if e.metadata && e.metadata['document_id']
    doc = Rag::Document.find_by(id: e.metadata['document_id'])
    e.update_column(:rag_bot_id, doc.rag_bot_id) if doc
  end
end
puts "Fixed records"
