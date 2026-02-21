import { hasSupabaseConfig } from 'src/services/config';

import { supabase } from './supabase';

const EDGE_FEEDBACK_FUNCTION = 'verify-feedback';

export const feedbackService = {
  async submitFeedback({ resultId, correction, note, photo }) {
    if (!resultId && !correction) {
      throw new Error('Feedback content is required');
    }

    if (!hasSupabaseConfig()) {
      return { success: true, mocked: true };
    }

    try {
      const { data, error } = await supabase.functions.invoke(
        EDGE_FEEDBACK_FUNCTION,
        {
          body: {
            resultId,
            correction,
            note,
            photo
          }
        }
      );
      if (error) {
        throw error;
      }
      return data;
    } catch (error) {
      console.warn('[feedback] submit failed', error);
      throw new Error(
        error.message ?? 'Failed to send feedback. Please try again later.'
      );
    }
  }
};
