import { create } from 'zustand';
import { supabase } from 'src/services/supabase';

const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

const emptyStats = {
  scans: 0,
  arenaWins: 0,
  credits: 0
};

const getCurrentUser = async () => {
  const { data, error } = await supabase.auth.getUser();
  if (error) {
    throw new Error(error.message);
  }
  return data.user ?? null;
};

const fetchStats = async () => {
  if (!hasSupabaseConfig) {
    return { ...emptyStats };
  }
  const user = await getCurrentUser();
  if (!user) {
    return { ...emptyStats };
  }

  const [{ data: profileRow, error: profileError }, { data: challengeRows, error: challengeError }] =
    await Promise.all([
      supabase
        .from('profiles')
        .select('credits,total_scans')
        .eq('id', user.id)
        .maybeSingle(),
      supabase.rpc('get_my_challenges', { p_status: 'completed' })
    ]);

  if (profileError) {
    throw new Error(profileError.message);
  }
  if (challengeError) {
    throw new Error(challengeError.message);
  }

  const completedChallenges = Array.isArray(challengeRows) ? challengeRows : [];
  const arenaWins = completedChallenges.filter((item) => item.winner_id === user.id).length;

  return {
    scans: profileRow?.total_scans ?? 0,
    arenaWins,
    credits: profileRow?.credits ?? 0
  };
};

export const useProfileStore = create((set) => ({
  stats: null,
  loading: false,
  error: null,
  hydrate: async () => {
    set({ loading: true, error: null });
    try {
      const stats = await fetchStats();
      set({ stats, loading: false });
    } catch (error) {
      set({ stats: { ...emptyStats }, loading: false, error: error.message });
    }
  }
}));
