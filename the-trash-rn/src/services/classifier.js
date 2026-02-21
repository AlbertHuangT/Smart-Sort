import * as FileSystem from 'expo-file-system';
import { NativeModules, Platform } from 'react-native';

import knowledgeRows from '../../assets/trash_knowledge.json';

const edgeFunctionUrl = process.env.EXPO_PUBLIC_SUPABASE_EDGE_FUNCTION_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY;
const classifierMode = process.env.EXPO_PUBLIC_CLASSIFIER_MODE ?? 'local-only';
const allowSketchFallback =
  process.env.EXPO_PUBLIC_ALLOW_SKETCH_FALLBACK === '1';
const parsedThreshold = Number(process.env.EXPO_PUBLIC_CLASSIFIER_THRESHOLD);
const mobileClipModule = NativeModules?.MobileClipModule ?? null;

const CONFIDENCE_THRESHOLD =
  Number.isFinite(parsedThreshold) && parsedThreshold > 0 && parsedThreshold < 1
    ? parsedThreshold
    : 0.22;
const SEARCH_CHUNK_SIZE = 64;
const LOCAL_SKETCH_SAMPLE_SIZE = 4096;

const CATEGORY_MAP = {
  recycle: 'Recyclable',
  recyclable: 'Recyclable',
  compost: 'Compost',
  compostable: 'Compost',
  landfill: 'General Waste',
  hazardous: 'Hazardous Waste',
  ignore: 'Unrecognized'
};

const TIP_MAP = {
  Recyclable:
    'Empty liquids and rinse before recycling to improve recovery quality.',
  Compost: 'Remove plastic packaging when possible before compost disposal.',
  'General Waste':
    'Dispose non-recyclable, non-compostable residue as general waste.',
  'Hazardous Waste':
    'Do not mix with other waste. Use a dedicated hazardous-waste drop-off point.',
  Unrecognized: 'Move closer and ensure good lighting for better recognition.'
};

const fallbackResult = (
  message = 'AI recognition is currently unavailable. Please try again later.'
) => ({
  id: String(Date.now()),
  item: 'Recognition failed',
  category: 'Unrecognized',
  confidence: 0,
  timestamp: new Date().toISOString(),
  tips: [message],
  source: 'fallback'
});

const parseJsonSafely = (value) => {
  try {
    return JSON.parse(value);
  } catch {
    return null;
  }
};

const isEdgeFunctionMissingError = (error) => {
  const code = String(error?.code ?? '').toUpperCase();
  const message = String(error?.message ?? '');
  const status = Number(error?.status);
  return (
    code === 'NOT_FOUND' ||
    status === 404 ||
    message.includes('Requested function was not found')
  );
};

const normalizeCategory = (value) => {
  const raw = String(value ?? '').trim();
  if (!raw) return 'Unrecognized';
  const lower = raw.toLowerCase();
  return CATEGORY_MAP[lower] ?? raw;
};

const ensureTips = (category, payloadTips = []) => {
  const unique = new Set();
  const tips = [];
  payloadTips.forEach((tip) => {
    const normalized = String(tip ?? '').trim();
    if (!normalized || unique.has(normalized)) return;
    unique.add(normalized);
    tips.push(normalized);
  });
  if (tips.length) return tips;
  return [TIP_MAP[category] ?? TIP_MAP.Unrecognized];
};

const toBase64 = async (photo) => {
  const uri = toPhotoUri(photo);
  if (!uri) return null;
  return FileSystem.readAsStringAsync(uri, {
    encoding: FileSystem.EncodingType.Base64
  });
};

const toPhotoUri = (photo) => {
  if (!photo?.path && !photo?.uri) return null;
  const path = photo.path ?? photo.uri;
  if (typeof path !== 'string' || !path.length) return null;
  return path.startsWith('file://') ? path : `file://${path}`;
};

const parseEmbedding = (payload) => {
  const candidates = [
    payload?.embedding,
    payload?.image_embedding,
    payload?.imageEmbedding,
    payload?.features,
    payload?.vector
  ];
  for (const candidate of candidates) {
    if (Array.isArray(candidate) && candidate.length > 0) {
      return candidate.map((value) => Number(value)).filter(Number.isFinite);
    }
  }
  return null;
};

const dot = (a, b) => {
  let sum = 0;
  for (let idx = 0; idx < a.length; idx += 1) {
    sum += a[idx] * b[idx];
  }
  return sum;
};

const toLocalSketchEmbedding = (base64, targetDimension) => {
  if (!base64 || !targetDimension) return null;
  const sampleSize = Math.min(base64.length, LOCAL_SKETCH_SAMPLE_SIZE);
  if (!sampleSize) return null;
  const step = Math.max(1, Math.floor(base64.length / sampleSize));
  const projected = new Float32Array(targetDimension);

  let cursor = 0;
  for (let index = 0; index < sampleSize; index += 1) {
    const code = base64.charCodeAt(cursor);
    const mixed = ((index + 1) * 1103515245 + (code + 11) * 12345) >>> 0;
    const bucket = mixed % targetDimension;
    const sign = mixed & 1 ? 1 : -1;
    const magnitude = 0.2 + (code % 31) / 31;
    projected[bucket] += sign * magnitude;
    cursor = Math.min(base64.length - 1, cursor + step);
  }

  return projected;
};

const toNormalizedVector = (vector) => {
  if (
    (!Array.isArray(vector) && !ArrayBuffer.isView(vector)) ||
    vector.length === 0
  ) {
    return null;
  }
  const numeric = Array.from(vector, (value) => Number(value)).filter(
    Number.isFinite
  );
  if (!numeric.length) return null;
  let sumSquare = 0;
  for (let idx = 0; idx < numeric.length; idx += 1) {
    sumSquare += numeric[idx] * numeric[idx];
  }
  const norm = Math.sqrt(sumSquare);
  if (!Number.isFinite(norm) || norm < 1e-8) return null;
  const normalized = new Float32Array(numeric.length);
  for (let idx = 0; idx < numeric.length; idx += 1) {
    normalized[idx] = numeric[idx] / norm;
  }
  return normalized;
};

const alignAndNormalize = (vector, targetDimension) => {
  const normalized = toNormalizedVector(vector);
  if (!normalized) return null;
  if (!targetDimension || normalized.length === targetDimension)
    return normalized;
  if (normalized.length > targetDimension) {
    return normalized.slice(0, targetDimension);
  }
  const padded = new Float32Array(targetDimension);
  padded.set(normalized);
  return toNormalizedVector(Array.from(padded));
};

const yieldToEventLoop = () =>
  new Promise((resolve) => {
    setTimeout(resolve, 0);
  });

class ClassifierService {
  constructor() {
    this.ready = false;
    this.warmed = false;
    this.loading = false;
    this.knowledgeBase = [];
    this.dimension = 0;
    this.initializationError = null;
    this.edgeUnavailableReason = null;
    this.edgeDisabled = false;
    this.edgeMissingWarned = false;
    this.nativeEmbedWarned = false;
    this.nativeUnavailableReason = null;
    this.nativeEmbeddingAvailable =
      Platform.OS === 'ios' &&
      typeof mobileClipModule?.embedImage === 'function';
    this.mode = classifierMode;
    this._initPromise = null;
  }

  getStatus() {
    return {
      ready: this.ready,
      warmed: this.warmed,
      loading: this.loading,
      knowledgeCount: this.knowledgeBase.length,
      dimension: this.dimension,
      initializationError: this.initializationError,
      nativeEmbeddingAvailable: this.nativeEmbeddingAvailable,
      nativeUnavailableReason: this.nativeUnavailableReason,
      mode: this.mode
    };
  }

  async ensureReady() {
    if (this.ready) return this.getStatus();
    if (this._initPromise) return this._initPromise;

    this.loading = true;
    this._initPromise = this.initialize()
      .then(() => this.getStatus())
      .finally(() => {
        this.loading = false;
        this._initPromise = null;
      });
    return this._initPromise;
  }

  async initialize() {
    try {
      const parsed = knowledgeRows;
      if (!Array.isArray(parsed) || !parsed.length) {
        throw new Error('Knowledge base is empty');
      }

      const normalizedRows = [];
      for (let index = 0; index < parsed.length; index += 1) {
        const row = parsed[index];
        const normalizedEmbedding = toNormalizedVector(row?.embedding);
        if (!normalizedEmbedding) continue;
        normalizedRows.push({
          id: `${row?.label ?? 'item'}-${index}`,
          label: row?.label ?? 'Unknown Item',
          category: normalizeCategory(row?.category ?? 'Unrecognized'),
          embedding: normalizedEmbedding
        });
      }

      if (!normalizedRows.length) {
        throw new Error('Failed to normalize knowledge-base vectors');
      }

      this.dimension = normalizedRows[0].embedding.length;
      this.knowledgeBase = normalizedRows.filter(
        (item) => item.embedding.length === this.dimension
      );
      this.ready = true;
      this.initializationError = null;
    } catch (error) {
      this.ready = false;
      this.initializationError =
        error instanceof Error ? error.message : 'Initialization failed';
      console.warn('[classifier] initialize failed', error);
      throw error;
    }
  }

  async warmup() {
    await this.ensureReady();
    if (this.warmed) return;
    const sample = this.knowledgeBase[0]?.embedding;
    if (sample) {
      await this.findBestMatch(Array.from(sample));
    }
    this.warmed = true;
  }

  async classify(photo) {
    await this.warmup();

    const nativePayload = await this.classifyWithNativeEmbedding(photo);
    if (nativePayload) {
      return nativePayload;
    }

    if (allowSketchFallback) {
      const localPayload = await this.classifyWithLocalProjection(photo);
      if (localPayload) {
        return localPayload;
      }
    } else if (Platform.OS === 'ios' && !this.nativeEmbeddingAvailable) {
      this.nativeUnavailableReason =
        this.nativeUnavailableReason ??
        'Native MobileCLIP module is unavailable in this build. Rebuild iOS app with `pnpm --dir the-trash-rn expo run:ios`.';
    }

    const allowEdge =
      this.mode === 'hybrid' ||
      this.mode === 'edge-first' ||
      this.mode === 'local-first';
    if (!allowEdge) {
      return fallbackResult(
        this.nativeUnavailableReason ??
          this.initializationError ??
          'Local embedding projection failed. Verify camera capture permissions and photo access.'
      );
    }

    let remotePayload = null;
    try {
      remotePayload = await this.classifyWithEdge(photo);
    } catch (error) {
      if (isEdgeFunctionMissingError(error)) {
        this.edgeDisabled = true;
        this.edgeUnavailableReason =
          'Supabase Edge Function "classify" was not found. Deploy it or update EXPO_PUBLIC_SUPABASE_EDGE_FUNCTION_URL.';
        if (!this.edgeMissingWarned) {
          this.edgeMissingWarned = true;
          console.warn('[classifier] edge classify disabled', {
            code: error?.code,
            status: error?.status,
            message: error?.message,
            hint: this.edgeUnavailableReason
          });
        }
      } else {
        console.warn('[classifier] edge classify failed', error);
      }
    }

    if (remotePayload?.embedding?.length) {
      const localMatch = await this.findBestMatch(remotePayload.embedding);
      if (localMatch?.accepted) {
        return {
          id: remotePayload.id ?? localMatch.id,
          item: localMatch.item,
          category: localMatch.category,
          confidence: localMatch.confidence,
          timestamp: new Date().toISOString(),
          tips: ensureTips(localMatch.category, remotePayload.tips ?? []),
          source: 'local-cosine'
        };
      }
    }

    if (remotePayload) {
      const category = normalizeCategory(
        remotePayload.category ?? remotePayload.prediction
      );
      return {
        id: remotePayload.id ?? String(Date.now()),
        item: remotePayload.item ?? remotePayload.label ?? 'Unknown item',
        category,
        confidence: Number(remotePayload.confidence ?? 0.4),
        timestamp: remotePayload.timestamp ?? new Date().toISOString(),
        tips: ensureTips(category, remotePayload.tips ?? []),
        source: 'edge'
      };
    }

    return fallbackResult(
      this.edgeUnavailableReason ??
        this.initializationError ??
        'Edge classification is unavailable and no embedding was returned for local retrieval.'
    );
  }

  async classifyWithNativeEmbedding(photo) {
    if (!this.nativeEmbeddingAvailable || !photo) return null;
    const imageUri = toPhotoUri(photo);
    if (!imageUri) return null;

    try {
      const payload = await mobileClipModule.embedImage(imageUri);
      const embedding = parseEmbedding(payload);
      if (!embedding?.length) return null;
      const localMatch = await this.findBestMatch(embedding);
      if (!localMatch?.accepted) return null;
      this.nativeUnavailableReason = null;
      return {
        id: localMatch.id ?? String(Date.now()),
        item: localMatch.item,
        category: localMatch.category,
        confidence: localMatch.confidence,
        timestamp: new Date().toISOString(),
        tips: ensureTips(localMatch.category, []),
        source: 'local-mobileclip-image'
      };
    } catch (error) {
      this.nativeUnavailableReason =
        error?.message ?? 'Native MobileCLIP embedding failed';
      if (!this.nativeEmbedWarned) {
        this.nativeEmbedWarned = true;
        console.warn('[classifier] native mobileclip embed failed', error);
      }
      return null;
    }
  }

  async classifyWithLocalProjection(photo) {
    if (!photo || !this.dimension) return null;
    const imageBase64 = await toBase64(photo);
    if (!imageBase64) return null;
    const embedding = toLocalSketchEmbedding(imageBase64, this.dimension);
    if (!embedding) return null;
    const localMatch = await this.findBestMatch(embedding);
    if (!localMatch?.accepted) return null;

    return {
      id: localMatch.id ?? String(Date.now()),
      item: localMatch.item,
      category: localMatch.category,
      confidence: localMatch.confidence,
      timestamp: new Date().toISOString(),
      tips: ensureTips(localMatch.category, []),
      source: 'local-byte-projection'
    };
  }

  async classifyWithEdge(photo) {
    if (this.edgeDisabled || !edgeFunctionUrl || !supabaseAnonKey || !photo) {
      return null;
    }
    const imageBase64 = await toBase64(photo);
    if (!imageBase64) {
      throw new Error('Failed to read photo');
    }
    const response = await fetch(edgeFunctionUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${supabaseAnonKey}`
      },
      body: JSON.stringify({
        image: imageBase64,
        mimeType: photo?.mime ?? 'image/jpeg',
        includeEmbedding: true,
        returnEmbedding: true,
        mode: 'embedding'
      })
    });
    if (!response.ok) {
      const message = await response.text();
      const parsed = parseJsonSafely(message);
      const error = new Error(
        parsed?.message ?? message ?? 'Edge Function request failed'
      );
      error.code = parsed?.code;
      error.status = response.status;
      throw error;
    }
    const payload = await response.json();
    this.edgeDisabled = false;
    this.edgeUnavailableReason = null;
    const embedding = parseEmbedding(payload);
    return {
      ...payload,
      embedding
    };
  }

  async findBestMatch(imageEmbedding) {
    if (!this.ready || !this.knowledgeBase.length) return null;
    const normalizedImage = alignAndNormalize(imageEmbedding, this.dimension);
    if (!normalizedImage) return null;

    let bestScore = -Infinity;
    let bestMatch = null;

    for (let idx = 0; idx < this.knowledgeBase.length; idx += 1) {
      const row = this.knowledgeBase[idx];
      const score = dot(normalizedImage, row.embedding);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = row;
      }
      if ((idx + 1) % SEARCH_CHUNK_SIZE === 0) {
        await yieldToEventLoop();
      }
    }

    if (!bestMatch || !Number.isFinite(bestScore)) return null;
    return {
      id: bestMatch.id,
      item: bestMatch.label,
      category: bestMatch.category,
      confidence: Math.max(0, bestScore),
      accepted: bestScore >= CONFIDENCE_THRESHOLD
    };
  }
}

export const classifierService = new ClassifierService();
