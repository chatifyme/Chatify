export type DetectorType = 'OIB' | 'IBAN' | 'KEY' | 'EMAIL';

export type Confidence = 'high' | 'medium' | 'low';

export interface Finding {
  type: DetectorType;
  start: number;
  end: number;
  confidence: Confidence;
}
