/** Joins editor paragraphs into plain prompt text, one paragraph per line. */
export function joinLines(lines: string[]): string {
  return lines.map((line) => line.replace(/\u00a0/g, ' ')).join('\n');
}
