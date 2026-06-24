import SettingsWrapper from '../SettingsWrapper.vue';
import AiSettings from 'dashboard/components/ai/AiSettings.vue';
import { frontendURL } from '../../../../helper/URLHelper';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/ai'),
      component: SettingsWrapper,
      children: [
        {
          path: '',
          name: 'settings_ai',
          component: AiSettings,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
