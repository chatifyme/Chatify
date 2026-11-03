import { describe, expect, it } from 'vitest';
import { joinLines } from './text';

describe('joinLines', () => {
  it('joins paragraphs with a newline', () => {
    expect(joinLines(['Test poruka', 'druga linija'])).toBe('Test poruka\ndruga linija');
  });

  it('returns an empty string for one empty paragraph', () => {
    expect(joinLines([''])).toBe('');
  });

  it('keeps a blank line between paragraphs', () => {
    expect(joinLines(['a', '', 'b'])).toBe('a\n\nb');
  });

  it('replaces non-breaking spaces with normal spaces', () => {
    expect(joinLines(['HR12\u00a01001\u00a00051'])).toBe('HR12 1001 0051');
  });
});
