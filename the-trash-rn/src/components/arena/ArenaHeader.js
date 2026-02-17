import { Text, View } from 'react-native';

import { useTheme } from 'src/theme/ThemeProvider';

const statusLabel = (status) => {
  switch (status) {
    case 'loading':
      return '加载中';
    case 'lobby':
      return '等待准备';
    case 'countdown':
      return '倒计时';
    case 'playing':
      return '对战进行中';
    case 'waiting-result':
      return '等待对手';
    case 'finalizing':
      return '结算中';
    case 'completed':
      return '已完成';
    default:
      return status || '未知状态';
  }
};

function ReadyDot({ active, color, label, textColor }) {
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
      <Text style={{ color: textColor, fontSize: 11 }}>{label}</Text>
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

  return (
    <View
      style={{
        borderRadius: 24,
        borderWidth: 1,
        borderColor: theme.tabBar.border,
        backgroundColor: theme.palette.card,
        padding: 14,
        marginBottom: 14,
        gap: 10
      }}
    >
      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <View style={{ flex: 1, paddingRight: 10 }}>
          <Text
            style={{
              color: theme.palette.textPrimary,
              fontWeight: '700',
              fontSize: 17
            }}
            numberOfLines={1}
          >
            {opponent ?? '等待对手'}
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              marginTop: 2,
              fontSize: 12
            }}
          >
            状态：{statusLabel(status)}
            {status === 'countdown' && Number.isFinite(countdown)
              ? ` · ${countdown}s`
              : ''}
          </Text>
        </View>
        <View style={{ alignItems: 'flex-end' }}>
          <Text style={{ color: theme.palette.textSecondary, fontSize: 11 }}>
            我的分数 {myScore}
          </Text>
          <Text
            style={{
              color: theme.palette.textSecondary,
              fontSize: 11,
              marginTop: 2
            }}
          >
            对手分数 {opponentScore}
          </Text>
        </View>
      </View>

      <View style={{ flexDirection: 'row', justifyContent: 'space-between' }}>
        <ReadyDot
          active={myReady}
          color={theme.accents.green}
          label="我已准备"
          textColor={theme.palette.textSecondary}
        />
        <ReadyDot
          active={opponentReady}
          color={theme.accents.blue}
          label={opponentOnline ? '对手在线' : '对手离线'}
          textColor={theme.palette.textSecondary}
        />
      </View>

      <Text style={{ color: theme.palette.textSecondary, fontSize: 11 }}>
        进度 {myProgress}/{totalQuestions || '—'} · 对手 {opponentProgress}/
        {totalQuestions || '—'}
      </Text>
    </View>
  );
}
