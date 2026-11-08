interface FallbackWatchdogOptions {
  timeoutMs: number;
  onMissing: () => void;
  onFound: () => void;
}

export interface FallbackWatchdog {
  /** Reports whether the input is present right now. Safe to call as often as needed. */
  check: (found: boolean) => void;
  stop: () => void;
}

/** Decides when the fallback box should be shown: input missing for timeoutMs in a row. */
export function createFallbackWatchdog({
  timeoutMs,
  onMissing,
  onFound,
}: FallbackWatchdogOptions): FallbackWatchdog {
  let timer: ReturnType<typeof setTimeout> | undefined;
  let shown = false;

  return {
    check(found) {
      if (found) {
        clearTimeout(timer);
        timer = undefined;
        if (shown) {
          shown = false;
          onFound();
        }
        return;
      }

      // Start the countdown only once; repeated misses must not restart it.
      if (timer !== undefined || shown) return;
      timer = setTimeout(() => {
        timer = undefined;
        shown = true;
        onMissing();
      }, timeoutMs);
    },

    stop() {
      clearTimeout(timer);
      timer = undefined;
    },
  };
}
