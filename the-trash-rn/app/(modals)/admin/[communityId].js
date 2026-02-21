import { useLocalSearchParams } from 'expo-router';
import { useEffect, useState } from 'react';
import { Alert, ScrollView, Text, View } from 'react-native';

import ModalSheet from 'src/components/layout/ModalSheet';
import {
  TrashButton,
  TrashInput,
  TrashSegmentedControl
} from 'src/components/themed';
import { useCommunityStore } from 'src/stores/communityStore';

const TABS = [
  { value: 'requests', label: 'Requests' },
  { value: 'members', label: 'Members' },
  { value: 'logs', label: 'Logs' }
];

export default function AdminPanelModal() {
  const { communityId } = useLocalSearchParams();
  const dashboard = useCommunityStore((state) =>
    state.adminDashboard(communityId)
  );
  const loadAdminDashboard = useCommunityStore(
    (state) => state.loadAdminDashboard
  );
  const processRequest = useCommunityStore((state) => state.processRequest);
  const grantCredits = useCommunityStore((state) => state.grantCredits);
  const removeMember = useCommunityStore((state) => state.removeMember);

  const [tab, setTab] = useState('requests');
  const [memberId, setMemberId] = useState('');
  const [amount, setAmount] = useState('10');
  const [reason, setReason] = useState('Contribution');

  useEffect(() => {
    if (communityId) {
      loadAdminDashboard(communityId);
    }
  }, [communityId, loadAdminDashboard]);

  const handleGrantCredits = async () => {
    if (!communityId || !memberId) return;
    try {
      await grantCredits({
        communityId,
        memberId,
        amount: Number(amount) || 0,
        reason
      });
      setMemberId('');
      setAmount('10');
    } catch (error) {
      Alert.alert(
        'Operation failed',
        error.message ?? 'Temporarily unavailable'
      );
    }
  };

  return (
    <ModalSheet title="Community Admin">
      <TrashSegmentedControl options={TABS} value={tab} onChange={setTab} />
      <ScrollView
        showsVerticalScrollIndicator={false}
        contentContainerStyle={{ paddingBottom: 48 }}
      >
        {tab === 'requests' && (
          <View>
            {dashboard.requests.length === 0 ? (
              <Text className="text-white/60 text-sm">No pending requests</Text>
            ) : (
              dashboard.requests.map((request) => (
                <View
                  key={request.id}
                  className="rounded-3xl border border-white/10 p-4 mb-3"
                >
                  <Text className="text-white font-semibold">
                    {request.name}
                  </Text>
                  <Text className="text-white/60 text-xs mb-3">
                    {request.message}
                  </Text>
                  <View className="flex-row gap-3">
                    <TrashButton
                      title="Approve"
                      onPress={() =>
                        processRequest({
                          communityId,
                          requestId: request.id,
                          approve: true
                        })
                      }
                      style={{ flex: 1 }}
                    />
                    <TrashButton
                      title="Reject"
                      variant="outline"
                      onPress={() =>
                        processRequest({
                          communityId,
                          requestId: request.id,
                          approve: false
                        })
                      }
                      style={{ flex: 1 }}
                    />
                  </View>
                </View>
              ))
            )}
          </View>
        )}

        {tab === 'members' && (
          <View>
            {dashboard.members.map((member) => (
              <View
                key={member.id}
                className="rounded-3xl border border-white/10 p-4 mb-3"
              >
                <View className="flex-row justify-between mb-2">
                  <Text className="text-white font-semibold">
                    {member.name}
                  </Text>
                  <Text className="text-white/50 text-xs">{member.role}</Text>
                </View>
                <Text className="text-white/60 text-xs mb-3">
                  Points {member.points ?? 0}
                </Text>
                <View className="flex-row gap-3">
                  <TrashButton
                    title="+10 pts"
                    onPress={async () => {
                      try {
                        await grantCredits({
                          communityId,
                          memberId: member.id,
                          amount: 10,
                          reason: 'Contribution'
                        });
                      } catch (error) {
                        Alert.alert(
                          'Operation failed',
                          error.message ?? 'Temporarily unavailable'
                        );
                      }
                    }}
                    style={{ flex: 1 }}
                  />
                  <TrashButton
                    title="Remove"
                    variant="outline"
                    onPress={() =>
                      removeMember({ communityId, memberId: member.id })
                    }
                    style={{ flex: 1 }}
                  />
                </View>
              </View>
            ))}
            <View className="rounded-3xl border border-white/10 p-4 mt-4">
              <Text className="text-white font-semibold mb-2">
                Manual point grant
              </Text>
              <TrashInput
                label="Member ID"
                value={memberId}
                onChangeText={setMemberId}
                placeholder="mem-1"
              />
              <TrashInput
                label="Points"
                value={amount}
                onChangeText={setAmount}
                keyboardType="number-pad"
                placeholder="10"
              />
              <TrashInput
                label="Reason"
                value={reason}
                onChangeText={setReason}
                placeholder="Detailed note"
              />
              <TrashButton title="Grant" onPress={handleGrantCredits} />
            </View>
          </View>
        )}

        {tab === 'logs' && (
          <View>
            {dashboard.logs.map((log) => (
              <View key={log.id} className="py-3 border-b border-white/10">
                <Text className="text-white font-semibold text-sm">
                  {log.message}
                </Text>
                <Text className="text-white/60 text-xs">{log.timestamp}</Text>
              </View>
            ))}
            {dashboard.logs.length === 0 && (
              <Text className="text-white/60 text-sm">No logs yet</Text>
            )}
          </View>
        )}
      </ScrollView>
    </ModalSheet>
  );
}
