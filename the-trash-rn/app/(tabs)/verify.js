import { useRouter } from 'expo-router';
import { useEffect, useRef, useState } from 'react';
import { Text, View } from 'react-native';

import CameraControls from 'src/components/camera/CameraControls';
import CameraView from 'src/components/camera/CameraView';
import ResultCard from 'src/components/cards/ResultCard';
import ScreenShell from 'src/components/layout/ScreenShell';
import {
  TrashButton,
  TrashInput,
  TrashSegmentedControl
} from 'src/components/themed';
import { useTrashStore } from 'src/stores/trashStore';
import { useTheme } from 'src/theme/ThemeProvider';

const CORRECTION_OPTIONS = ['可回收', '湿垃圾', '干垃圾', '有害垃圾'];

export default function VerifyScreen() {
  const router = useRouter();
  const theme = useTheme();
  const cameraRef = useRef(null);
  const permission = useTrashStore((state) => state.permission);
  const requestPermission = useTrashStore((state) => state.requestPermission);
  const analyzePhoto = useTrashStore((state) => state.analyzePhoto);
  const scanningState = useTrashStore((state) => state.scanningState);
  const lastResult = useTrashStore((state) => state.lastResult);
  const confirmResult = useTrashStore((state) => state.confirmResult);
  const submitCorrection = useTrashStore((state) => state.submitCorrection);
  const ensureClassifierReady = useTrashStore(
    (state) => state.ensureClassifierReady
  );
  const classifierStatus = useTrashStore((state) => state.classifierStatus);
  const classifierMeta = useTrashStore((state) => state.classifierMeta);
  const classifierError = useTrashStore((state) => state.classifierError);
  const error = useTrashStore((state) => state.error);
  const clearError = useTrashStore((state) => state.clearError);

  const [correctionCategory, setCorrectionCategory] = useState(
    CORRECTION_OPTIONS[0]
  );
  const [correctionNote, setCorrectionNote] = useState('');
  const [showCorrection, setShowCorrection] = useState(false);

  useEffect(() => {
    requestPermission();
  }, [requestPermission]);

  useEffect(() => {
    ensureClassifierReady({ warmup: true }).catch((bootstrapError) => {
      console.warn('[verify] classifier bootstrap failed', bootstrapError);
    });
  }, [ensureClassifierReady]);

  useEffect(() => {
    if (!showCorrection) {
      setCorrectionNote('');
      setCorrectionCategory(CORRECTION_OPTIONS[0]);
    }
  }, [showCorrection]);

  const handleCapture = async () => {
    try {
      const photo = await cameraRef.current?.takePhoto?.({
        qualityPrioritization: 'quality',
        flash: 'off',
        skipMetadata: true
      });
      if (photo) {
        await analyzePhoto(photo);
        setShowCorrection(false);
      }
    } catch (captureError) {
      console.warn('[verify] capture failed', captureError);
    }
  };

  const handleCorrectionSubmit = async () => {
    try {
      await submitCorrection({
        category: correctionCategory,
        note: correctionNote
      });
      setShowCorrection(false);
    } catch (submitError) {
      console.warn('[verify] correction failed', submitError);
    }
  };

  return (
    <ScreenShell title="Verify" useScroll={false}>
      <View style={{ flex: 1 }}>
        <View style={{ flex: 1.2, marginBottom: 24 }}>
          <CameraView
            cameraRef={cameraRef}
            permissionStatus={permission}
            onRequestPermission={requestPermission}
            isActive={scanningState !== 'feedback'}
          />
          <View
            style={{
              marginTop: 12,
              borderRadius: 16,
              borderWidth: 1,
              borderColor: theme.palette.divider ?? 'rgba(255,255,255,0.15)',
              backgroundColor: theme.palette.card,
              paddingHorizontal: 12,
              paddingVertical: 10
            }}
          >
            <Text style={{ color: theme.palette.textSecondary, fontSize: 12 }}>
              AI 引擎：
              {classifierStatus === 'ready'
                ? '已就绪'
                : classifierStatus === 'loading'
                  ? '预热中'
                  : '未就绪'}
              {classifierMeta?.knowledgeCount
                ? ` · 向量 ${classifierMeta.knowledgeCount}`
                : ''}
            </Text>
            {classifierError ? (
              <Text
                style={{
                  color: theme.palette.danger ?? '#ff8a8a',
                  fontSize: 11,
                  marginTop: 4
                }}
              >
                {classifierError}
              </Text>
            ) : null}
          </View>
          <CameraControls
            onCapture={handleCapture}
            onHistory={() => router.push('/(modals)/history')}
            disabled={
              scanningState === 'analyzing' || classifierStatus === 'loading'
            }
            analyzing={scanningState === 'analyzing'}
          />
        </View>
        <View style={{ flex: 1 }}>
          <ResultCard
            result={lastResult}
            onConfirm={() => {
              confirmResult();
              setShowCorrection(false);
            }}
            onCorrect={() => setShowCorrection(true)}
          />
          {error ? (
            <Text
              style={{
                color: theme.palette.danger ?? '#fca5a5',
                fontSize: 12,
                marginTop: 12
              }}
              onPress={clearError}
            >
              {error}
            </Text>
          ) : null}
          {showCorrection ? (
            <View style={{ marginTop: 24 }}>
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  marginBottom: 8,
                  fontSize: 13
                }}
              >
                纠正分类
              </Text>
              <TrashSegmentedControl
                options={CORRECTION_OPTIONS.map((option) => ({
                  label: option,
                  value: option
                }))}
                value={correctionCategory}
                onChange={setCorrectionCategory}
              />
              <TrashInput
                label="备注（可选）"
                placeholder="为什么要纠正？"
                value={correctionNote}
                onChangeText={setCorrectionNote}
                autoCapitalize="sentences"
              />
              <TrashButton
                title="提交纠正"
                onPress={handleCorrectionSubmit}
                loading={scanningState === 'feedback'}
                disabled={scanningState === 'feedback'}
              />
            </View>
          ) : null}
        </View>
      </View>
    </ScreenShell>
  );
}
