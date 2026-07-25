<script setup>
import { ref, reactive, computed, watch } from 'vue';
import { useAlert } from 'dashboard/composables';
import Dialog from 'dashboard/components-next/dialog/Dialog.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import ragBotsApi from '../../../../api/ragBots';

const props = defineProps({
  type: {
    type: String,
    default: 'create',
    validator: value => ['create', 'edit'].includes(value),
  },
  selectedBot: {
    type: Object,
    default: () => ({}),
  },
});

const emit = defineEmits(['success']);

const dialogRef = ref(null);
const isLoading = ref(false);

const formState = reactive({
  name: '',
  rag_knowledge: '',
  ai_endpoint_url: '',
  use_general_ai_setting: false,
});

const dialogTitle = computed(() =>
  props.type === 'create' ? 'Create New RAG Bot' : 'Edit RAG Bot'
);

const confirmButtonLabel = computed(() =>
  props.type === 'create' ? 'Create Bot' : 'Update Bot'
);

const isFormValid = computed(() => {
  if (!formState.name) return false;
  if (!formState.use_general_ai_setting && !formState.ai_endpoint_url) return false;
  return true;
});

const resetForm = () => {
  Object.assign(formState, {
    name: '',
    rag_knowledge: '',
    ai_endpoint_url: '',
    use_general_ai_setting: false,
  });
};

const initializeForm = () => {
  if (props.selectedBot && Object.keys(props.selectedBot).length) {
    const { name, rag_knowledge, ai_endpoint_url, use_general_ai_setting } = props.selectedBot;
    formState.name = name || '';
    formState.rag_knowledge = rag_knowledge || '';
    formState.ai_endpoint_url = ai_endpoint_url || '';
    formState.use_general_ai_setting = use_general_ai_setting || false;
  } else {
    resetForm();
  }
};

const handleSubmit = async () => {
  if (!isFormValid.value) return;

  isLoading.value = true;
  const botData = {
    name: formState.name,
    rag_knowledge: formState.rag_knowledge,
    ai_endpoint_url: formState.use_general_ai_setting ? '' : formState.ai_endpoint_url,
    use_general_ai_setting: formState.use_general_ai_setting,
  };

  try {
    if (props.type === 'create') {
      await ragBotsApi.create(botData);
      useAlert('RAG Bot created successfully');
    } else {
      await ragBotsApi.update(props.selectedBot.id, botData);
      useAlert('RAG Bot updated successfully');
    }
    emit('success');
    dialogRef.value.close();
    resetForm();
  } catch (error) {
    useAlert(`Error ${props.type === 'create' ? 'creating' : 'updating'} RAG bot`);
  } finally {
    isLoading.value = false;
  }
};

const onCancel = () => {
  dialogRef.value.close();
  resetForm();
};

const onDialogClose = () => {
  resetForm();
};

watch(() => props.selectedBot, initializeForm, { immediate: true, deep: true });

defineExpose({ dialogRef });
</script>

<template>
  <Dialog
    ref="dialogRef"
    type="edit"
    :title="dialogTitle"
    :show-cancel-button="false"
    :show-confirm-button="false"
    @close="onDialogClose"
  >
    <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
      <div class="flex flex-col gap-4">
        <Input
          id="bot-name"
          v-model="formState.name"
          label="Bot Name"
          placeholder="Enter bot name"
        />

        <TextArea
          id="bot-knowledge"
          v-model="formState.rag_knowledge"
          label="RAG Knowledge / System Prompt"
          placeholder="Instructions for your AI. E.g: You are a helpful assistant."
        />

        <div class="flex items-center gap-2 mb-2">
          <input
            id="use-general-setting"
            type="checkbox"
            v-model="formState.use_general_ai_setting"
            class="w-4 h-4 text-blue-600 rounded border-gray-300 focus:ring-blue-500"
          />
          <label for="use-general-setting" class="text-sm font-medium text-slate-700 dark:text-slate-200 cursor-pointer">
            Gunakan Pengaturan AI General (diatur di Tab General AI Settings)
          </label>
        </div>

        <Input
          v-if="!formState.use_general_ai_setting"
          id="bot-endpoint"
          v-model="formState.ai_endpoint_url"
          label="Custom AI Endpoint URL"
          placeholder="e.g. http://your-ai-app.com/api/chat"
        />
      </div>

      <div class="flex items-center justify-end w-full gap-2 px-0 py-2">
        <NextButton
          faded
          slate
          type="button"
          label="Cancel"
          @click="onCancel"
        />
        <NextButton
          type="submit"
          :label="confirmButtonLabel"
          :is-loading="isLoading"
          :disabled="!isFormValid"
        />
      </div>
    </form>
  </Dialog>
</template>
