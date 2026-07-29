<script setup>
import { reactive, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useVuelidate } from '@vuelidate/core';
import { required, minLength } from '@vuelidate/validators';
import { useMapGetter } from 'dashboard/composables/store';

import Input from 'dashboard/components-next/input/Input.vue';
import TextArea from 'dashboard/components-next/textarea/TextArea.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import ComboBox from 'dashboard/components-next/combobox/ComboBox.vue';
import TagMultiSelectComboBox from 'dashboard/components-next/combobox/TagMultiSelectComboBox.vue';

const emit = defineEmits(['submit', 'cancel']);

const { t } = useI18n();

const formState = {
  uiFlags: useMapGetter('campaigns/getUIFlags'),
  labels: useMapGetter('labels/getLabels'),
  inboxes: useMapGetter('inboxes/getLunarsenderInboxes'),
};

const initialState = {
  title: '',
  message: '',
  inboxId: null,
  scheduledAt: null,
  selectedAudience: [],
  manualNumbers: '',
  delay: 3, // Default 3 seconds delay
  isRandomDelay: false,
  maxDelay: 5,
};

const state = reactive({ ...initialState });

const rules = {
  title: { required, minLength: minLength(1) },
  message: { required, minLength: minLength(1) },
  inboxId: { required },
  scheduledAt: { required },
  delay: { required },
};

const v$ = useVuelidate(rules, state);

const isCreating = computed(() => formState.uiFlags.value.isCreating);

const currentDateTime = computed(() => {
  const now = new Date();
  
  // Round up to nearest 5 minutes (300000 ms)
  const ms = 1000 * 60 * 5; 
  const roundedNow = new Date(Math.ceil(now.getTime() / ms) * ms);
  
  const localTime = new Date(roundedNow.getTime() - roundedNow.getTimezoneOffset() * 60000);
  return localTime.toISOString().slice(0, 16);
});

const mapToOptions = (items, valueKey, labelKey) =>
  items?.map(item => ({
    value: item[valueKey],
    label: item[labelKey],
  })) ?? [];

const audienceList = computed(() =>
  mapToOptions(formState.labels.value, 'id', 'title')
);

const inboxOptions = computed(() =>
  mapToOptions(formState.inboxes.value, 'id', 'name')
);

const getErrorMessage = (field, errorKey) => {
  const baseKey = 'CAMPAIGN.LUNARSENDER.CREATE.FORM';
  if (!v$.value[field]) return '';
  return v$.value[field].$error ? t(`${baseKey}.${errorKey}.ERROR`) : '';
};

const formErrors = computed(() => ({
  title: getErrorMessage('title', 'TITLE'),
  message: getErrorMessage('message', 'MESSAGE'),
  inbox: getErrorMessage('inboxId', 'INBOX'),
  scheduledAt: getErrorMessage('scheduledAt', 'SCHEDULED_AT'),
  delay: getErrorMessage('delay', 'DELAY'),
}));

const hasAudience = computed(() => {
  return state.selectedAudience.length > 0 || state.manualNumbers.trim().length > 0;
});

const isSubmitDisabled = computed(() => {
  if (v$.value.$invalid) return true;
  if (!hasAudience.value) return true;
  if (state.isRandomDelay && (state.maxDelay === null || state.maxDelay <= state.delay)) return true;
  return false;
});

const formatToUTCString = localDateTime =>
  localDateTime ? new Date(localDateTime).toISOString() : null;

const resetState = () => {
  Object.assign(state, initialState);
  v$.value.$reset();
};

const disableBeforeToday = (date) => {
  const yesterday = new Date();
  yesterday.setDate(yesterday.getDate() - 1);
  return date < yesterday;
};

const handleCancel = () => emit('cancel');

const prepareCampaignDetails = () => {
  return {
    title: state.title,
    message: state.message,
    inbox_id: state.inboxId,
    scheduled_at: formatToUTCString(state.scheduledAt),
    audience: state.selectedAudience?.map(id => ({
      id,
      type: 'Label',
    })),
    template_params: { 
      delay: state.delay,
      is_random_delay: state.isRandomDelay,
      max_delay: state.maxDelay,
      manual_numbers: state.manualNumbers
    },
  };
};

const handleSubmit = async () => {
  const isFormValid = await v$.value.$validate();
  if (!isFormValid || !hasAudience.value) return;

  emit('submit', prepareCampaignDetails());
  resetState();
  handleCancel();
};
</script>

<template>
  <form class="flex flex-col gap-4" @submit.prevent="handleSubmit">
    <Input
      v-model="state.title"
      :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.TITLE.LABEL')"
      :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.TITLE.PLACEHOLDER')"
      :message="formErrors.title"
      :message-type="formErrors.title ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="inbox" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.LUNARSENDER.CREATE.FORM.INBOX.LABEL') }}
      </label>
      <ComboBox
        id="inbox"
        v-model="state.inboxId"
        :options="inboxOptions"
        :has-error="!!formErrors.inbox"
        :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.INBOX.PLACEHOLDER')"
        :message="formErrors.inbox"
        class="[&>div>button]:bg-n-alpha-black2 [&>div>button:not(.focused)]:dark:outline-n-weak [&>div>button:not(.focused)]:hover:!outline-n-slate-6"
      />
    </div>

    <TextArea
      v-model="state.message"
      :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.MESSAGE.LABEL')"
      :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.MESSAGE.PLACEHOLDER')"
      :message="formErrors.message"
      :message-type="formErrors.message ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="audience" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.LUNARSENDER.CREATE.FORM.AUDIENCE.LABEL') }}
      </label>
      <TagMultiSelectComboBox
        v-model="state.selectedAudience"
        :options="audienceList"
        :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.AUDIENCE.LABEL')"
        :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.AUDIENCE.PLACEHOLDER')"
        class="[&>div>button]:bg-n-alpha-black2"
      />
    </div>

    <TextArea
      v-model="state.manualNumbers"
      :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.MANUAL_NUMBERS.LABEL')"
      :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.MANUAL_NUMBERS.PLACEHOLDER')"
      :message="!hasAudience ? t('CAMPAIGN.LUNARSENDER.CREATE.FORM.AUDIENCE.ERROR') : ''"
      :message-type="!hasAudience ? 'error' : 'info'"
    />

    <div class="flex flex-col gap-1">
      <label for="scheduledAt" class="mb-0.5 text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.LUNARSENDER.CREATE.FORM.SCHEDULED_AT.LABEL') }}
      </label>
      <input
        type="datetime-local"
        v-model="state.scheduledAt"
        step="300"
        :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.SCHEDULED_AT.PLACEHOLDER')"
        class="flex h-[2.5rem] w-full rounded-md border border-solid border-n-weak bg-n-background px-3 py-2 text-sm text-n-slate-12 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-n-brand disabled:cursor-not-allowed disabled:opacity-50"
        :class="{ 'border-n-ruby-9': formErrors.scheduledAt }"
      />
      <p
        v-if="formErrors.scheduledAt"
        class="min-w-0 mt-1 mb-0 text-label-small truncate transition-all duration-500 ease-in-out text-n-ruby-9 dark:text-n-ruby-9"
      >
        {{ formErrors.scheduledAt }}
      </p>
    </div>

    <div class="flex items-center gap-2 mb-2">
      <input
        type="checkbox"
        id="isRandomDelay"
        v-model="state.isRandomDelay"
        class="w-4 h-4 text-n-blue-9 bg-gray-100 border-gray-300 rounded focus:ring-n-blue-9"
      />
      <label for="isRandomDelay" class="text-sm font-medium text-n-slate-12">
        {{ t('CAMPAIGN.LUNARSENDER.CREATE.FORM.IS_RANDOM_DELAY.LABEL') }}
      </label>
    </div>

    <div class="flex gap-4 w-full">
      <div class="flex-1">
        <Input
          v-model="state.delay"
          :label="state.isRandomDelay ? t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY_MIN.LABEL') : t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY.LABEL')"
          type="number"
          min="0"
          :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY.PLACEHOLDER')"
          :message="formErrors.delay"
          :message-type="formErrors.delay ? 'error' : 'info'"
        />
      </div>
      
      <div v-if="state.isRandomDelay" class="flex-1">
        <Input
          v-model="state.maxDelay"
          :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY_MAX.LABEL')"
          type="number"
          :min="state.delay + 1"
          :placeholder="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY_MAX.PLACEHOLDER')"
          :message="state.maxDelay <= state.delay ? t('CAMPAIGN.LUNARSENDER.CREATE.FORM.DELAY_MAX.ERROR') : ''"
          :message-type="state.maxDelay <= state.delay ? 'error' : 'info'"
        />
      </div>
    </div>

    <div class="flex gap-3 justify-between items-center w-full">
      <Button
        variant="faded"
        color="slate"
        type="button"
        :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.BUTTONS.CANCEL')"
        class="w-full bg-n-alpha-2 text-n-blue-11 hover:bg-n-alpha-3"
        @click="handleCancel"
      />
      <Button
        :label="t('CAMPAIGN.LUNARSENDER.CREATE.FORM.BUTTONS.CREATE')"
        class="w-full"
        type="submit"
        :is-loading="isCreating"
        :disabled="isCreating || isSubmitDisabled"
      />
    </div>
  </form>
</template>
