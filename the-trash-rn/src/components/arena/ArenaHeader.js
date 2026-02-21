import { Text, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

const statusLabel = (status) => {
  switch (status) {
    case 'loading':
      return 'Loading';
    case 'lobby':
      return 'Waiting to ready';
    case 'countdown':
      return 'Countdown';
    case 'playing':
      return 'In duel';
    case 'waiting-result':
      return 'Waiting for opponent';
    case 'finalizing':
      return 'Settling';
    case 'completed':
      return 'Completed';
    default:
      return status || 'Unknown status';
  }
};

function ReadyDot({ active, color, label, textColor, captionType }) {
  return (
    <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6 }}>
      <View
        style={{
          width: 8,
          height: 8,
          borderRadius: 99,
          backgroundColor: active ? color : 'rgba(148, 163, 184, 0.45)'
        }}
      />
      <Text
        style={{
          color: textColor,
          fontSize: captionType.size,
          lineHeight: captionType.lineHeight,
          letterSpacing: captionType.letterSpacing
        }}
      >
        {label}
      </Text>
    </View>
  );
}

export default function ArenaHeader({
  status,
  opponent,
  countdown,
  myReady,
  opponentReady,
  opponentOnline,
  myScore = 0,
  opponentScore = 0,
  myProgress = 0,
  opponentProgress = 0,
  totalQuestions = 0
}) {
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const radii = theme.radii ?? {};
  const bodyType = theme.typography?.body ?? {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  };
  const labelType = theme.typography?.label ?? {
    size: 14,
    lineHeight: 19,
    letterSpacing: 0.18
  };
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };

  return (
    <View
      style={{
        borderRadius: radii.card ?? 20,
        borderWidth: 1,
        borderColor: theme.tabBar.border,
        backgroundColor: theme.palette.card,
        padding: spacing.md ?? 14,
        marginBottom: spacing.md ?? 14,
        gap: spacing.sm ?? 10
      }}
    >
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <View style={{ flex: 1, paddingRight: 10 }}>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              fontSize: bodyType.size + 2,
              lineHeight: bodyType.lineHeight + 2,
              letterSpacing: bodyType.letterSpacing
            }}
            numberOfLines={1}
          >
            {opponent ?? 'Waiting for opponent'}
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              marginTop: 2,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            Status: {statusLabel(status)}
            {status === 'countdown' && Number.isFinite(countdown)
              ? ` · ${countdown}s`
              : ''}
          </Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            My score {myScore}
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: captionType.size,
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing,
              marginTop: 2
            }}
          >
            Opponent score {opponentScore}
          </Text>
        </View>
      </View>

      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <ReadyDot
          active={myReady}
          color={theme.accents.green}
          label="I am ready"
          textColor={theme.palette.textSecondary}
          captionType={captionType}
        />
        <ReadyDot
          active={opponentReady}
          color={theme.accents.blue}
          label={opponentOnline ? 'Opponent online' : 'Opponent offline'}
          textColor={theme.palette.textSecondary}
          captionType={captionType}
        />
      </View>

      <Text
        style={{
          color: theme.palette.textSecondary,
          fontSize: labelType.size,
          lineHeight: labelType.lineHeight,
          letterSpacing: labelType.letterSpacing
        }}
      >
        Progress {myProgress}/{totalQuestions || '—'} · Opponent{' '}
        {opponentProgress}/{totalQuestions || '—'}
      </Text>
    </View>
  );
}
