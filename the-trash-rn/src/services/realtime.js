import { supabase } from './supabase';

const toStringId = (value) => {
  if (value == null) return null;
  return String(value);
};

const pickUserId = (payload) =>
  toStringId(payload?.userId ?? payload?.user_id ?? payload?.uid);

const noop = () => {};

export const realtimeService = {
  joinDuel(id, handlers = {}, options = {}) {
    if (!id) {
      return {
        send: noop,
        sendReady: noop,
        sendAnswerSubmitted: noop,
        sendFinished: noop,
        unsubscribe: noop
      };
    }
    const channelName = options.channelName || `duel:${id}`;
    const myUserId = toStringId(options.myUserId);
    const opponentUserId = toStringId(options.opponentUserId);

    const channel = supabase.channel(channelName, {
      config: {
        broadcast: { self: false },
        presence: {
          key: myUserId ?? `guest-${Date.now()}`
        }
      }
    });

    const emitPresence = () => {
      if (!handlers.onPresence) return;
      const state = channel.presenceState?.() ?? {};
      const onlineIds = Object.values(state)
        .flat()
        .map((presence) =>
          toStringId(
            presence?.userId ??
              presence?.user_id ??
              presence?.uid ??
              presence?.key
          )
        )
        .filter(Boolean);
      const uniqueOnline = Array.from(new Set(onlineIds));
      const opponentOnline = opponentUserId
        ? uniqueOnline.includes(opponentUserId)
        : uniqueOnline.length > 1;
      handlers.onPresence({
        opponentOnline,
        onlineIds: uniqueOnline
      });
    };

    channel
      .on('broadcast', { event: 'state' }, (payload) => {
        handlers.onState?.(payload.payload);
      })
      .on('broadcast', { event: 'player_ready' }, ({ payload }) => {
        const userId = pickUserId(payload);
        handlers.onPlayerReady?.({
          userId,
          isOpponent: Boolean(
            userId && opponentUserId && userId === opponentUserId
          )
        });
      })
      .on('broadcast', { event: 'answer_submitted' }, ({ payload }) => {
        const userId = pickUserId(payload);
        handlers.onAnswerSubmitted?.({
          userId,
          questionIndex: Number(
            payload?.questionIndex ?? payload?.question_index ?? 0
          ),
          isCorrect: Boolean(payload?.isCorrect ?? payload?.is_correct)
        });
      })
      .on('broadcast', { event: 'player_finished' }, ({ payload }) => {
        const userId = pickUserId(payload);
        handlers.onPlayerFinished?.({
          userId,
          totalCorrect: Number(
            payload?.totalCorrect ?? payload?.total_correct ?? 0
          ),
          totalScore: Number(payload?.totalScore ?? payload?.total_score ?? 0)
        });
      })
      .on('presence', { event: 'sync' }, emitPresence)
      .on('presence', { event: 'join' }, emitPresence)
      .on('presence', { event: 'leave' }, emitPresence)
      .subscribe((status) => {
        handlers.onStatusChange?.(status);
        if (status === 'SUBSCRIBED' && myUserId) {
          channel
            .track({
              userId: myUserId,
              onlineAt: new Date().toISOString()
            })
            .catch((error) => {
              console.warn('[realtime] presence track failed', error);
            });
        }
      });

    const broadcast = (event, payload) =>
      channel.send({
        type: 'broadcast',
        event,
        payload
      });

    return {
      send: (state) => broadcast('state', state),
      sendReady: () =>
        broadcast('player_ready', {
          userId: myUserId,
          timestamp: new Date().toISOString()
        }),
      sendAnswerSubmitted: ({ questionIndex, isCorrect }) =>
        broadcast('answer_submitted', {
          userId: myUserId,
          questionIndex,
          isCorrect,
          timestamp: new Date().toISOString()
        }),
      sendFinished: ({ totalCorrect, totalScore }) =>
        broadcast('player_finished', {
          userId: myUserId,
          totalCorrect,
          totalScore,
          timestamp: new Date().toISOString()
        }),
      unsubscribe: () => {
        channel.unsubscribe();
        supabase.removeChannel(channel);
      }
    };
  }
};
