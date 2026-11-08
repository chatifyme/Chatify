import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createFallbackWatchdog } from './fallback';

describe('createFallbackWatchdog', () => {
  beforeEach(() => {
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  function setup() {
    const onMissing = vi.fn();
    const onFound = vi.fn();
    const watchdog = createFallbackWatchdog({ timeoutMs: 3000, onMissing, onFound });
    return { watchdog, onMissing, onFound };
  }

  it('does not report missing before the timeout', () => {
    const { watchdog, onMissing } = setup();
    watchdog.check(false);
    vi.advanceTimersByTime(2999);
    expect(onMissing).not.toHaveBeenCalled();
  });

  it('reports missing once the input stays missing for the timeout', () => {
    const { watchdog, onMissing } = setup();
    watchdog.check(false);
    vi.advanceTimersByTime(3000);
    expect(onMissing).toHaveBeenCalledTimes(1);
  });

  it('does not restart the timer on repeated misses', () => {
    const { watchdog, onMissing } = setup();
    watchdog.check(false);
    vi.advanceTimersByTime(2000);
    watchdog.check(false);
    vi.advanceTimersByTime(1000);
    expect(onMissing).toHaveBeenCalledTimes(1);
  });

  it('stays quiet when the input is found in time', () => {
    const { watchdog, onMissing, onFound } = setup();
    watchdog.check(false);
    vi.advanceTimersByTime(1000);
    watchdog.check(true);
    vi.advanceTimersByTime(5000);
    expect(onMissing).not.toHaveBeenCalled();
    expect(onFound).not.toHaveBeenCalled();
  });

  it('reports found when the input returns after the fallback was shown', () => {
    const { watchdog, onMissing, onFound } = setup();
    watchdog.check(false);
    vi.advanceTimersByTime(3000);
    watchdog.check(true);
    expect(onMissing).toHaveBeenCalledTimes(1);
    expect(onFound).toHaveBeenCalledTimes(1);
  });
});
