import { useRouter } from 'expo-router';
import { useState } from 'react';
import { Alert, ScrollView, Text } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import { TrashButton, TrashInput } from 'src/components/themed';
import { useCommunityStore } from 'src/stores/communityStore';
import { useLocationStore } from 'src/stores/locationStore';

export default function CreateCommunityModal() {
  const router = useRouter();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const currentCity = useLocationStore((state) => state.currentCity);
  const createCommunity = useCommunityStore((state) => state.createCommunity);

  const handleCreate = async () => {
    if (!currentCity) {
      Alert.alert('请选择城市', '请先选择城市');
      return;
    }
    if (!name.trim()) {
      Alert.alert('信息不完整', '请输入社群名称');
      return;
    }
    try {
      setSubmitting(true);
      await createCommunity({
        name: name.trim(),
        description: description.trim(),
        cityId: currentCity.id,
        city: currentCity.city ?? currentCity.name ?? currentCity.id,
        state: currentCity.state,
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
    <ModalSheet title="创建社群">
      <ScrollView contentContainerStyle={{ paddingBottom: 32 }}>
        <Text className="text-white/60 text-xs mb-2">
          城市 · {currentCity?.name ?? '未选择'}
        </Text>
        <TrashInput
          label="名称"
          placeholder="虹口环保队"
          value={name}
          onChangeText={setName}
        />
        <TrashInput
          label="简介"
          placeholder="介绍社群的使命与成员"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        <TrashButton
          title="创建"
          onPress={handleCreate}
          loading={submitting}
          disabled={submitting}
        />
      </ScrollView>
    </ModalSheet>
  );
}
