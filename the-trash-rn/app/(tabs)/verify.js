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

const CORRECTION_OPTIONS = [
  'Recyclable',
  'Compost',
  'General Waste',
  'Hazardous Waste'
];

export default function VerifyScreen() {
  const router = useRouter();
  const theme = useTheme();
  const spacing = theme.spacing ?? {};
  const captionType = theme.typography?.caption ?? {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  };
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
        <View
          style={{
            width: '100%',
            aspectRatio: 1,
            alignSelf: 'center',
            borderRadius: theme.radii?.card ?? 20,
            overflow: 'hidden'
          }}
        >
          <CameraView
            cameraRef={cameraRef}
            permissionStatus={permission}
            onRequestPermission={requestPermission}
            isActive={scanningState !== 'feedback'}
          />
        </View>
        <View style={{ flex: 1, marginTop: spacing.md ?? 14 }}>
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
            <View style={{ marginTop: spacing.lg ?? 20 }}>
              <Text
                style={{
                  color: theme.palette.textSecondary,
                  marginBottom: spacing.xs ?? 6,
                  fontSize: captionType.size,
                  lineHeight: captionType.lineHeight,
                  letterSpacing: captionType.letterSpacing
                }}
              >
                Correct category
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
                label="Notes (optional)"
                placeholder="Why are you correcting this?"
                value={correctionNote}
                onChangeText={setCorrectionNote}
                autoCapitalize="sentences"
              />
              <TrashButton
                title="Submit correction"
                onPress={handleCorrectionSubmit}
                loading={scanningState === 'feedback'}
                disabled={scanningState === 'feedback'}
              />
            </View>
          ) : null}
        </View>
        <View style={{ marginTop: 'auto', paddingTop: spacing.sm ?? 10 }}>
          <CameraControls
            onCapture={handleCapture}
            onHistory={() => router.push('/(modals)/history')}
            disabled={
              scanningState === 'analyzing' || classifierStatus === 'loading'
            }
            analyzing={scanningState === 'analyzing'}
            style={{ marginTop: 0 }}
          />
          <Text
            style={{
              marginTop: spacing.xs ?? 6,
              textAlign: 'center',
              color: theme.palette.textSecondary,
              opacity: 0.66,
              fontSize: Math.max(10, captionType.size - 1),
              lineHeight: captionType.lineHeight,
              letterSpacing: captionType.letterSpacing
            }}
          >
            AI recognition:
            {classifierStatus === 'ready'
              ? ' Ready'
              : classifierStatus === 'loading'
                ? ' Warming up'
                : ' Not ready'}
            {classifierMeta?.knowledgeCount
              ? ` · vectors ${classifierMeta.knowledgeCount}`
              : ''}
          </Text>
          {classifierError ? (
            <Text
              style={{
                marginTop: 2,
                textAlign: 'center',
                color: theme.palette.danger ?? '#ff8a8a',
                opacity: 0.82,
                fontSize: Math.max(10, captionType.size - 1),
                lineHeight: captionType.lineHeight,
                letterSpacing: captionType.letterSpacing
              }}
            >
              {classifierError}
            </Text>
          ) : null}
        </View>
      </View>
    </ScreenShell>
  );
}
