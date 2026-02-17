import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, ScrollView, Text } from 'react-native';
import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { useCommunityStore } from 'src/stores/communityStore';
import { useLocationStore } from 'src/stores/locationStore';

export default function CreateEventModal() {
  const router = useRouter();
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [venue, setVenue] = useState('');
  const [startTime, setStartTime] = useState('');
  const [quota, setQuota] = useState('80');
  const [submitting, setSubmitting] = useState(false);
  const createEvent = useCommunityStore((state) => state.createEvent);
  const currentCity = useLocationStore((state) => state.currentCity);

  const handleSubmit = async () => {
    if (!currentCity) {
      Alert.alert('请选择城市', '请先在活动页选择城市。');
      return;
    }
    if (!title.trim() || !description.trim()) {
      Alert.alert('信息不完整', '请填写标题和描述');
      return;
    }
    try {
      setSubmitting(true);
      await createEvent({
        title: title.trim(),
        description: description.trim(),
        venue: venue.trim(),
        startTime,
        quota: Number(quota) || 50,
        cityId: currentCity.id,
        latitude: currentCity.latitude,
        longitude: currentCity.longitude
      });
      router.back();
    } catch (error) {
      Alert.alert('创建失败', error.message ?? '请稍后再试');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalSheet title="创建活动">
      <ScrollView contentContainerStyle={{ paddingBottom: 32 }}>
        <Text className="text-white/60 text-xs mb-2">城市 · {currentCity?.name ?? '未选择'}</Text>
        <TrashInput label="标题" placeholder="例如：周末净滩" value={title} onChangeText={setTitle} />
        <TrashInput
          label="活动时间 (ISO)"
          placeholder="2024-06-22T14:00"
          value={startTime}
          onChangeText={setStartTime}
        />
        <TrashInput label="地点" placeholder="静安区市民中心" value={venue} onChangeText={setVenue} />
        <TrashInput
          label="名额"
          placeholder="80"
          value={quota}
          onChangeText={setQuota}
          keyboardType="number-pad"
        />
        <TrashInput
          label="描述"
          placeholder="介绍一下活动亮点"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        <TrashButton title="发布" onPress={handleSubmit} loading={submitting} disabled={submitting} />
      </ScrollView>
    </ModalSheet>
  );
}
