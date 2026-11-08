import { debounce } from './debounce';
import rules from './rules/chatgpt.json';
import { joinLines } from './text';

/** Finds the prompt input box by role and attributes, never by generated class names. */
export function findInput(root: ParentNode = document): HTMLElement | null {
  return root.querySelector<HTMLElement>(rules.input.selector);
}

/** Reads the prompt text from the editor. The caller must never log or store it. */
export function getText(input: HTMLElement): string {
  const lines = Array.from(
    input.querySelectorAll(rules.input.textLineSelector),
    (line) => line.textContent ?? '',
  );
  return joinLines(lines);
}

/** Finds the send button in the same form as the input. It is absent while the box is empty. */
export function findSendButton(input: HTMLElement): HTMLButtonElement | null {
  const container = input.closest(rules.sendButton.container);
  return container?.querySelector<HTMLButtonElement>(rules.sendButton.selector) ?? null;
}

const CHANGE_DEBOUNCE_MS = 150;

/**
 * Calls callback with the prompt text whenever it changes. Re-finds the input on every check,
 * so it survives ChatGPT replacing the editor when the user switches conversations.
 * The caller must never log or store the text. Returns a function that stops watching.
 */
export function onTextChange(callback: (text: string) => void): () => void {
  let lastText: string | null = null;

  const check = debounce(() => {
    const input = findInput();
    const text = input ? getText(input) : null;
    if (text === lastText) return;
    lastText = text;
    if (text !== null) callback(text);
  }, CHANGE_DEBOUNCE_MS);

  const observer = new MutationObserver(check);
  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
  });
  check();

  return () => observer.disconnect();
}

/**
 * Calls callback with true or false whenever the input appears or disappears.
 * Returns a function that stops watching.
 */
export function onInputPresence(callback: (found: boolean) => void): () => void {
  let last: boolean | null = null;

  const check = debounce(() => {
    const found = findInput() !== null;
    if (found === last) return;
    last = found;
    callback(found);
  }, CHANGE_DEBOUNCE_MS);

  const observer = new MutationObserver(check);
  observer.observe(document.body, { childList: true, subtree: true });
  check();

  return () => observer.disconnect();
}
