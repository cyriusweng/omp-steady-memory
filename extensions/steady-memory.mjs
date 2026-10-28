// steady-memory: re-assert the voice rules as a hidden message right before
// each generation, the SillyTavern post_history_instructions idea. The reminder
// text is static, so provider prefix caches stay valid. Edit the reminder in
// steady-memory.txt; this file only injects it. Main sessions only —
// subagents report to the agent, and their voice is not the user-facing one.
import { readFileSync, existsSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const TAIL_FILE = join(homedir(), '.omp/agent/extensions/steady-memory.txt');
const FALLBACK =
  '[steady-memory] Plainest words. One point per sentence. Sound like a person talking: curious, warm, direct, have a view. '
  + 'Lead with the outcome. Long flowing paragraphs; headings only when structure is needed. '
  + 'No filler openers, no hedging, no AI lexicon, no negation-contrast framing. '
  + 'In Chinese: spoken tone, 「」 quotes, full-width punctuation, one space around English and numbers. '
  + 'Name files, paths and numbers exactly. Stop when the point is made.';

function tailText() {
  try {
    if (existsSync(TAIL_FILE)) {
      const text = readFileSync(TAIL_FILE, 'utf8').trim();
      if (text) return text;
    }
  } catch {
    // fall through to the built-in text
  }
  return FALLBACK;
}

export default function steadyMemory(pi) {
  if (pi.setLabel) pi.setLabel('steady-memory');
  pi.on('before_agent_start', (event, ctx) => {
    const agent = ctx && ctx.agent;
    if (agent && agent.kind === 'sub') return;
    if (pi.logger) pi.logger.info('steady-memory: injecting style reminder before generation');
    return {
      message: {
        customType: 'steady-memory',
        content: tailText(),
        display: false,
        attribution: 'agent',
      },
    };
  });
}
