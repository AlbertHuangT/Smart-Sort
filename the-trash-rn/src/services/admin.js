import { hasSupabaseConfig } from 'src/services/config';

import { supabase } from './supabase';

const rpc = async (fn, args = {}) => {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw new Error(error.message);
  return data;
};

const emptyDashboard = {
  requests: [],
  members: [],
  logs: []
};

export const adminService = {
  async fetchDashboard(communityId) {
    if (!hasSupabaseConfig() || !communityId) {
      return { ...emptyDashboard };
    }
    const [requests, members, logs] = await Promise.all([
      rpc('get_pending_applications', { p_community_id: communityId }),
      rpc('get_community_members_admin', { p_community_id: communityId }),
      rpc('get_admin_action_logs', { p_community_id: communityId, p_limit: 50 })
    ]);
    return {
      requests: requests ?? [],
      members: members ?? [],
      logs: logs ?? []
    };
  },

  async approveMember({ requestId, approve }) {
    if (!hasSupabaseConfig()) return false;
    const data = await rpc('review_join_application', {
      p_application_id: requestId,
      p_approve: Boolean(approve),
      p_rejection_reason: approve ? null : 'Rejected by admin review'
    });
    return Boolean(data?.success);
  },

  async grantCredits() {
    if (!hasSupabaseConfig()) return false;
    throw new Error(
      'Bulk credit grants must be tied to an event. This panel does not support that yet.'
    );
  },

  async removeMember({ communityId, memberId }) {
    if (!hasSupabaseConfig()) return false;
    const data = await rpc('remove_community_member', {
      p_community_id: communityId,
      p_user_id: memberId,
      p_reason: 'Admin operation'
    });
    return Boolean(data?.success);
  }
};
