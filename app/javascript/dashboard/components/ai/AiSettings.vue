<template>
  <div class="column content-box">
    <div class="row">
      <div class="small-12 columns with-right-space">
        <h2 class="page-title">
          Buat Bot (AI & Knowledge Base)
        </h2>
        <p class="sub-block-title">
          Konfigurasi koneksi ke model AI eksternal dan unggah dokumen untuk sumber pengetahuan (RAG).
        </p>

        <div class="row">
          <div class="small-12 columns">
            <p class="text-slate-500 dark:text-slate-400 text-sm">
              Pengaturan AI General ini akan digunakan oleh RAG Bots yang mencentang opsi "Gunakan Pengaturan AI General".
            </p>
          </div>
        </div>

        <form class="margin-top-2" @submit.prevent="saveAiSettings">
          <div class="row margin-top-2">
            <div class="small-12 medium-6 columns">
              <label>
                AI Endpoint URL
                <input
                  v-model="aiEndpoint"
                  type="text"
                  placeholder="Contoh: http://localhost:11434/api/generate atau https://api.openai.com/v1/chat/completions"
                />
              </label>
            </div>
            <div class="small-12 medium-6 columns">
              <label>
                AI Model Name
                <input
                  v-model="aiModel"
                  type="text"
                  placeholder="Contoh: llama3 atau gpt-4o"
                />
              </label>
            </div>
          </div>

          <div class="row margin-top-2">
            <div class="small-12 medium-6 columns">
              <label>
                AI API Key (Opsional)
                <input
                  v-model="aiApiKey"
                  type="password"
                  placeholder="Kosongkan jika menggunakan Ollama lokal"
                />
              </label>
            </div>
          </div>

          <div class="row margin-top-2">
            <div class="small-12 columns">
              <label>
                System Prompt
                <textarea
                  v-model="aiSystemPrompt"
                  rows="4"
                  placeholder="Instruksi untuk AI Anda. Contoh: Anda adalah asisten CS yang ramah."
                ></textarea>
              </label>
            </div>
          </div>

          <div class="row margin-top-2">
            <div class="small-12 columns flex items-center gap-2">
              <button
                class="button nice success"
                type="submit"
                :disabled="isSaving"
              >
                {{ isSaving ? 'Menyimpan...' : 'Simpan Pengaturan AI' }}
              </button>
              <button
                class="button nice primary margin-left-1"
                type="button"
                :disabled="isTesting"
                @click="testConnection"
              >
                {{ isTesting ? 'Mengetes...' : 'Tes Koneksi' }}
              </button>
            </div>
            
            <div v-if="testResult" class="small-12 columns margin-top-2">
              <div class="callout" :class="testSuccess ? 'success' : 'alert'">
                <strong>Hasil Tes Koneksi:</strong><br/>
                {{ testResult }}
              </div>
            </div>
          </div>
        </form>

      </div>
    </div>
  </div>
</template>

<script>
import { useAlert } from 'dashboard/composables';
import DocumentsUpload from 'dashboard/components/rag/DocumentsUpload.vue';

export default {
  components: {
    DocumentsUpload,
  },
  data() {
    return {
      aiEndpoint: '',
      aiApiKey: '',
      aiModel: '',
      aiSystemPrompt: '',
      isSaving: false,
      isTesting: false,
      testResult: '',
      testSuccess: false,
    };
  },
  computed: {
    accountId() {
      return this.$route.params.accountId;
    }
  },
  mounted() {
    this.loadSettings();
  },
  methods: {
    async testConnection() {
      if (!this.aiEndpoint || !this.aiModel) {
        this.testSuccess = false;
        this.testResult = 'Silakan isi Endpoint URL dan Model Name terlebih dahulu.';
        return;
      }
      this.isTesting = true;
      this.testResult = 'Menghubungi AI...';
      try {
        const payload = {
          endpoint_url: this.aiEndpoint,
          api_key: this.aiApiKey,
          ai_model: this.aiModel,
          system_prompt: this.aiSystemPrompt,
        };

        const response = await window.axios.post(`/api/v1/accounts/${this.accountId}/custom_ai_integration/test`, payload);
        
        if (response.data && response.data.success) {
          this.testSuccess = true;
          this.testResult = response.data.reply;
        } else {
          this.testSuccess = false;
          this.testResult = 'Berhasil terhubung, tapi balasan AI kosong/tidak sesuai format.';
        }
      } catch (error) {
        this.testSuccess = false;
        this.testResult = `Gagal tes koneksi: ${error.response?.data?.error || error.message}`;
      } finally {
        this.isTesting = false;
      }
    },
    async loadSettings() {
      try {
        const response = await window.axios.get(`/api/v1/accounts/${this.accountId}/custom_ai_integration`);
        if (response.data) {
          this.aiEndpoint = response.data.endpoint_url || '';
          this.aiApiKey = response.data.api_key || '';
          this.aiModel = response.data.ai_model || '';
          this.aiSystemPrompt = response.data.system_prompt || '';
        }
      } catch (error) {
        // Abaikan jika belum ada pengaturan
      }
    },
    async saveAiSettings() {
      this.isSaving = true;
      try {
        const payload = {
          custom_ai_integration: {
            endpoint_url: this.aiEndpoint,
            api_key: this.aiApiKey,
            ai_model: this.aiModel,
            system_prompt: this.aiSystemPrompt,
          }
        };

        let existing = null;
        try {
          const res = await window.axios.get(`/api/v1/accounts/${this.accountId}/custom_ai_integration`);
          existing = res.data;
        } catch (e) {
          // ignore error if not found
        }
        
        if (existing && existing.id) {
          await window.axios.patch(`/api/v1/accounts/${this.accountId}/custom_ai_integration`, payload);
        } else {
          await window.axios.post(`/api/v1/accounts/${this.accountId}/custom_ai_integration`, payload);
        }
        useAlert('Pengaturan AI berhasil disimpan.');
      } catch (error) {
        useAlert(`Gagal menyimpan pengaturan AI: ${error.response?.data?.error || error.message}`);
      } finally {
        this.isSaving = false;
      }
    },
  },
};
</script>

<style scoped>
.with-right-space {
  padding-right: 2rem;
}
.margin-left-1 {
  margin-left: 1rem;
}
.margin-top-1 {
  margin-top: 0.5rem;
}
.margin-top-2 {
  margin-top: 1rem;
}
.margin-top-3 {
  margin-top: 2rem;
}
.margin-bottom-3 {
  margin-bottom: 2rem;
}
.help-text {
  font-size: 1.2rem;
  color: var(--color-body);
}
</style>
