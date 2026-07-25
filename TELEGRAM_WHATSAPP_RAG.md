# Telegram & WhatsApp RAG Integration

AI-powered auto-response untuk Telegram \& WhatsApp menggunakan knowledge base custom.

## Fitur

- **Multi-channel**: Telegram \& WhatsApp support
- **Hybrid Knowledge Base**: Global (SuperAdmin) + Account-specific
- **Multi-format**: PDF, TXT, XLSX, CSV, Gambar (OCR)
- **Vector Search**: Semantic similarity search (Enterprise)
- **Fallback**: Keyword search jika vector search unavailable
- **Multi-LLM**: Anthropic, OpenAI, Azure OpenAI

## Arsitektur

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────────┐
│  Telegram Msg   │     │              │     │  LLM (Claude/   │
│  WhatsApp Msg   │────▶│  Rag Service │────▶│  GPT-4o, etc)   │
│  (Inbound)      │     │              │     │                 │
└─────────────────┘     └──────┬───────┘     └─────────────────┘
                               │
                      ┌────────▼────────┐
                      │  Knowledge Base │
                      │  - Global       │
                      │  - Account      │
                      └─────────────────┘
```

## Setup

### 1. Environment Variables

Tambahkan ke `.env`:

```bash
# RAG Feature Flag
RAG_ENABLED=true

# LLM Provider (anthropic|openai|azure)
RAG_LLM_PROVIDER=anthropic

# Anthropic
ANTHROPIC_API_KEY=sk-ant-...

# OpenAI (alternative)
# RAG_LLM_PROVIDER=openai
# OPENAI_API_KEY=sk-...

# Azure OpenAI (alternative)
# RAG_LLM_PROVIDER=azure
# AZURE_OPENAI_API_KEY=...
# AZURE_OPENAI_ENDPOINT=https://...
# AZURE_OPENAI_DEPLOYMENT=...

# Fallback message ketika knowledge tidak ditemukan
RAG_FALLBACK_MESSAGE=Maaf, saya tidak menemukan informasi terkait pertanyaan Anda.

# Embedding model (optional)
RAG_EMBEDDING_MODEL=text-embedding-3-small
```

### 2. Database Migration

```bash
rails db:migrate
```

Migration yang dibuat:
- `CreateRagKnowledgeEntries` - Tabel knowledge base
- `CreateRagDocuments` - Tabel uploaded documents

### 3. Enable Feature Flag

```ruby
# Rails console
Account.find(ID).feature_flags.update(rag: true)
```

### 4. Upload Dokumen

#### Via API

```bash
# Single document
curl -X POST "https://your-chatwoot.com/api/v1/accounts/:account_id/rag/documents" \
  -H "Authorization: Bearer :api_key" \
  -F "document[file]=@/path/to/file.pdf" \
  -F "document[name]=My Document" \
  -F "document[scope]=account"

# Bulk upload
curl -X POST "https://your-chatwoot.com/api/v1/accounts/:account_id/rag/documents/bulk_upload" \
  -H "Authorization: Bearer :api_key" \
  -F "files[]=@/path/to/file1.pdf" \
  -F "files[]=@/path/to/file2.xlsx" \
  -F "scope=account"
```

#### Scope

- `account` - Hanya untuk account ini (default)
- `global` - Untuk semua accounts (SuperAdmin only)

### 5. Manage Knowledge Entries

#### List knowledge
```bash
curl "https://your-chatwoot.com/api/v1/rag_knowledge" \
  -H "Authorization: Bearer :api_key"
```

#### Add manual entry
```bash
curl -X POST "https://your-chatwoot.com/api/v1/rag_knowledge" \
  -H "Authorization: Bearer :api_key" \
  -H "Content-Type: application/json" \
  -d '{
    "knowledge": {
      "question": "Apa jam operasional?",
      "answer": "Jam operasional kami adalah Senin-Jumat, 9:00-17:00 WIB",
      "scope": "account"
    }
  }'
```

#### Search knowledge
```bash
curl "https://your-chatwoot.com/api/v1/rag_knowledge/search?q=jam%20buka" \
  -H "Authorization: Bearer :api_key"
```

### 6. Telegram Setup

1. Create bot via @BotFather
2. Dapatkan bot token
3. Add Telegram channel di Chatwoot Settings \> Inboxes
4. Bot token akan auto-setup webhook

### 7. WhatsApp Setup

1. Meta Business verified
2. WhatsApp Business API access
3. Add WhatsApp channel di Chatwoot Settings \> Inboxes
4. Configure Phone Number ID \& Business Account ID

## Permission Model

| Role | Upload Global | Upload Account | Edit Global | Edit Account |
|------|--------------|----------------|-------------|--------------|
| SuperAdmin | ✅ | ✅ | ✅ | ✅ |
| Account Admin | ❌ | ✅ | ❌ | ✅ |
| Account Manager | ❌ | ✅ | ❌ | ✅ |
| Agent | ❌ | ❌ | ❌ | View only |

## Supported File Formats

| Format | Extension | Extract Method |
|--------|-----------|----------------|
| Text | `.txt` | Direct read |
| PDF | `.pdf` | PyPDF2 / OCR |
| Excel | `.xlsx`, `.xls` | Roo gem |
| CSV | `.csv` | CSV parser |
| Image | `.jpg`, `.png`, `.gif` | Tesseract OCR |

## Redis Queue

RAG jobs antri di Redis queue `rag`:

```bash
SIDEKIQ_QUEUES=rag,default,mailers
```

## Monitoring

### Check document status

```ruby
Rag::Document.find(id).status
# => "pending", "processing", "completed", "failed"
```

### Check knowledge entries

```ruby
Rag::KnowledgeEntry.count
Rag::KnowledgeEntry.global.count
Rag::KnowledgeEntry.for_account(account_id).count
```

### Logs

```
Rails.logger.info("RAG document processed: #{document_id}")
Rails.logger.error("Rag::ResponseJob failed: #{e.message}")
```

## Troubleshooting

### Vector search tidak bekerja

Pastikan:
1. Chatwoot Enterprise aktif
2. pgvector extension enabled di PostgreSQL
3. Embedding API key valid

```sql
-- Check pgvector
SELECT * FROM pg_extension WHERE extname = 'vector';
```

### OCR gagal

Install Tesseract:

```bash
# Ubuntu/Debian
apt-get install tesseract-ocr

# Windows
# Download dari https://github.com/UB-Mannheim/tesseract/wiki
```

### LLM API error

Check API key \& quota:

```bash
rails console
ENV.fetch('ANTHROPIC_API_KEY')
# atau
ENV.fetch('OPENAI_API_KEY')
```

## API Reference

### Upload Document
```
POST /api/v1/accounts/:account_id/rag/documents
```

### Bulk Upload
```
POST /api/v1/accounts/:account_id/rag/documents/bulk_upload
```

### List Documents
```
GET /api/v1/accounts/:account_id/rag/documents
```

### Delete Document
```
DELETE /api/v1/accounts/:account_id/rag/documents/:id
```

### List Knowledge
```
GET /api/v1/rag_knowledge
```

### Create Knowledge
```
POST /api/v1/rag_knowledge
```

### Update Knowledge
```
PUT /api/v1/rag_knowledge/:id
```

### Delete Knowledge
```
DELETE /api/v1/rag_knowledge/:id
```

### Search Knowledge
```
GET /api/v1/rag_knowledge/search?q=:query
```

## Development

### Run migrations
```bash
rails db:migrate
```

### Seed sample data
```bash
rails db:seed:rag
```

### Test OCR
```ruby
loader = Rag::DocumentLoader.new('path/to/image.jpg')
loader.load
```

### Test LLM
```ruby
llm = Rag::LlmService.new
llm.generate(prompt: "Halo", context: nil)
```

### Test Knowledge Base
```ruby
kb = Rag::KnowledgeBase.new(account_id: 1)
results = kb.search("jam operasional")
```