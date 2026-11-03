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
