import { describe, expect, it } from 'vitest';
import { detectKeys } from './keys';

// All values are invented, except the public AWS documentation example.
const awsExample = 'AKIAIOSFODNN7EXAMPLE';
const githubFake = 'ghp_' + 'aB3dE'.repeat(7) + 'a';
const openAiFake = 'sk-' + 'Ab12'.repeat(8);

function covered(text: string): string[] {
  return detectKeys(text).map((f) => text.slice(f.start, f.end));
}

describe('detectKeys', () => {
  it('finds an AWS access key id', () => {
    expect(covered(`key=${awsExample}`)).toEqual([awsExample]);
  });

  it('finds a GitHub token', () => {
    expect(covered(`token ${githubFake} je tu`)).toEqual([githubFake]);
  });

  it('finds an OpenAI-style key', () => {
    expect(covered(`OPENAI_API_KEY=${openAiFake}`)).toEqual([openAiFake]);
  });

  it('does not flag ordinary text', () => {
    expect(detectKeys('Napiši mail klijentu o dogovoru od prošlog tjedna.')).toHaveLength(0);
    expect(detectKeys('risk-assessment-for-the-company-plan')).toHaveLength(0);
  });
});