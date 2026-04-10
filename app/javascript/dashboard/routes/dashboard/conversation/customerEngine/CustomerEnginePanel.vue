<script setup>
import { computed, onMounted, ref, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import axios from 'axios';
import AccordionItem from 'dashboard/components/Accordion/AccordionItem.vue';
import { useAlert } from 'dashboard/composables';
import { BUS_EVENTS } from 'shared/constants/busEvents';
import { emitter } from 'shared/helpers/mitt';

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const { showAlert } = useAlert();

const loading = ref(true);
const context = ref({
  timeline: [],
  latest_draft: null,
  pending_approval: null,
});

const accountId = computed(
  () => window.location.pathname.split('/')[3] || ''
);

const apiBase = computed(
  () => `/api/v1/accounts/${accountId.value}/customer_engine`
);

async function load() {
  if (!props.conversationId) return;
  loading.value = true;
  try {
    const { data } = await axios.get(
      `${apiBase.value}/conversations/${props.conversationId}/context`
    );
    context.value = data;
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  } finally {
    loading.value = false;
  }
}

function insertDraft() {
  const text = context.value.latest_draft?.text;
  if (!text) return;
  emitter.emit(BUS_EVENTS.INSERT_INTO_RICH_EDITOR, text);
}

async function approveAttempt() {
  const id = context.value.pending_approval?.attempt_id;
  if (!id) return;
  try {
    await axios.post(`${apiBase.value}/resolution_attempts/${id}/approve`, {});
    showAlert(t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.APPROVED'));
    await load();
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  }
}

async function rejectAttempt() {
  const id = context.value.pending_approval?.attempt_id;
  if (!id) return;
  const reason = window.prompt(t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.REJECT_PROMPT'));
  if (reason == null || reason === '') return;
  try {
    await axios.post(`${apiBase.value}/resolution_attempts/${id}/reject`, {
      reason,
    });
    showAlert(t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.REJECTED'));
    await load();
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  }
}

onMounted(load);
watch(
  () => props.conversationId,
  () => load()
);
</script>

<template>
  <div class="text-sm text-n-slate-11">
    <p
      v-if="loading"
      class="px-1"
    >
      {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.LOADING') }}
    </p>
    <div
      v-else
      class="flex flex-col gap-3"
    >
      <div v-if="context.latest_draft?.text">
        <div class="text-xs font-medium text-n-slate-12 mb-1">
          {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.SUGGESTED') }}
        </div>
        <p class="whitespace-pre-wrap break-words rounded border border-n-weak bg-n-alpha-2 p-2 text-n-slate-12">
          {{ context.latest_draft.text }}
        </p>
        <button
          type="button"
          class="mt-2 rounded-md bg-n-brand px-2 py-1 text-xs text-white"
          @click="insertDraft"
        >
          {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.INSERT') }}
        </button>
      </div>

      <div v-if="context.pending_approval">
        <div class="text-xs font-medium text-n-slate-12 mb-1">
          {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.PENDING') }}
        </div>
        <div class="flex flex-wrap gap-2">
          <button
            type="button"
            class="rounded border border-n-weak px-2 py-1 text-xs"
            @click="approveAttempt"
          >
            {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.APPROVE') }}
          </button>
          <button
            type="button"
            class="rounded border border-n-weak px-2 py-1 text-xs"
            @click="rejectAttempt"
          >
            {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.REJECT') }}
          </button>
        </div>
      </div>

      <div v-if="context.timeline?.length">
        <div class="text-xs font-medium text-n-slate-12 mb-1">
          {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.TIMELINE') }}
        </div>
        <ul class="max-h-48 overflow-y-auto space-y-2 text-xs">
          <li
            v-for="(row, idx) in context.timeline"
            :key="idx"
            class="border-b border-n-weak/40 pb-1"
          >
            <span class="text-n-slate-11">{{ row.at }}</span>
            <span class="ml-1 text-n-slate-12">{{ row.kind }} · {{ row.status || row.resolution_path || '' }}</span>
          </li>
        </ul>
      </div>

      <p
        v-if="!context.timeline?.length && !context.latest_draft && !context.pending_approval"
        class="text-xs"
      >
        {{ $t('CONVERSATION_SIDEBAR.CUSTOMER_ENGINE.EMPTY') }}
      </p>
    </div>
  </div>
</template>
