import { supabase } from './supabase';

const EDGE_FEEDBACK_FUNCTION = 'verify-feedback';
const hasSupabaseConfig = Boolean(
  process.env.EXPO_PUBLIC_SUPABASE_URL && process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY
);

export const feedbackService = {
  async submitFeedback({ resultId, correction, note, photo }) {
    if (!resultId && !correction) {
      throw new Error('缺少反馈内容');
    }

    if (!hasSupabaseConfig) {
      console.log('[feedback] mock submit', { resultId, correction, note });
      return { mocked: true };
    }

    try {
      const { data, error } = await supabase.functions.invoke(EDGE_FEEDBACK_FUNCTION, {
        body: {
          resultId,
          correction,
          note,
          photo
        }
      });
      if (error) {
        throw error;
      }
      return data;
    } catch (error) {
      console.warn('[feedback] submit failed', error);
      throw new Error(error.message ?? '反馈失败，请稍后再试');
    }
  }
};
