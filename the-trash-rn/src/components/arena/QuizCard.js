import { Pressable, Text, View } from 'react-native';

export default function QuizCard({ question, onAnswer, mode }) {
  if (!question) {
    return (
      <View className="rounded-3xl border border-white/10 bg-white/5 p-6">
        <Text className="text-white/70 text-sm">加载题目中…</Text>
      </View>
    );
  }

  return (
    <View className="rounded-3xl border border-white/10 bg-white/5 p-6">
      <Text className="text-brand-neon text-xs mb-2 uppercase tracking-[0.4em]">
        {mode}
      </Text>
      <Text className="text-white font-semibold text-xl mb-4">{question.prompt}</Text>
      {question.options?.map((option) => (
        <Pressable
          key={option}
          onPress={() => onAnswer?.(option)}
          className="rounded-2xl border border-white/10 p-4 mb-3"
        >
          <Text className="text-white text-base">{option}</Text>
        </Pressable>
      ))}
    </View>
  );
}
