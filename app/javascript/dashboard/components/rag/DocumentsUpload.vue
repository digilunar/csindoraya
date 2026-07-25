<template>
  <div class="rag-documents-container">
    <div class="header">
      <div class="title">
        <h3>{{ $t('RAG_DOCUMENTS.TITLE') }}</h3>
        <p>{{ $t('RAG_DOCUMENTS.DESCRIPTION') }}</p>
      </div>
      <span @click="showUploadModal = true" class="inline-block cursor-pointer">
        <NextButton variant="ghost" color="slate" icon="i-lucide-upload-cloud">
          {{ $t('RAG_DOCUMENTS.UPLOAD_BUTTON') }}
        </NextButton>
      </span>
    </div>

    <!-- Document List -->
    <div class="document-list" v-if="documents.length > 0">
      <div class="document-item" v-for="doc in documents" :key="doc.id">
        <div class="document-info">
          <div class="document-icon">
            <fluent-icon :icon="getFileIcon(doc.file_type)" size="24" />
          </div>
          <div class="document-details">
            <h4>{{ doc.name }}</h4>
            <div class="document-meta">
              <span class="badge" :class="doc.scope">{{ doc.scope }}</span>
              <span class="status" :class="doc.status">
                <Spinner v-if="['pending', 'processing'].includes(doc.status)" size="small" />
                <fluent-icon v-else-if="doc.status === 'failed'" icon="warning" size="12" />
                <fluent-icon v-else-if="doc.status === 'completed'" icon="checkmark" size="12" />
                {{ $t(`RAG_DOCUMENTS.STATUS.${doc.status.toUpperCase()}`) }}
              </span>
              <span v-if="doc.file_type">{{ doc.file_type.toUpperCase() }}</span>
            </div>
            <div v-if="doc.status === 'failed' && doc.last_error" class="document-error">
              <p class="error-text">Alasan Gagal: {{ doc.last_error }}</p>
            </div>
          </div>
        </div>
        <div class="document-actions">
          <span v-if="['completed', 'failed'].includes(doc.status)" @click="deleteDocument(doc.id)" class="inline-block cursor-pointer">
            <NextButton
              variant="ghost"
              icon="i-lucide-trash"
              color="ruby"
            />
          </span>
        </div>
      </div>
    </div>

    <!-- Empty State -->
    <empty-state
      v-else
      :title="$t('RAG_DOCUMENTS.EMPTY_STATE.TITLE')"
      :message="$t('RAG_DOCUMENTS.EMPTY_STATE.DESCRIPTION')"
      icon="folder-open"
    >
      <div class="flex justify-center mt-4 cursor-pointer">
        <span @click="showUploadModal = true" class="inline-block">
          <NextButton variant="solid" color="blue" icon="i-lucide-upload-cloud">
            {{ $t('RAG_DOCUMENTS.UPLOAD_FIRST') }}
          </NextButton>
        </span>
      </div>
    </empty-state>

    <!-- Upload Modal -->
    <woot-modal v-model:show="showUploadModal" :on-close="closeUploadModal">
      <div class="upload-modal">
        <woot-modal-header
          :modal-title="$t('RAG_DOCUMENTS.UPLOAD_MODAL.TITLE')"
          :modal-on-close="closeUploadModal"
        />

        <form @submit.prevent="uploadDocuments">
          <!-- Scope Selection -->
          <div class="form-group">
            <label>{{ $t('RAG_DOCUMENTS.SCOPE') }}</label>
            <select v-model="uploadScope" class="woot-input">
              <option value="account">{{ $t('RAG_DOCUMENTS.SCOPE_ACCOUNT') }}</option>
              <option v-if="isSuperAdmin" value="global">{{ $t('RAG_DOCUMENTS.SCOPE_GLOBAL') }}</option>
            </select>
          </div>

          <!-- File Upload -->
          <div class="form-group">
            <label>{{ $t('RAG_DOCUMENTS.FILES') }}</label>
            <div class="file-upload-area" @dragover.prevent @drop.prevent="handleFileDrop" @click="triggerFileInput">
              <input
                type="file"
                ref="fileInput"
                multiple
                accept=".pdf,.txt,.csv,.xlsx,.xls,.jpg,.jpeg,.png,.gif"
                @change="handleFileSelect"
                class="file-input"
              />
              <div class="upload-icon">
                <fluent-icon icon="upload" size="48" />
              </div>
              <p>{{ $t('RAG_DOCUMENTS.DRAG_DROP') }}</p>
              <p class="hint">{{ $t('RAG_DOCUMENTS.SUPPORTED_FORMATS') }}</p>
            </div>
          </div>

          <!-- Selected Files -->
          <div v-if="selectedFiles.length > 0" class="selected-files">
            <div class="file-item" v-for="(file, index) in selectedFiles" :key="index">
              <fluent-icon :icon="getFileIcon(file.type)" size="16" />
              <span>{{ file.name }}</span>
              <span @click="removeFile(index)" class="inline-block cursor-pointer">
                <NextButton variant="ghost" color="slate" icon="i-lucide-x" />
              </span>
            </div>
          </div>

          <div class="modal-footer">
            <span @click="closeUploadModal" class="inline-block cursor-pointer">
              <NextButton variant="ghost" color="slate">
                {{ $t('RAG_DOCUMENTS.CANCEL') }}
              </NextButton>
            </span>
            <NextButton type="submit" variant="primary" :loading="isUploading" :disabled="selectedFiles.length === 0">
              {{ $t('RAG_DOCUMENTS.UPLOAD') }}
            </NextButton>
          </div>
        </form>
      </div>
    </woot-modal>

    <!-- Alert Messages removed in favor of useAlert -->
  </div>
</template>

<script>
import { mapGetters } from 'vuex';
import { useAlert } from 'dashboard/composables';
import EmptyState from 'dashboard/components/widgets/EmptyState.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Spinner from 'shared/components/Spinner.vue';

export default {
  components: {
    EmptyState,
    NextButton,
    Spinner,
  },
  props: {
    accountId: {
      type: [Number, String],
      required: true,
    },
    ragBotId: {
      type: [Number, String],
      required: true,
    },
  },
  setup() {
    return { useAlert };
  },
  data() {
    return {
      documents: [],
      selectedFiles: [],
      showUploadModal: false,
      uploadScope: 'account',
      isUploading: false,
      pollingInterval: null,
    };
  },
  computed: {
    ...mapGetters({
      currentAccountId: 'getCurrentAccountId',
      currentUser: 'getCurrentUser',
    }),
    account() {
      return this.$store.getters['accounts/getAccount'](this.currentAccountId);
    },
    isSuperAdmin() {
      return this.currentUser.role === 'super_admin';
    },
  },
  mounted() {
    this.fetchDocuments();
  },
  unmounted() {
    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }
  },
  methods: {
    triggerFileInput() {
      if (this.$refs.fileInput) {
        this.$refs.fileInput.click();
      }
    },
    async fetchDocuments(silent = false) {
      try {
        const response = await this.$store.dispatch('ragDocuments/get', {
          accountId: this.accountId,
          ragBotId: this.ragBotId,
        });
        this.documents = response.data;
        this.checkAndStartPolling();
      } catch (error) {
        if (!silent) {
          this.showAlert(this.$t('RAG_DOCUMENTS.ERRORS.FETCH'), 'error');
        }
      }
    },

    checkAndStartPolling() {
      const hasPending = this.documents.some(doc => ['pending', 'processing'].includes(doc.status));
      if (hasPending && !this.pollingInterval) {
        this.pollingInterval = setInterval(() => {
          this.fetchDocuments(true);
        }, 3000);
      } else if (!hasPending && this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
      }
    },

    handleFileSelect(event) {
      const files = Array.from(event.target.files);
      this.selectedFiles.push(...files);
    },

    handleFileDrop(event) {
      const files = Array.from(event.dataTransfer.files);
      this.selectedFiles.push(...files);
    },

    removeFile(index) {
      this.selectedFiles.splice(index, 1);
    },

    closeUploadModal() {
      this.showUploadModal = false;
      this.selectedFiles = [];
      this.uploadScope = 'account';
    },

    async uploadDocuments() {
      this.isUploading = true;

      const formData = new FormData();
      this.selectedFiles.forEach(file => {
        formData.append('files[]', file);
      });
      formData.append('scope', this.uploadScope);
      formData.append('rag_bot_id', this.ragBotId);

      try {
        await this.$store.dispatch('ragDocuments/upload', {
          accountId: this.accountId,
          ragBotId: this.ragBotId,
          formData,
        });
        this.showAlert(this.$t('RAG_DOCUMENTS.UPLOAD_SUCCESS'), 'success');
        this.closeUploadModal();
        this.fetchDocuments();
      } catch (error) {
        this.showAlert(this.$t('RAG_DOCUMENTS.ERRORS.UPLOAD'), 'error');
      } finally {
        this.isUploading = false;
      }
    },

    async deleteDocument(id) {
      if (!confirm(this.$t('RAG_DOCUMENTS.DELETE_CONFIRM'))) return;

      try {
        await this.$store.dispatch('ragDocuments/delete', {
          accountId: this.accountId,
          ragBotId: this.ragBotId,
          id,
        });
        this.showAlert(this.$t('RAG_DOCUMENTS.DELETE_SUCCESS'), 'success');
        this.fetchDocuments();
      } catch (error) {
        this.showAlert(this.$t('RAG_DOCUMENTS.ERRORS.DELETE'), 'error');
      }
    },

    getFileIcon(fileType) {
      if (fileType === 'image' || fileType?.startsWith('image/')) {
        return 'image';
      }
      return 'document';
    },

    showAlert(message, type) {
      this.useAlert(message);
    },
  },
};
</script>

<style scoped lang="scss">
.rag-documents-container {
  padding: 2rem;

  .header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 2rem;

    .title {
      h3 {
        margin: 0 0 0.5rem 0;
      }

      p {
        color: var(--s-500);
        margin: 0;
      }
    }
  }


  .document-list {
    .document-item {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 1rem;
      border: 1px solid var(--color-border);
      border-radius: var(--border-radius-medium);
      margin-bottom: 0.75rem;
      background: var(--color-background);

      .document-info {
        display: flex;
        align-items: center;
        gap: 1rem;

        .document-icon {
          color: var(--s-600);
        }

        .document-details {
          h4 {
            margin: 0 0 0.25rem 0;
          }

          .document-meta {
            display: flex;
            gap: 0.5rem;
            align-items: center;

            .badge {
              padding: 0.125rem 0.5rem;
              border-radius: var(--border-radius-small);
              font-size: var(--font-size-mini);
              text-transform: uppercase;

              &.account {
                background: var(--b-100);
                color: var(--b-700);
              }

              &.global {
                background: var(--p-100);
                color: var(--p-700);
              }
            }

            .status {
              font-size: var(--font-size-mini);
              display: flex;
              align-items: center;
              gap: 0.25rem;

              &.pending {
                color: var(--y-700);
              }

              &.processing {
                color: var(--b-700);
              }

              &.completed {
                color: var(--g-700);
              }

              &.failed {
                color: var(--r-700);
              }
            }
          }
          
          .document-error {
            margin-top: 0.5rem;
            padding: 0.5rem;
            background-color: var(--r-50);
            border-left: 3px solid var(--r-500);
            border-radius: var(--border-radius-small);
            
            .error-text {
              margin: 0;
              font-size: var(--font-size-mini);
              color: var(--r-800);
              word-break: break-word;
            }
          }
        }
      }
    }
  }

  @keyframes spin {
    100% {
      transform: rotate(360deg);
    }
  }

  .upload-modal {
    padding: 2rem;

    .form-group {
      margin-bottom: 1.5rem;

      label {
        display: block;
        margin-bottom: 0.5rem;
        font-weight: var(--font-weight-medium);
      }
    }

    .file-upload-area {
      border: 2px dashed var(--color-border);
      border-radius: var(--border-radius-medium);
      padding: 2rem;
      text-align: center;
      cursor: pointer;
      transition: all 0.2s;

      &:hover {
        border-color: var(--w-400);
        background: var(--w-50);
      }

      .upload-icon {
        color: var(--s-400);
        margin-bottom: 1rem;
      }

      .hint {
        color: var(--s-500);
        font-size: var(--font-size-mini);
        margin-top: 0.5rem;
      }

      .file-input {
        display: none;
      }
    }

    .selected-files {
      margin-top: 1rem;

      .file-item {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        padding: 0.5rem;
        background: var(--color-background-secondary);
        border-radius: var(--border-radius-small);
        margin-bottom: 0.5rem;
        font-size: var(--font-size-small);

        span {
          flex: 1;
        }
      }
    }

    .modal-footer {
      display: flex;
      justify-content: flex-end;
      gap: 0.75rem;
      margin-top: 1.5rem;
    }
  }
}
</style> 
