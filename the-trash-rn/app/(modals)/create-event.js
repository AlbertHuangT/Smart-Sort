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
      Alert.alert(
        'Please select a city',
        'Please select a city on the Events page first.'
      );
      return;
    }
    if (!title.trim() || !description.trim()) {
      Alert.alert(
        'Incomplete information',
        'Please fill in title and description'
      );
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
        city: currentCity.city ?? currentCity.name ?? currentCity.id,
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
    <ModalSheet title="Create Event">
      <ScrollView contentContainerStyle={{ paddingBottom: 32 }}>
        <Text className="text-white/60 text-xs mb-2">
          City · {currentCity?.name ?? 'Not selected'}
        </Text>
        <TrashInput
          label="Title"
          placeholder="e.g. Weekend Beach Cleanup"
          value={title}
          onChangeText={setTitle}
        />
        <TrashInput
          label="Event Time (ISO)"
          placeholder="2024-06-22T14:00"
          value={startTime}
          onChangeText={setStartTime}
        />
        <TrashInput
          label="Location"
          placeholder="Jing'an District Civic Center"
          value={venue}
          onChangeText={setVenue}
        />
        <TrashInput
          label="Capacity"
          placeholder="80"
          value={quota}
          onChangeText={setQuota}
          keyboardType="number-pad"
        />
        <TrashInput
          label="Description"
          placeholder="Describe the event highlights"
          value={description}
          onChangeText={setDescription}
          multiline
        />
        <TrashButton
          title="Publish"
          onPress={handleSubmit}
          loading={submitting}
          disabled={submitting}
        />
      </ScrollView>
    </ModalSheet>
  );
}
