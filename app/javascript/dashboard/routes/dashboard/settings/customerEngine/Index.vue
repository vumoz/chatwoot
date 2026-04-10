<script setup>
import { computed, onMounted, reactive, ref } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert } from 'dashboard/composables';
import axios from 'axios';
import SettingsLayout from '../SettingsLayout.vue';

const { t } = useI18n();
const { showAlert } = useAlert();

const accountId = computed(
  () => window.location.pathname.split('/')[3] || ''
);
const apiRoot = computed(
  () => `/api/v1/accounts/${accountId.value}/customer_engine`
);

const loading = ref(true);
const saving = ref(false);
const metrics = ref({});
const connectors = ref([]);
const resolutionAttempts = ref([]);
const attemptsMeta = ref({ current_page: 1, total_pages: 1, total_count: 0 });
const attemptsPage = ref(1);

const slackConfigured = ref(false);
const slackMasked = ref('');

const form = reactive({
  policy: {
    automation_level: 2,
    min_confidence_for_auto: 0.72,
    max_auto_actions_per_hour: 500,
    risk_alert_threshold: 0.55,
    generate_draft_reply: true,
    live_zendesk_public_comment: false,
    post_draft_as_private_note: true,
    live_google_review_reply: false,
    live_yelp_public_reply: false,
    auto_ingest_incoming_messages: false,
    blocked_issue_categories: '',
    allowed_issue_categories: '',
  },
  slack_webhook_url: '',
  alert_email: '',
  openai_api_key: '',
  openai_model: '',
});

const newConnector = reactive({
  name: '',
  provider: 'zendesk',
  zendesk: { subdomain: '', email: '', api_token: '' },
  yelp: { api_key: '', business_id: '', partner_r2r_access_token: '' },
  google: {
    oauth_client_id: '',
    oauth_client_secret: '',
    oauth_refresh_token: '',
    account_resource_name: '',
    location_resource_name: '',
  },
  trustpilot: {
    business_unit_id: '',
    oauth_access_token: '',
    api_key: '',
    api_secret: '',
  },
  intercom: {
    access_token: '',
  },
  shopify: {
    shop_domain: '',
    access_token: '',
  },
  amazon: {
    stub_mode: true,
  },
});

function buildConnectorSettings() {
  switch (newConnector.provider) {
    case 'zendesk':
      return { ...newConnector.zendesk };
    case 'yelp_fusion':
      return { ...newConnector.yelp };
    case 'google_business':
      return { ...newConnector.google };
    case 'trustpilot':
      return { ...newConnector.trustpilot };
    case 'intercom':
      return { ...newConnector.intercom };
    case 'shopify':
      return { ...newConnector.shopify };
    case 'amazon_selling_partner':
      return { stub_mode: true, ...newConnector.amazon };
    default:
      return {};
  }
}

async function fetchResolutionAttempts(page = 1) {
  const { data } = await axios.get(`${apiRoot.value}/resolution_attempts`, {
    params: { page },
  });
  resolutionAttempts.value = data.data || [];
  attemptsMeta.value = data.meta || {};
  attemptsPage.value = page;
}

async function fetchAll() {
  loading.value = true;
  try {
    const [settingsRes, metricsRes, connRes] = await Promise.all([
      axios.get(`${apiRoot.value}/settings`),
      axios.get(
        `/api/v1/accounts/${accountId.value}/ai_resolution/metrics`
      ),
      axios.get(`${apiRoot.value}/connectors`),
    ]);
    const p = settingsRes.data.policy || {};
    form.policy.automation_level = p.automation_level ?? 2;
    form.policy.min_confidence_for_auto = p.min_confidence_for_auto ?? 0.72;
    form.policy.max_auto_actions_per_hour = p.max_auto_actions_per_hour ?? 500;
    form.policy.risk_alert_threshold = p.risk_alert_threshold ?? 0.55;
    form.policy.generate_draft_reply = p.generate_draft_reply !== false;
    form.policy.live_zendesk_public_comment = p.live_zendesk_public_comment === true;
    form.policy.post_draft_as_private_note = p.post_draft_as_private_note !== false;
    form.policy.live_google_review_reply = p.live_google_review_reply === true;
    form.policy.live_yelp_public_reply = p.live_yelp_public_reply === true;
    form.policy.auto_ingest_incoming_messages =
      p.auto_ingest_incoming_messages === true;
    form.policy.blocked_issue_categories = (
      p.blocked_issue_categories || []
    ).join(', ');
    form.policy.allowed_issue_categories = (
      p.allowed_issue_categories || []
    ).join(', ');
    slackConfigured.value = settingsRes.data.slack_webhook_configured;
    slackMasked.value = settingsRes.data.slack_webhook_url_masked || '';
    form.slack_webhook_url = '';
    form.alert_email = settingsRes.data.alert_email || '';
    form.openai_model = settingsRes.data.openai_model || '';
    metrics.value = metricsRes.data;
    connectors.value = connRes.data.data || [];
    await fetchResolutionAttempts(attemptsPage.value);
  } finally {
    loading.value = false;
  }
}

async function saveSettings() {
  saving.value = true;
  try {
    const blocked = form.policy.blocked_issue_categories
      .split(',')
      .map(s => s.trim())
      .filter(Boolean);
    const allowedRaw = form.policy.allowed_issue_categories
      .split(',')
      .map(s => s.trim())
      .filter(Boolean);
    const payload = {
      alert_email: form.alert_email,
      openai_api_key: form.openai_api_key,
      openai_model: form.openai_model,
      policy: {
        automation_level: Number(form.policy.automation_level),
        min_confidence_for_auto: Number(form.policy.min_confidence_for_auto),
        max_auto_actions_per_hour: Number(form.policy.max_auto_actions_per_hour),
        risk_alert_threshold: Number(form.policy.risk_alert_threshold),
        generate_draft_reply: form.policy.generate_draft_reply,
        live_zendesk_public_comment: form.policy.live_zendesk_public_comment,
        post_draft_as_private_note: form.policy.post_draft_as_private_note,
        live_google_review_reply: form.policy.live_google_review_reply,
        live_yelp_public_reply: form.policy.live_yelp_public_reply,
        auto_ingest_incoming_messages:
          form.policy.auto_ingest_incoming_messages,
        blocked_issue_categories: blocked,
        allowed_issue_categories: allowedRaw.length ? allowedRaw : null,
      },
    };
    if (form.slack_webhook_url) {
      payload.slack_webhook_url = form.slack_webhook_url;
    }
    await axios.patch(`${apiRoot.value}/settings`, payload);
    showAlert(t('CUSTOMER_ENGINE.SETTINGS.SAVED'));
    form.openai_api_key = '';
    await fetchAll();
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  } finally {
    saving.value = false;
  }
}

async function addConnector() {
  try {
    await axios.post(`${apiRoot.value}/connectors`, {
      connector: {
        name: newConnector.name,
        provider: newConnector.provider,
        status: 'enabled',
        settings: buildConnectorSettings(),
      },
    });
    newConnector.name = '';
    await fetchAll();
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  }
}

async function removeConnector(id) {
  await axios.delete(`${apiRoot.value}/connectors/${id}`);
  await fetchAll();
}

async function syncConnector(id) {
  const { data } = await axios.post(
    `${apiRoot.value}/connectors/${id}/sync`
  );
  showAlert(`Synced ${data.synced} new signals`);
  await fetchAll();
}

async function sendTestAlert() {
  try {
    const { data } = await axios.post(`${apiRoot.value}/alerts/test`);
    showAlert(
      `${t('CUSTOMER_ENGINE.SETTINGS.TEST_SENT')} Slack:${data.sent_slack} Email:${data.sent_email}`
    );
  } catch (e) {
    showAlert(e.response?.data?.error || e.message);
  }
}

onMounted(fetchAll);
</script>

<template>
  <SettingsLayout
    :is-loading="loading"
    :loading-message="t('CUSTOMER_ENGINE.SETTINGS.TITLE')"
    class="flex flex-col gap-6"
  >
    <template #body>
      <div class="max-w-4xl">
      <p class="text-n-slate-11 mb-4">
        {{ $t('CUSTOMER_ENGINE.SETTINGS.DESCRIPTION') }}
      </p>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_TITLE') }}
        </h3>
        <div class="grid grid-cols-2 gap-2 text-sm text-n-slate-11">
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_SIGNALS') }}:
            {{ metrics.review_signals_count }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_TRIAGE') }}:
            {{ metrics.triage_decisions_count }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_SUCCEEDED') }}:
            {{ metrics.resolution_attempts_succeeded }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_AUTO_OK') }}:
            {{ metrics.resolution_attempts_automated_succeeded }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_AGENT_ASSIST') }}:
            {{ metrics.resolution_attempts_agent_assist_succeeded }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_APPROVAL') }}:
            {{ metrics.resolution_attempts_pending_approval }}
          </div>
          <div>
            {{ $t('CUSTOMER_ENGINE.SETTINGS.METRICS_FAILED') }}:
            {{ metrics.resolution_attempts_failed }}
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-3">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_TITLE') }}
        </h3>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_AUTOMATION') }}</span>
            <input
              v-model.number="form.policy.automation_level"
              type="number"
              min="1"
              max="5"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_MIN_CONF') }}</span>
            <input
              v-model.number="form.policy.min_confidence_for_auto"
              type="number"
              step="0.01"
              min="0"
              max="1"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_MAX_RATE') }}</span>
            <input
              v-model.number="form.policy.max_auto_actions_per_hour"
              type="number"
              min="1"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_RISK') }}</span>
            <input
              v-model.number="form.policy.risk_alert_threshold"
              type="number"
              step="0.01"
              min="0"
              max="1"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm md:col-span-2">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_BLOCKED') }}</span>
            <input
              v-model="form.policy.blocked_issue_categories"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm md:col-span-2">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_ALLOWED') }}</span>
            <input
              v-model="form.policy.allowed_issue_categories"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.generate_draft_reply"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_DRAFT') }}</span>
          </label>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.live_zendesk_public_comment"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_ZENDESK_LIVE') }}</span>
          </label>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.post_draft_as_private_note"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_CHATWOOT_NOTE') }}</span>
          </label>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.live_google_review_reply"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_GOOGLE_LIVE') }}</span>
          </label>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.live_yelp_public_reply"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_YELP_LIVE') }}</span>
          </label>
          <p class="text-xs text-n-slate-11 md:col-span-2 -mt-1">
            {{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_YELP_LIVE_HINT') }}
          </p>
          <label class="flex items-center gap-2 text-sm md:col-span-2">
            <input
              v-model="form.policy.auto_ingest_incoming_messages"
              type="checkbox"
              class="rounded border-n-weak"
            />
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_AUTO_INGEST') }}</span>
          </label>
          <p class="text-xs text-n-slate-11 md:col-span-2 -mt-1">
            {{ $t('CUSTOMER_ENGINE.SETTINGS.POLICY_AUTO_INGEST_HINT') }}
          </p>
        </div>
      </div>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-3">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_TITLE') }}
        </h3>
        <p
          v-if="resolutionAttempts.length === 0"
          class="text-sm text-n-slate-11"
        >
          {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_EMPTY') }}
        </p>
        <div
          v-else
          class="overflow-x-auto"
        >
          <table class="w-full text-left text-sm text-n-slate-11">
            <thead>
              <tr class="border-b border-n-weak text-n-slate-12">
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_ID') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_STATUS') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_PATH') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_SOURCE') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_CONVERSATION') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_PREVIEW') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_ERROR') }}
                </th>
                <th class="py-2 pr-2">
                  {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_COL_TIME') }}
                </th>
              </tr>
            </thead>
            <tbody>
              <tr
                v-for="row in resolutionAttempts"
                :key="row.id"
                class="border-b border-n-weak/50"
              >
                <td class="py-2 pr-2 align-top">
                  {{ row.id }}
                </td>
                <td class="py-2 pr-2 align-top">
                  {{ row.status }}
                </td>
                <td class="py-2 pr-2 align-top">
                  {{ row.resolution_path || '—' }}
                </td>
                <td class="py-2 pr-2 align-top">
                  {{ row.source_platform || '—' }}
                </td>
                <td class="py-2 pr-2 align-top whitespace-nowrap">
                  <router-link
                    v-if="row.conversation_url"
                    :to="row.conversation_url"
                    class="text-n-brand hover:underline"
                  >
                    #{{ row.conversation_display_id }}
                  </router-link>
                  <span v-else>—</span>
                </td>
                <td class="py-2 pr-2 align-top max-w-md break-words">
                  {{ row.draft_reply_preview || '—' }}
                </td>
                <td class="py-2 pr-2 align-top max-w-xs break-words text-red-500">
                  {{ row.failure_reason || '—' }}
                </td>
                <td class="py-2 pr-2 align-top whitespace-nowrap">
                  {{ row.created_at }}
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div
          v-if="attemptsMeta.total_pages > 1"
          class="mt-3 flex flex-wrap items-center gap-2 text-sm"
        >
          <button
            type="button"
            class="rounded border border-n-weak px-2 py-1"
            :disabled="attemptsPage <= 1"
            @click="fetchResolutionAttempts(attemptsPage - 1)"
          >
            {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_PREV') }}
          </button>
          <span class="text-n-slate-11">
            {{ attemptsPage }} / {{ attemptsMeta.total_pages }}
          </span>
          <button
            type="button"
            class="rounded border border-n-weak px-2 py-1"
            :disabled="attemptsPage >= attemptsMeta.total_pages"
            @click="fetchResolutionAttempts(attemptsPage + 1)"
          >
            {{ $t('CUSTOMER_ENGINE.SETTINGS.ATTEMPTS_NEXT') }}
          </button>
        </div>
      </div>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-3">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.OPENAI_TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.OPENAI_HINT') }}
        </p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label class="flex flex-col gap-1 text-sm md:col-span-2">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.OPENAI_MODEL') }}</span>
            <input
              v-model="form.openai_model"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm md:col-span-2">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.OPENAI_KEY') }}</span>
            <input
              v-model="form.openai_api_key"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
        </div>
      </div>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-3">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.ALERTS_TITLE') }}
        </h3>
        <div class="grid grid-cols-1 gap-3">
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.SLACK_URL') }}</span>
            <span
              v-if="slackConfigured"
              class="text-xs text-n-slate-11"
            >{{ slackMasked }}</span>
            <input
              v-model="form.slack_webhook_url"
              type="url"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.ALERT_EMAIL') }}</span>
            <input
              v-model="form.alert_email"
              type="email"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <div>
            <button
              type="button"
              class="rounded-md bg-n-brand px-3 py-1.5 text-sm text-white"
              @click="sendTestAlert"
            >
              {{ $t('CUSTOMER_ENGINE.SETTINGS.TEST_ALERT') }}
            </button>
          </div>
        </div>
      </div>

      <div class="rounded-lg border border-n-weak bg-n-alpha-3 p-4 mb-4">
        <h3 class="text-base font-semibold text-n-slate-12 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTORS_TITLE') }}
        </h3>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.ZENDESK_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.YELP_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-4">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.GOOGLE_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.TRUSTPILOT_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.INTERCOM_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-2">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.SHOPIFY_FIELDS') }}
        </p>
        <p class="text-xs text-n-slate-11 mb-4">
          {{ $t('CUSTOMER_ENGINE.SETTINGS.AMAZON_FIELDS') }}
        </p>

        <div
          v-for="c in connectors"
          :key="c.id"
          class="mb-3 rounded border border-n-weak p-3 text-sm"
        >
          <div class="font-medium text-n-slate-12">
            {{ c.name }} ({{ c.provider }})
          </div>
          <div class="text-n-slate-11">
            {{ $t('CUSTOMER_ENGINE.SETTINGS.LAST_SYNC') }}:
            {{ c.last_synced_at || '—' }}
          </div>
          <div
            v-if="c.last_error"
            class="text-red-500"
          >
            {{ $t('CUSTOMER_ENGINE.SETTINGS.LAST_ERROR') }}: {{ c.last_error }}
          </div>
          <div class="mt-2 flex flex-wrap gap-2">
            <button
              type="button"
              class="rounded border border-n-weak px-2 py-1"
              @click="syncConnector(c.id)"
            >
              {{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTOR_SYNC') }}
            </button>
            <button
              type="button"
              class="rounded border border-n-weak px-2 py-1"
              @click="removeConnector(c.id)"
            >
              {{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTOR_DELETE') }}
            </button>
          </div>
        </div>

        <div class="grid grid-cols-1 gap-2 border-t border-n-weak pt-4">
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTOR_NAME') }}</span>
            <input
              v-model="newConnector.name"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            />
          </label>
          <label class="flex flex-col gap-1 text-sm">
            <span>{{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTOR_PROVIDER') }}</span>
            <select
              v-model="newConnector.provider"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1 text-n-slate-12"
            >
              <option value="zendesk">
                zendesk
              </option>
              <option value="yelp_fusion">
                yelp_fusion
              </option>
              <option value="google_business">
                google_business
              </option>
              <option value="trustpilot">
                trustpilot
              </option>
              <option value="intercom">
                intercom
              </option>
              <option value="shopify">
                shopify
              </option>
              <option value="amazon_selling_partner">
                amazon_selling_partner
              </option>
            </select>
          </label>

          <div
            v-if="newConnector.provider === 'zendesk'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.zendesk.subdomain"
              placeholder="subdomain"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.zendesk.email"
              placeholder="agent@example.com"
              type="email"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.zendesk.api_token"
              placeholder="API token"
              type="password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'yelp_fusion'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.yelp.api_key"
              placeholder="Yelp API key"
              type="password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.yelp.business_id"
              placeholder="Business ID"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.yelp.partner_r2r_access_token"
              :placeholder="$t('CUSTOMER_ENGINE.SETTINGS.YELP_R2R_TOKEN')"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'google_business'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.google.oauth_client_id"
              placeholder="OAuth client ID"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.google.oauth_client_secret"
              placeholder="OAuth client secret"
              type="password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.google.oauth_refresh_token"
              placeholder="Refresh token"
              type="password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.google.account_resource_name"
              placeholder="accounts/123456789"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.google.location_resource_name"
              placeholder="locations/987654321"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'trustpilot'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.trustpilot.business_unit_id"
              placeholder="Business unit id"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.trustpilot.oauth_access_token"
              placeholder="OAuth access token (optional if using API key)"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.trustpilot.api_key"
              placeholder="API key (client id)"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.trustpilot.api_secret"
              placeholder="API secret (client secret)"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'intercom'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.intercom.access_token"
              placeholder="Intercom access token"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'shopify'"
            class="grid grid-cols-1 gap-2"
          >
            <input
              v-model="newConnector.shopify.shop_domain"
              placeholder="mystore.myshopify.com"
              type="text"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
            <input
              v-model="newConnector.shopify.access_token"
              placeholder="Shopify Admin API access token"
              type="password"
              autocomplete="new-password"
              class="rounded-md border border-n-weak bg-n-alpha-2 px-2 py-1"
            />
          </div>

          <div
            v-if="newConnector.provider === 'amazon_selling_partner'"
            class="grid grid-cols-1 gap-2 text-xs text-n-slate-11"
          >
            <p>
              {{ $t('CUSTOMER_ENGINE.SETTINGS.AMAZON_FIELDS') }}
            </p>
          </div>

          <button
            type="button"
            class="rounded-md bg-n-brand px-3 py-1.5 text-sm text-white"
            @click="addConnector"
          >
            {{ $t('CUSTOMER_ENGINE.SETTINGS.CONNECTOR_ADD') }}
          </button>
        </div>
      </div>

      <div class="flex gap-2">
        <button
          type="button"
          class="rounded-md bg-n-brand px-4 py-2 text-sm text-white disabled:opacity-50"
          :disabled="saving"
          @click="saveSettings"
        >
          {{ $t('CUSTOMER_ENGINE.SETTINGS.SAVE') }}
        </button>
      </div>
    </div>
    </template>
  </SettingsLayout>
</template>
