export default {
  RAG_DOCUMENTS: {
    TITLE: 'RAG Knowledge Base',
    DESCRIPTION: 'Upload dokumen untuk training bot Telegram & WhatsApp. Bot akan otomatis menjawab berdasarkan konten dokumen.',
    UPLOAD_BUTTON: 'Upload Dokumen',
    UPLOAD_FIRST: 'Upload Dokumen Pertama',
    SCOPE: 'Scope',
    SCOPE_ACCOUNT: 'Account ini saja',
    SCOPE_GLOBAL: 'Global (Semua Account)',
    FILES: 'File',
    DRAG_DROP: 'Drag & drop file di sini atau klik untuk browse',
    SUPPORTED_FORMATS: 'Support: PDF, TXT, CSV, XLSX, JPG, PNG (max 10MB)',
    UPLOAD: 'Upload',
    CANCEL: 'Cancel',
    STATUS: {
      PENDING: 'Pending',
      PROCESSING: 'Processing',
      COMPLETED: 'Completed',
      FAILED: 'Failed',
    },
    EMPTY_STATE: {
      TITLE: 'Belum ada dokumen',
      DESCRIPTION: 'Upload PDF, TXT, CSV, XLSX, atau gambar untuk training bot. Bot akan extract konten dan gunakan untuk auto-response.',
    },
    UPLOAD_MODAL: {
      TITLE: 'Upload Dokumen ke Knowledge Base',
    },
    UPLOAD_SUCCESS: 'Dokumen berhasil diupload. Bot sedang memproses...',
    DELETE_SUCCESS: 'Dokumen berhasil dihapus',
    DELETE_CONFIRM: 'Yakin hapus dokumen ini? Bot tidak bisa lagi akses knowledge dari dokumen ini.',
    ERRORS: {
      FETCH: 'Gagal load dokumen',
      UPLOAD: 'Upload gagal. Pastikan format file supported.',
      DELETE: 'Gagal hapus dokumen',
    },
  },
};