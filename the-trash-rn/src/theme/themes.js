const SPACING = {
  xxs: 4,
  xs: 6,
  sm: 10,
  md: 14,
  lg: 20,
  xl: 28,
  xxl: 36,
  xxxl: 44,
  screenHorizontal: 20,
  screenTop: 36,
  screenBottom: 28,
  sectionGap: 28,
  stackGap: 18,
  fieldGap: 16
};

const RADII = {
  card: 20,
  button: 14,
  input: 14,
  segmented: 14,
  pill: 999
};

const SIZES = {
  buttonHeight: 48,
  inputMinHeight: 52,
  segmentedMinHeight: 44,
  inlineActionWidth: 132,
  contentMaxWidth: 680,
  proseMaxWidth: 540
};

const MOTION = {
  durations: {
    tapIn: 110,
    tapOut: 180,
    focus: 200,
    normal: 240,
    slow: 360
  },
  curves: {
    emphasize: [0.22, 1, 0.36, 1],
    standard: [0.3, 0, 0.2, 1],
    decelerate: [0, 0, 0.2, 1]
  },
  springs: {
    pressIn: {
      damping: 18,
      stiffness: 360,
      mass: 0.26
    },
    pressOut: {
      damping: 20,
      stiffness: 320,
      mass: 0.24
    },
    snappy: {
      damping: 18,
      stiffness: 280,
      mass: 0.34
    }
  }
};

const TYPOGRAPHY = {
  display: {
    size: 34,
    lineHeight: 40,
    letterSpacing: -0.82
  },
  title: {
    size: 28,
    lineHeight: 34,
    letterSpacing: -0.48
  },
  body: {
    size: 15,
    lineHeight: 22,
    letterSpacing: 0.12
  },
  label: {
    size: 14,
    lineHeight: 19,
    letterSpacing: 0.18
  },
  caption: {
    size: 12,
    lineHeight: 17,
    letterSpacing: 0.14
  }
};

const COMPONENTS = {
  card: {
    padding: 18
  },
  button: {
    horizontalPadding: 16,
    verticalPadding: 11
  },
  input: {
    horizontalPadding: 14,
    verticalPadding: 11
  },
  segmented: {
    padding: 4
  },
  resultCard: {
    swipeThreshold: 110
  }
};

const ANIMATION = {
  type: 'tactile',
  cardEnterSpring: {
    damping: 18,
    stiffness: 220,
    mass: 0.45
  },
  segmentedSpring: {
    damping: 18,
    stiffness: 280,
    mass: 0.34
  },
  buttonBreath: {
    enabled: false,
    minOpacity: 0.07,
    maxOpacity: 0.18,
    minRadius: 6,
    maxRadius: 14,
    duration: 3200
  }
};

const HAPTICS = {
  buttonImpact: 'none',
  buttonPrimaryImpact: 'light',
  buttonSecondaryImpact: 'none',
  buttonOutlineImpact: 'none',
  buttonGhostImpact: 'none',
  segmentedImpact: 'none'
};

const SHAPE = {
  rounding: 'rounded',
  borderCurve: 'circular',
  cardCornerOffsets: null
};

const SCROLL = {
  decelerationRate: 'normal'
};

const BACKDROP = {
  gradientColors: ['#0a101a', '#0d1624', '#131f33'],
  lights: [],
  frameIntervalMs: 90,
  noiseOpacity: 0,
  noiseTint: '#ffffff',
  noiseSeed: 23,
  noiseFreqX: 0.028,
  noiseFreqY: 0.024,
  noiseOctaves: 3,
  noiseDriftAmplitudeX: 0.8,
  noiseDriftAmplitudeY: 0.6,
  noiseDriftSpeed: 0.03
};

const makeTheme = (config) => ({
  ...config,
  spacing: SPACING,
  radii: { ...RADII, ...(config.radii ?? {}) },
  sizes: { ...SIZES, ...(config.sizes ?? {}) },
  motion: MOTION,
  typography: TYPOGRAPHY,
  animationConfig: {
    ...ANIMATION,
    ...(config.animationConfig ?? {}),
    cardEnterSpring: {
      ...ANIMATION.cardEnterSpring,
      ...(config.animationConfig?.cardEnterSpring ?? {})
    },
    segmentedSpring: {
      ...ANIMATION.segmentedSpring,
      ...(config.animationConfig?.segmentedSpring ?? {})
    },
    buttonBreath: {
      ...ANIMATION.buttonBreath,
      ...(config.animationConfig?.buttonBreath ?? {})
    }
  },
  haptics: { ...HAPTICS, ...(config.haptics ?? {}) },
  shape: { ...SHAPE, ...(config.shape ?? {}) },
  scroll: { ...SCROLL, ...(config.scroll ?? {}) },
  backdrop: { ...BACKDROP, ...(config.backdrop ?? {}) },
  components: {
    card: { ...COMPONENTS.card, ...(config.components?.card ?? {}) },
    button: { ...COMPONENTS.button, ...(config.components?.button ?? {}) },
    input: { ...COMPONENTS.input, ...(config.components?.input ?? {}) },
    segmented: {
      ...COMPONENTS.segmented,
      ...(config.components?.segmented ?? {})
    },
    resultCard: {
      ...COMPONENTS.resultCard,
      ...(config.components?.resultCard ?? {})
    }
  }
});

export const THEMES = {
  neumorphic: makeTheme({
    label: 'Neumorphic',
    description: 'Soft skeuomorphism · dual light and gentle material depth',
    palette: {
      background: '#0b121b',
      card: '#141f2c',
      elevated: '#1a283b',
      overlay: '#23324a',
      textPrimary: '#f2f7ff',
      textSecondary: '#95a8c4',
      textTertiary: '#7b90ae',
      textQuaternary: '#60728d',
      divider: '#2a3c55',
      danger: '#ff7c8f',
      success: '#4cd2aa'
    },
    tabBar: {
      background: '#101a28dd',
      border: '#26364d',
      active: '#5ca9ff',
      inactive: '#8398b5'
    },
    accents: {
      blue: '#5ca9ff',
      green: '#4bd1a6',
      orange: '#ffbf5f',
      purple: '#ae95ff'
    },
    shadows: {
      light: '#3f5a7c',
      dark: '#02060b'
    },
    materialModel: 'industrial-tactile',
    interactionLexicon: 'squash, elasticity, and tactile rebound',
    animationConfig: {
      type: 'tactile',
      cardEnterSpring: {
        damping: 17,
        stiffness: 240,
        mass: 0.42
      },
      segmentedSpring: {
        damping: 16,
        stiffness: 300,
        mass: 0.3
      }
    },
    haptics: {
      buttonImpact: 'medium',
      segmentedImpact: 'none'
    },
    shape: {
      rounding: 'rounded',
      borderCurve: 'continuous'
    },
    backdrop: {
      gradientColors: ['#0d1522', '#122032', '#18293f'],
      lights: [
        {
          color: '#6ea7ff',
          baseX: 0.2,
          baseY: 0.18,
          rangeX: 0.08,
          rangeY: 0.05,
          radius: 0.42,
          opacity: 0.12,
          blur: 58,
          speed: 0.12,
          phase: 0
        },
        {
          color: '#a5b8d7',
          baseX: 0.8,
          baseY: 0.78,
          rangeX: 0.06,
          rangeY: 0.06,
          radius: 0.45,
          opacity: 0.1,
          blur: 64,
          speed: 0.1,
          phase: 1.5
        }
      ],
      noiseOpacity: 0.01,
      noiseTint: '#c8d8f0',
      noiseFreqX: 0.02,
      noiseFreqY: 0.018,
      noiseOctaves: 2,
      frameIntervalMs: 100
    },
    materials: {
      card: {
        gradientColors: ['#1e2d42', '#151f2e'],
        borderColor: 'rgba(184, 205, 234, 0.16)',
        ambientShadow: {
          color: '#01050a',
          opacity: 0.36,
          radius: 28,
          offsetY: 18,
          elevation: 9
        },
        keyShadow: {
          color: '#050b12',
          opacity: 0.22,
          radius: 13,
          offsetY: 8,
          elevation: 4
        },
        highlightShadow: {
          color: '#4a6991',
          opacity: 0.2,
          radius: 12,
          offsetX: -5,
          offsetY: -5
        },
        edgeHighlight: {
          colors: ['rgba(207,226,255,0.34)', 'rgba(207,226,255,0)'],
          height: 44,
          opacity: 0.9
        }
      }
    }
  }),

  paper: makeTheme({
    label: 'Paper',
    description: 'kraft texture · warm layers with soft haze shadows',
    palette: {
      background: '#1a140e',
      card: '#2a1f16',
      elevated: '#332519',
      overlay: '#3f2e1f',
      textPrimary: '#f7efe2',
      textSecondary: '#c2ad98',
      textTertiary: '#a58f7b',
      textQuaternary: '#857160',
      divider: '#503a28',
      danger: '#ff8f73',
      success: '#74d493'
    },
    tabBar: {
      background: '#140d08ee',
      border: '#332318',
      active: '#ffbf63',
      inactive: '#a4937f'
    },
    accents: {
      blue: '#7fd4ff',
      green: '#75d79a',
      orange: '#ffbf63',
      purple: '#c98df5'
    },
    shadows: {
      light: '#3a2819',
      dark: '#0b0704'
    },
    materialModel: 'analogue-paper',
    interactionLexicon: 'damping, friction, and ink diffusion',
    animationConfig: {
      type: 'analogue-damped',
      cardEnterSpring: {
        damping: 24,
        stiffness: 180,
        mass: 0.6
      },
      segmentedSpring: {
        damping: 22,
        stiffness: 190,
        mass: 0.5
      }
    },
    haptics: {
      buttonImpact: 'rigid',
      segmentedImpact: 'none'
    },
    shape: {
      rounding: 'rounded',
      borderCurve: 'continuous'
    },
    scroll: {
      decelerationRate: 0.985
    },
    backdrop: {
      gradientColors: ['#1e160f', '#261c14', '#312316'],
      lights: [
        {
          color: '#f1d4aa',
          baseX: 0.15,
          baseY: 0.2,
          rangeX: 0.04,
          rangeY: 0.03,
          radius: 0.34,
          opacity: 0.07,
          blur: 36,
          speed: 0.06,
          phase: 0.2
        },
        {
          color: '#9c6b3f',
          baseX: 0.82,
          baseY: 0.8,
          rangeX: 0.03,
          rangeY: 0.04,
          radius: 0.4,
          opacity: 0.06,
          blur: 44,
          speed: 0.05,
          phase: 1.4
        }
      ],
      noiseOpacity: 0.026,
      noiseTint: '#f8e8cf',
      noiseFreqX: 0.018,
      noiseFreqY: 0.014,
      noiseOctaves: 2,
      frameIntervalMs: 130
    },
    materials: {
      card: {
        gradientColors: ['#362718', '#281e15'],
        borderColor: 'rgba(255, 236, 209, 0.12)',
        ambientShadow: {
          color: '#090502',
          opacity: 0.32,
          radius: 24,
          offsetY: 15,
          elevation: 8
        },
        keyShadow: {
          color: '#140d07',
          opacity: 0.2,
          radius: 11,
          offsetY: 6,
          elevation: 3
        },
        highlightShadow: {
          color: '#5a4128',
          opacity: 0.14,
          radius: 10,
          offsetX: -4,
          offsetY: -4
        },
        edgeHighlight: {
          colors: ['rgba(255,239,214,0.22)', 'rgba(255,239,214,0)'],
          height: 34,
          opacity: 0.7
        }
      }
    }
  }),

  neon: makeTheme({
    label: 'Neon Glass',
    description: 'neon glass · high-contrast layers with glow bloom',
    palette: {
      background: '#040814',
      card: '#13203a',
      elevated: '#172949',
      overlay: '#22365d',
      textPrimary: '#f7f9ff',
      textSecondary: '#8d9fbe',
      textTertiary: '#7288aa',
      textQuaternary: '#5e7394',
      divider: '#2b4369',
      danger: '#ff7686',
      success: '#73dfc4'
    },
    tabBar: {
      background: '#050b1cdd',
      border: '#1a2b4a',
      active: '#59d9ee',
      inactive: '#8194b5'
    },
    accents: {
      blue: '#59d9ee',
      green: '#89e8cd',
      orange: '#ffbe5f',
      purple: '#c09bff'
    },
    shadows: {
      light: '#1a2442',
      dark: '#000000'
    },
    materialModel: 'light-signal',
    interactionLexicon: 'pulse, instant response, and energy trails',
    animationConfig: {
      type: 'pulse',
      cardEnterSpring: {
        damping: 14,
        stiffness: 330,
        mass: 0.28
      },
      segmentedSpring: {
        damping: 12,
        stiffness: 360,
        mass: 0.24
      },
      buttonBreath: {
        enabled: true,
        minOpacity: 0.11,
        maxOpacity: 0.22,
        minRadius: 8,
        maxRadius: 16,
        duration: 2100
      }
    },
    haptics: {
      buttonImpact: 'light',
      segmentedImpact: 'none'
    },
    shape: {
      rounding: 'rounded',
      borderCurve: 'continuous'
    },
    backdrop: {
      gradientColors: ['#070b1b', '#101a34', '#1b1540'],
      lights: [
        {
          color: '#5bdcf7',
          baseX: 0.18,
          baseY: 0.16,
          rangeX: 0.12,
          rangeY: 0.08,
          radius: 0.44,
          opacity: 0.14,
          blur: 64,
          speed: 0.22,
          phase: 0
        },
        {
          color: '#b29aff',
          baseX: 0.82,
          baseY: 0.22,
          rangeX: 0.1,
          rangeY: 0.09,
          radius: 0.4,
          opacity: 0.12,
          blur: 60,
          speed: 0.2,
          phase: 1.2
        },
        {
          color: '#65ffd7',
          baseX: 0.55,
          baseY: 0.84,
          rangeX: 0.08,
          rangeY: 0.06,
          radius: 0.38,
          opacity: 0.11,
          blur: 52,
          speed: 0.24,
          phase: 2.4
        }
      ],
      noiseOpacity: 0.012,
      noiseTint: '#8fb8ff',
      noiseFreqX: 0.032,
      noiseFreqY: 0.028,
      noiseOctaves: 3,
      frameIntervalMs: 70
    },
    materials: {
      card: {
        gradientColors: ['#20345a', '#142341'],
        borderColor: 'rgba(120, 205, 237, 0.24)',
        ambientShadow: {
          color: '#01030a',
          opacity: 0.4,
          radius: 28,
          offsetY: 20,
          elevation: 10
        },
        keyShadow: {
          color: '#0a1228',
          opacity: 0.24,
          radius: 16,
          offsetY: 8,
          elevation: 4
        },
        highlightShadow: {
          color: '#4f75b5',
          opacity: 0.18,
          radius: 12,
          offsetX: -5,
          offsetY: -5
        },
        glow: {
          color: '#59d9ee',
          opacity: 0.18,
          radius: 20,
          offsetY: 0
        },
        edgeHighlight: {
          colors: ['rgba(124,215,255,0.3)', 'rgba(124,215,255,0)'],
          height: 38,
          opacity: 0.8
        }
      }
    }
  }),

  eco: makeTheme({
    label: 'Eco Green',
    description: 'eco forest · natural gradients with translucent green glow',
    palette: {
      background: '#06140e',
      card: '#1f4331',
      elevated: '#2a5540',
      overlay: '#346850',
      textPrimary: '#eaf8ef',
      textSecondary: '#b8d7c3',
      textTertiary: '#9fc5ad',
      textQuaternary: '#84a790',
      divider: '#5a8d74',
      danger: '#ff8d79',
      success: '#77dcaa'
    },
    tabBar: {
      background: '#0a1b12dd',
      border: '#3b6e56',
      active: '#77dcaa',
      inactive: '#96bca5'
    },
    accents: {
      blue: '#77dcaa',
      green: '#77dcaa',
      orange: '#f5c151',
      purple: '#9bd64a'
    },
    shadows: {
      light: '#1b3626',
      dark: '#030907'
    },
    materialModel: 'organic',
    interactionLexicon: 'slow, growing, and smooth transitions',
    animationConfig: {
      type: 'organic-grow',
      cardEnterSpring: {
        damping: 22,
        stiffness: 115,
        mass: 0.8
      },
      segmentedSpring: {
        damping: 24,
        stiffness: 130,
        mass: 0.72
      },
      buttonBreath: {
        enabled: true,
        minOpacity: 0.06,
        maxOpacity: 0.16,
        minRadius: 6,
        maxRadius: 12,
        duration: 3600
      }
    },
    haptics: {
      buttonImpact: 'soft',
      segmentedImpact: 'none',
      buttonSecondaryImpact: 'none',
      buttonOutlineImpact: 'none',
      buttonGhostImpact: 'none'
    },
    shape: {
      rounding: 'squircle',
      borderCurve: 'continuous',
      cardCornerOffsets: {
        topLeft: 1,
        topRight: -1,
        bottomRight: 2,
        bottomLeft: 0
      }
    },
    scroll: {
      decelerationRate: 0.992
    },
    noiseOpacity: 0.02,
    backdrop: {
      gradientColors: ['#0a1a13', '#122a1f', '#1b3b2b'],
      lights: [
        {
          color: '#bde9a4',
          baseX: 0.14,
          baseY: 0.12,
          rangeX: 0.05,
          rangeY: 0.04,
          radius: 0.36,
          opacity: 0.1,
          blur: 44,
          speed: 0.08,
          phase: 0
        },
        {
          color: '#7edbaf',
          baseX: 0.88,
          baseY: 0.25,
          rangeX: 0.04,
          rangeY: 0.04,
          radius: 0.34,
          opacity: 0.09,
          blur: 46,
          speed: 0.07,
          phase: 1.1
        },
        {
          color: '#f4d389',
          baseX: 0.64,
          baseY: 0.82,
          rangeX: 0.03,
          rangeY: 0.05,
          radius: 0.32,
          opacity: 0.08,
          blur: 40,
          speed: 0.05,
          phase: 2.3
        }
      ],
      frameIntervalMs: 110,
      noiseOpacity: 0.022,
      noiseTint: '#d9f0d2',
      noiseSeed: 41,
      noiseFreqX: 0.022,
      noiseFreqY: 0.018,
      noiseOctaves: 3,
      noiseDriftAmplitudeX: 1.2,
      noiseDriftAmplitudeY: 1,
      noiseDriftSpeed: 0.042
    },
    materials: {
      card: {
        gradientColors: ['#2c5a43', '#1f4130'],
        borderColor: 'rgba(197, 244, 215, 0.36)',
        ambientShadow: {
          color: '#04140d',
          opacity: 0.38,
          radius: 24,
          offsetY: 18,
          elevation: 8
        },
        keyShadow: {
          color: '#0a1f15',
          opacity: 0.24,
          radius: 12,
          offsetY: 7,
          elevation: 3
        },
        highlightShadow: {
          color: '#66a486',
          opacity: 0.2,
          radius: 13,
          offsetX: -5,
          offsetY: -5
        },
        glow: {
          color: '#77dcaa',
          opacity: 0.14,
          radius: 20,
          offsetY: 0
        },
        edgeHighlight: {
          colors: ['rgba(196,242,207,0.34)', 'rgba(196,242,207,0)'],
          height: 52,
          opacity: 1
        }
      }
    }
  })
};

export const DEFAULT_THEME = 'neon';
