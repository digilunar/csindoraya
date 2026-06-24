<script setup>
import { ref, onMounted } from 'vue';
import { useAlert } from 'dashboard/composables';
import ragBotsApi from '../../../../api/ragBots';
import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import RagBotModal from './RagBotModal.vue';
import AiSettings from 'dashboard/components/ai/AiSettings.vue';
import DocumentsUpload from 'dashboard/components/rag/DocumentsUpload.vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const accountId = route.params.accountId;

const bots = ref([]);
const isFetching = ref(false);

const activeTab = ref('bots'); // bots, settings, knowledge
const modalRef = ref(null);
const modalType = ref('create');
const selectedBot = ref({});

const fetchBots = async () => {
  isFetching.value = true;
  try {
    const response = await ragBotsApi.get();
    bots.value = response.data;
  } catch (error) {
    useAlert('Error fetching RAG bots');
  } finally {
    isFetching.value = false;
  }
};

const openCreateModal = () => {
  modalType.value = 'create';
  selectedBot.value = {};
  modalRef.value.dialogRef.open();
};

const openEditModal = (bot) => {
  modalType.value = 'edit';
  selectedBot.value = bot;
  modalRef.value.dialogRef.open();
};

const manageKnowledge = (bot) => {
  selectedBot.value = bot;
  activeTab.value = 'knowledge';
};

const deleteBot = async (id) => {
  if (!confirm('Are you sure you want to delete this bot?')) return;
  try {
    await ragBotsApi.delete(id);
    useAlert('RAG Bot deleted successfully');
    fetchBots();
  } catch (error) {
    useAlert('Error deleting RAG bot');
  }
};

const getFullWebhookUrl = (path) => {
  if (!path) return '';
  return `${window.location.origin}${path}`;
};

onMounted(() => {
  fetchBots();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isFetching"
    loading-message="Loading RAG Bots..."
    :no-records-found="false"
    no-records-message="No RAG Bots found"
  >
    <template #header>
      <BaseSettingsHeader
        title="RAG Bots"
        description="Manage your RAG bots, general AI endpoints, and knowledge base."
        link-text="Learn more"
      >
        <template #tabs>
          <div class="flex gap-4 border-b border-n-weak w-full">
            <button
              class="px-4 py-2 font-medium text-sm transition-colors border-b-2"
              :class="activeTab === 'bots' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
              @click="activeTab = 'bots'"
            >
              RAG Bots
            </button>
            <button
              class="px-4 py-2 font-medium text-sm transition-colors border-b-2"
              :class="activeTab === 'settings' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
              @click="activeTab = 'settings'"
            >
              General AI Settings
            </button>
          </div>
        </template>
        <template #actions>
          <Button v-if="activeTab === 'bots'" @click="openCreateModal" color="blue" size="md">
            Create New Bot
          </Button>
        </template>
      </BaseSettingsHeader>
    </template>
    <template #body>
      <div class="flex flex-col gap-6 w-full mt-4">
        
        <!-- Tab: Bots -->
        <div v-if="activeTab === 'bots'">
          <div v-if="bots.length === 0" class="flex flex-col items-center justify-center p-12 bg-white dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700 shadow-sm">
            <p class="text-slate-500 dark:text-slate-400 mb-4">No RAG Bots found. Create your first bot to get started.</p>
            <Button @click="openCreateModal" color="blue">Create New Bot</Button>
          </div>

          <div v-else class="grid grid-cols-1 gap-4">
            <div 
              v-for="bot in bots" 
              :key="bot.id" 
              class="bg-white dark:bg-slate-800 rounded-lg p-6 shadow-sm border border-slate-200 dark:border-slate-700 flex flex-col gap-3"
            >
              <div class="flex justify-between items-center">
                <h3 class="text-lg font-bold text-slate-800 dark:text-slate-100 flex items-center gap-2">
                  <span class="w-2 h-2 rounded-full" :class="bot.use_general_ai_setting ? 'bg-blue-500' : 'bg-green-500'"></span>
                  {{ bot.name }}
                </h3>
                <div class="flex gap-2">
                  <Button @click="manageKnowledge(bot)" color="teal" variant="outline" size="sm">Knowledge Docs</Button>
                  <Button @click="openEditModal(bot)" color="slate" variant="outline" size="sm">Edit</Button>
                  <Button @click="deleteBot(bot.id)" color="ruby" variant="outline" size="sm">Delete</Button>
                </div>
              </div>
              
              <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mt-2">
                <div class="flex flex-col gap-1">
                  <span class="text-xs font-semibold text-slate-500 uppercase">AI Endpoint URL</span>
                  <span class="text-sm text-slate-700 dark:text-slate-300 break-all">
                    {{ bot.use_general_ai_setting ? '(Menggunakan General AI Setting)' : bot.ai_endpoint_url || 'N/A' }}
                  </span>
                </div>
                
                <div class="flex flex-col gap-1">
                  <span class="text-xs font-semibold text-slate-500 uppercase">Webhook URL (For Agent Bots)</span>
                  <div class="bg-slate-100 dark:bg-slate-900 p-2 rounded text-sm text-slate-800 dark:text-slate-200 font-mono break-all select-all flex items-center justify-between">
                    {{ getFullWebhookUrl(bot.webhook_url) }}
                  </div>
                </div>
              </div>

              <div v-if="bot.rag_knowledge" class="flex flex-col gap-1 mt-2">
                <span class="text-xs font-semibold text-slate-500 uppercase">RAG Knowledge</span>
                <div class="bg-slate-50 dark:bg-slate-900/50 p-3 rounded text-sm text-slate-600 dark:text-slate-400 whitespace-pre-wrap line-clamp-3 hover:line-clamp-none transition-all">
                  {{ bot.rag_knowledge }}
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Tab: Settings -->
        <div v-if="activeTab === 'settings'" class="bg-white dark:bg-slate-800 rounded-lg p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <AiSettings />
        </div>

        <!-- Tab: Knowledge Base (Per-Bot) -->
        <div v-if="activeTab === 'knowledge' && selectedBot.id" class="bg-white dark:bg-slate-800 rounded-lg p-6 shadow-sm border border-slate-200 dark:border-slate-700">
          <div class="flex items-center gap-4 mb-4">
            <Button @click="activeTab = 'bots'" color="slate" variant="ghost" icon="i-lucide-arrow-left">Back to Bots</Button>
            <h3 class="text-lg font-semibold m-0">Knowledge Base: {{ selectedBot.name }}</h3>
          </div>
          <p class="text-sm text-slate-500 mb-6">Upload PDF, TXT, or DOCX files specifically for this AI bot to reference.</p>
          <DocumentsUpload :account-id="accountId" :rag-bot-id="selectedBot.id" />
        </div>

      </div>

      <RagBotModal
        ref="modalRef"
        :type="modalType"
        :selected-bot="selectedBot"
        @success="fetchBots"
      />
    </template>
  </SettingsLayout>
</template>
