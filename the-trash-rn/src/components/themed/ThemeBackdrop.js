import {
  BlurMask,
  Canvas,
  Circle,
  Fill,
  FractalNoise,
  LinearGradient,
  Rect,
  useClock,
  vec
} from '@shopify/react-native-skia';
import { StyleSheet, View, useWindowDimensions } from 'react-native';
import { useDerivedValue } from 'react-native-reanimated';

import { useTheme } from 'src/theme/ThemeProvider';

const DEFAULT_LIGHTS = [
  {
    color: '#ffffff',
    baseX: 0.2,
    baseY: 0.2,
    rangeX: 0.06,
    rangeY: 0.05,
    radius: 0.4,
    opacity: 0.08,
    blur: 52,
    speed: 0.08,
    phase: 0
  },
  {
    color: '#ffffff',
    baseX: 0.8,
    baseY: 0.8,
    rangeX: 0.05,
    rangeY: 0.05,
    radius: 0.42,
    opacity: 0.06,
    blur: 60,
    speed: 0.06,
    phase: 1.4
  }
];

const clamp = (value, min, max) => Math.max(min, Math.min(max, value));

function LightOrb({ light, width, height, clock, stepSeconds }) {
  const baseX = light.baseX ?? 0.5;
  const baseY = light.baseY ?? 0.5;
  const speed = light.speed ?? 0.08;
  const phase = light.phase ?? 0;
  const rangeX = light.rangeX ?? 0;
  const rangeY = light.rangeY ?? 0;

  const cx = useDerivedValue(() => {
    'worklet';
    const seconds = clock.value / 1000;
    const snapped = Math.floor(seconds / stepSeconds) * stepSeconds;
    const t = snapped * speed + phase;
    return width * (baseX + Math.sin(t) * rangeX);
  }, [baseX, clock, phase, rangeX, speed, stepSeconds, width]);

  const cy = useDerivedValue(() => {
    'worklet';
    const seconds = clock.value / 1000;
    const snapped = Math.floor(seconds / stepSeconds) * stepSeconds;
    const t = snapped * speed + phase;
    return height * (baseY + Math.cos(t * 0.92 + 0.18) * rangeY);
  }, [baseY, clock, height, phase, rangeY, speed, stepSeconds]);

  const radius =
    Math.max(width, height) * clamp(light.radius ?? 0.4, 0.12, 0.65);

  return (
    <Circle
      cx={cx}
      cy={cy}
      r={radius}
      color={light.color ?? '#ffffff'}
      opacity={light.opacity ?? 0.08}
    >
      <BlurMask blur={light.blur ?? 52} style="normal" />
    </Circle>
  );
}

export default function ThemeBackdrop({ style }) {
  const theme = useTheme();
  const { width, height } = useWindowDimensions();
  const clock = useClock();

  const backdrop = theme.backdrop ?? {};
  const lights = backdrop.lights?.length ? backdrop.lights : DEFAULT_LIGHTS;
  const gradientColors = backdrop.gradientColors?.length
    ? backdrop.gradientColors
    : [theme.palette.background, theme.palette.background];
  const noiseOpacity = backdrop.noiseOpacity ?? theme.noiseOpacity ?? 0;
  const noiseTint = backdrop.noiseTint ?? '#ffffff';
  const noiseFreqX = backdrop.noiseFreqX ?? 0.028;
  const noiseFreqY = backdrop.noiseFreqY ?? 0.024;
  const noiseOctaves = backdrop.noiseOctaves ?? 3;
  const noiseSeed = backdrop.noiseSeed ?? 23;
  const frameIntervalMs = backdrop.frameIntervalMs ?? 16;
  const stepSeconds = Math.max(1 / 120, frameIntervalMs / 1000);

  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFillObject, style]}>
      <Canvas pointerEvents="none" style={StyleSheet.absoluteFillObject}>
        <Rect x={0} y={0} width={width} height={height}>
          <LinearGradient
            start={vec(0, 0)}
            end={vec(width, height)}
            colors={gradientColors}
          />
        </Rect>

        {lights.map((light, idx) => (
          <LightOrb
            key={`light-${idx}`}
            light={light}
            width={width}
            height={height}
            clock={clock}
            stepSeconds={stepSeconds}
          />
        ))}

        {noiseOpacity > 0 ? (
          <Fill opacity={noiseOpacity}>
            <FractalNoise
              freqX={noiseFreqX}
              freqY={noiseFreqY}
              octaves={noiseOctaves}
              seed={noiseSeed}
              tileWidth={Math.max(1, Math.round(width))}
              tileHeight={Math.max(1, Math.round(height))}
            />
          </Fill>
        ) : null}

        {noiseOpacity > 0 ? (
          <Rect
            x={0}
            y={0}
            width={width}
            height={height}
            color={noiseTint}
            opacity={noiseOpacity * 0.06}
          />
        ) : null}
      </Canvas>
    </View>
  );
}
