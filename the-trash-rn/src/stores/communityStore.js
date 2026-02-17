import { create } from 'zustand';
import { communityService } from 'src/services/community';
import { adminService } from 'src/services/admin';

const mapById = (items) => Object.fromEntries(items.map((item) => [item.id, item]));

export const useCommunityStore = create((set, get) => ({
  events: [],
  eventsLoading: false,
  eventMap: {},
  groups: [],
  groupsLoading: false,
  groupMap: {},
  adminDashboards: {},
  activeCityId: null,
  async loadEvents(city) {
    const cityId = typeof city === 'string' ? city : city?.id;
    if (!cityId) return;
    set({ eventsLoading: true, activeCityId: cityId });
    try {
      const events = await communityService.fetchEvents(city);
      set({ events, eventMap: mapById(events), eventsLoading: false });
    } catch (error) {
      set({ eventsLoading: false });
      console.warn('[communityStore] loadEvents failed', error);
    }
  },
  async loadGroups(city) {
    if (get().groupsLoading) return;
    set({ groupsLoading: true });
    try {
      const groups = await communityService.fetchGroups(city);
      set({ groups, groupMap: mapById(groups), groupsLoading: false });
    } catch (error) {
      set({ groupsLoading: false });
      console.warn('[communityStore] loadGroups failed', error);
    }
  },
  async refreshEvent(eventId) {
    if (!eventId) return null;
    try {
      const event = await communityService.fetchEvent(eventId);
      if (!event) return null;
      set((state) => ({ eventMap: { ...state.eventMap, [eventId]: event } }));
      return event;
    } catch (error) {
      console.warn('[communityStore] refreshEvent failed', error);
      return null;
    }
  },
  async refreshCommunity(communityId) {
    if (!communityId) return null;
    try {
      const community = await communityService.fetchCommunity(communityId);
      if (!community) return null;
      set((state) => ({ groupMap: { ...state.groupMap, [communityId]: community } }));
      return community;
    } catch (error) {
      console.warn('[communityStore] refreshCommunity failed', error);
      return null;
    }
  },
  async createEvent(payload) {
    const event = await communityService.createEvent(payload);
    if (!event) {
      throw new Error('创建活动失败');
    }
    set((state) => {
      const shouldInsert = state.activeCityId === event.cityId;
      const events = shouldInsert ? [event, ...state.events] : state.events;
      return {
        events,
        eventMap: { ...state.eventMap, [event.id]: event }
      };
    });
    return event;
  },
  async createCommunity(payload) {
    const community = await communityService.createCommunity(payload);
    if (!community) {
      throw new Error('创建社群失败');
    }
    set((state) => ({
      groups: [community, ...state.groups],
      groupMap: { ...state.groupMap, [community.id]: community }
    }));
    return community;
  },
  async joinCommunity(communityId) {
    await communityService.joinCommunity(communityId);
    await get().refreshCommunity(communityId);
  },
  async rsvpEvent(eventId) {
    const updated = await communityService.rsvpEvent(eventId);
    if (!updated) return null;
    set((state) => ({
      eventMap: { ...state.eventMap, [eventId]: updated },
      events: state.events.map((event) => (event.id === eventId ? updated : event))
    }));
    return updated;
  },
  communityById: (id) => get().groupMap[id] ?? null,
  eventById: (id) => get().eventMap[id] ?? null,
  adminDashboard: (communityId) =>
    get().adminDashboards[communityId] ?? { requests: [], members: [], logs: [] },
  loadAdminDashboard: async (communityId) => {
    if (!communityId) return;
    const dashboard = await adminService.fetchDashboard(communityId);
    set((state) => ({
      adminDashboards: { ...state.adminDashboards, [communityId]: dashboard }
    }));
  },
  processRequest: async ({ communityId, requestId, approve }) => {
    await adminService.approveMember({ communityId, requestId, approve });
    await get().loadAdminDashboard(communityId);
  },
  grantCredits: async ({ communityId, memberId, amount, reason }) => {
    await adminService.grantCredits({ communityId, memberId, amount, reason });
    await get().loadAdminDashboard(communityId);
  },
  removeMember: async ({ communityId, memberId }) => {
    await adminService.removeMember({ communityId, memberId });
    await get().loadAdminDashboard(communityId);
  }
}));
