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
      Alert.alert('Please select a city', 'Please select a city first');
      return;
    }
    if (!name.trim()) {
      Alert.alert('Incomplete information', 'Please enter a community name');
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
      Alert.alert('Create failed', error.message ?? 'Please try again later');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <ModalSheet title="Create Community">
      <ScrollView contentContainerStyle={{ paddingBottom: 32 }}>
        <Text className="text-white/60 text-xs mb-2">
          City · {currentCity?.name ?? 'Not selected'}
        </Text>
        <TrashInput
          label="Name"
          placeholder="Hongkou Eco Team"
          value={name}
          onChangeText={setName}
        />
        <TrashInput
          label="Bio"
          placeholder="Describe your community mission and members"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        <TrashButton
          title="Create"
          onPress={handleCreate}
          loading={submitting}
          disabled={submitting}
        />
      </ScrollView>
    </ModalSheet>
  );
}
