<script>
import V4Button from 'dashboard/components-next/button/Button.vue';
import { useAlert, useTrack } from 'dashboard/composables';
import ReportFilters from './components/ReportFilters.vue';
import { GROUP_BY_FILTER } from './constants';
import { REPORTS_EVENTS } from '../../../../helper/AnalyticsHelper/events';
import {
  generateFileName,
  downloadCsvFile,
} from 'dashboard/helper/downloadHelper';
import ReportContainer from './ReportContainer.vue';
import ReportHeader from './components/ReportHeader.vue';

const REPORTS_KEYS = {
  CONVERSATIONS: 'conversations_count',
  INCOMING_MESSAGES: 'incoming_messages_count',
  OUTGOING_MESSAGES: 'outgoing_messages_count',
  FIRST_RESPONSE_TIME: 'avg_first_response_time',
  RESOLUTION_TIME: 'avg_resolution_time',
  RESOLUTION_COUNT: 'resolutions_count',
  REPLY_TIME: 'reply_time',
};

export default {
  name: 'ConversationReports',
  components: {
    ReportHeader,
    ReportFilters,
    ReportContainer,
    V4Button,
  },
  data() {
    return {
      from: 0,
      to: 0,
      groupBy: GROUP_BY_FILTER[1],
      businessHours: false,
      isDownloadingReports: false,
      isDownloadingDashboard: false,
      isDownloadingChat: false,
    };
  },
  methods: {
    fetchAllData() {
      this.fetchAccountSummary();
      this.fetchChartData();
    },
    fetchAccountSummary() {
      try {
        this.$store.dispatch('fetchAccountSummary', this.getRequestPayload());
      } catch {
        useAlert(this.$t('REPORT.SUMMARY_FETCHING_FAILED'));
      }
    },
    fetchChartData() {
      [
        'CONVERSATIONS',
        'INCOMING_MESSAGES',
        'OUTGOING_MESSAGES',
        'FIRST_RESPONSE_TIME',
        'RESOLUTION_TIME',
        'RESOLUTION_COUNT',
        'REPLY_TIME',
      ].forEach(async key => {
        try {
          await this.$store.dispatch('fetchAccountReport', {
            metric: REPORTS_KEYS[key],
            ...this.getRequestPayload(),
          });
        } catch {
          useAlert(this.$t('REPORT.DATA_FETCHING_FAILED'));
        }
      });
    },
    getRequestPayload() {
      const { from, to, groupBy, businessHours } = this;

      return {
        from,
        to,
        groupBy: groupBy?.period,
        businessHours,
      };
    },
    async downloadConversationReports() {
      this.isDownloadingReports = true;
      const { from, to } = this;
      const fileName = generateFileName({
        type: 'conversation',
        to,
        businessHours: this.businessHours,
      });
      try {
        await this.$store.dispatch('downloadConversationsSummaryReports', {
          from,
          to,
          fileName,
          businessHours: this.businessHours,
        });
      } finally {
        this.isDownloadingReports = false;
      }
    },
    async downloadDashboard() {
      this.isDownloadingDashboard = true;
      const { from, to } = this;
      const startDate = new Date(from * 1000).toISOString().split('T')[0];
      const endDate = new Date(to * 1000).toISOString().split('T')[0];
      const accountId = this.$route.params.accountId;

      try {
        const response = await window.axios.get(
          `/api/v1/accounts/${accountId}/dashboard_reports.csv?start_date=${startDate}&end_date=${endDate}`
        );
        downloadCsvFile(
          `dashboard_reports_${startDate}_to_${endDate}.csv`,
          response.data
        );
      } finally {
        this.isDownloadingDashboard = false;
      }
    },
    async downloadChat() {
      this.isDownloadingChat = true;
      const { from, to } = this;
      const startDate = new Date(from * 1000).toISOString().split('T')[0];
      const endDate = new Date(to * 1000).toISOString().split('T')[0];
      const accountId = this.$route.params.accountId;

      try {
        const response = await window.axios.get(
          `/api/v1/accounts/${accountId}/chat_export.csv?start_date=${startDate}&end_date=${endDate}`
        );
        downloadCsvFile(`chat_export_${startDate}_to_${endDate}.csv`, response.data);
      } finally {
        this.isDownloadingChat = false;
      }
    },
    onFilterChange({ from, to, groupBy, businessHours }) {
      this.from = from;
      this.to = to;
      this.groupBy = groupBy;
      this.businessHours = businessHours;
      this.fetchAllData();

      useTrack(REPORTS_EVENTS.FILTER_REPORT, {
        filterValue: { from, to, groupBy, businessHours },
        reportType: 'conversations',
      });
    },
  },
};
</script>

<template>
  <ReportHeader :header-title="$t('REPORT.HEADER')">
    <V4Button
      :label="$t('REPORT.DOWNLOAD_CONVERSATION_REPORTS')"
      icon="i-ph-download-simple"
      size="sm"
      :is-loading="isDownloadingReports"
      :disabled="isDownloadingReports"
      @click="downloadConversationReports"
    />
    <V4Button
      label="Download Dashboard CSV"
      icon="i-ph-file-csv"
      size="sm"
      :is-loading="isDownloadingDashboard"
      :disabled="isDownloadingDashboard"
      @click="downloadDashboard"
    />
    <V4Button
      label="Download Chat"
      icon="i-ph-chat-circle-dots"
      size="sm"
      color="teal"
      :is-loading="isDownloadingChat"
      :disabled="isDownloadingChat"
      @click="downloadChat"
    />
  </ReportHeader>
  <div class="flex flex-col">
    <ReportFilters
      :show-entity-filter="false"
      show-group-by
      @filter-change="onFilterChange"
    />
    <ReportContainer :group-by="groupBy" />
  </div>
</template>
