import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
  routes: [
    {
      path: frontendURL('accounts/:accountId/settings/customer-engine'),
      meta: {
        permissions: ['administrator'],
      },
      component: SettingsWrapper,
      props: {
        headerTitle: 'CUSTOMER_ENGINE.SETTINGS.TITLE',
        icon: 'i-lucide-sparkles',
        showNewButton: false,
      },
      children: [
        {
          path: '',
          name: 'customer_engine_settings_index',
          component: Index,
          meta: {
            permissions: ['administrator'],
          },
        },
      ],
    },
  ],
};
