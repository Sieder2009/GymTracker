import { WEEKDAYS, freshEx } from './data.js';

// A line is treated as a SET/WEIGHT line if it starts with a digit
// (e.g. "135kg x5 2.1 1.1 ...", "72,5kg x1 5.4", "1x 20.19.15.10").
// Anything else starting a new paragraph is treated as an EXERCISE NAME line,
// optionally carrying a "NxM" or "NxM-M" scheme (sets x reps), e.g.
// "Deadlift 2x3 nt muskelversagen" or "Klimmzüge 2x6-10".
const SET_LINE = /^\d/;
const DAY_HEADER = /^(\d+)\s*\.\s*Wochentag/i;
const DIVIDER_LINE = /^[=\-_*]{3,}$/;
const SCHEME = /(\d+)\s*x\s*([\d]+(?:\s*-\s*[\d]+)?)/i;
const WEIGHT = /^(\d+(?:[.,]\d+)?)\s*kg/i;
const PR_HEADER = /^1?\s*PR\s*\(([^)]*)\)/i;
const DATE_IN_TEXT = /(\d{1,2})\.(\d{1,2})\.(\d{2,4})/;
const PR_LINE = /^([^\d]+?)\s+(\d+(?:[.,]\d+)?)\s*kg/i;

function parseWeight(line) {
  const m = line.match(WEIGHT);
  if (!m) return 0;
  return parseFloat(m[1].replace(',', '.'));
}

function cleanName(line) {
  return line
    .replace(SCHEME, '')
    .replace(/[-–]\s*$/, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

// Splits a leading "(...)" style aside from an exercise name line into a
// separate note (machine setting like "(Stufe 14)" or an execution cue like
// "(Rücken und Beine gerade)") so it can be shown on its own instead of
// disappearing into the name.
function splitNameNote(line) {
  const parenMatch = line.match(/\(([^)]*)\)/);
  const note = parenMatch ? parenMatch[1].trim() : '';
  const withoutParen = line.replace(/\([^)]*\)/, '');
  return { name: cleanName(withoutParen), note };
}

const X_MARKER = /^\d*x\d*$/i;

// Reads the per-set reps trailing a weight line, e.g. "135 kg x5  2.1  1.1  3.2"
// -> [2,1,1,1,3,2] (each "N.M" token is 2+ sets: first number = set 1, second = set 2, …).
// Letters (x/m, per the log's own legend: x = weniger Gewicht, m = mehr Gewicht) are kept as-is.
// A token made only of dots (e.g. "....." for an exercise with no rep count, like
// bodyweight holds) means "done, no reps logged" — recorded as '✓' per set.
function parseHistoryReps(line) {
  const tokens = line.trim().split(/\s+/);
  const xIdx = tokens.findIndex((t) => X_MARKER.test(t));
  if (xIdx === -1) return [];
  const reps = [];
  for (const tok of tokens.slice(xIdx + 1)) {
    if (tok === '—' || tok === '-') continue;
    if (/^\.+$/.test(tok)) {
      const segments = tok.split('.').length;
      for (let i = 0; i < segments; i++) reps.push('✓');
      continue;
    }
    for (const part of tok.split('.')) {
      if (!part) continue;
      reps.push(/^\d+$/.test(part) ? parseInt(part, 10) : part.toLowerCase());
    }
  }
  return reps;
}

// Collects lines into exercise entries (name line -> following weight lines),
// shared between day-scoped and "every training day" exercises.
function makeAccumulator(list, warnings, contextLabel) {
  let current = null;
  function flush() {
    if (current) {
      // A name line with no weight line at all before the next one (e.g. two
      // exercise-name lines in a row, or a decorative "====" divider that
      // slipped through) leaves nothing to show — skip it instead of adding
      // an empty card with no real history.
      const isEmpty = current.weight === 0 && !current.sawKg && !current.history.length;
      if (!isEmpty) {
        if (current.weight === 0 && current.sawKg) {
          warnings.push(`"${current.name}" (${contextLabel}): kein Gewicht erkannt, wird als Körpergewicht geführt.`);
        }
        list.push({
          name: current.name || 'Unbenannte Übung',
          note: current.note,
          sets: current.sets,
          reps: current.reps,
          weight: current.weight,
          history: current.history,
        });
      }
    }
    current = null;
  }
  function line(raw) {
    if (SET_LINE.test(raw)) {
      if (!current) {
        current = { name: null, note: '', sets: 2, reps: '8', weight: 0, sawKg: false, history: [] };
      }
      const w = parseWeight(raw);
      if (/kg/i.test(raw)) current.sawKg = true;
      // take the most recently logged weight, not the heaviest — a later
      // bodyweight-only line (no "kg", w=0) shouldn't erase a known weight
      if (w > 0) current.weight = w;
      const reps = parseHistoryReps(raw);
      if (reps.length) current.history.push({ weight: w, reps });
    } else {
      flush();
      const schemeMatch = raw.match(SCHEME);
      const sets = schemeMatch ? Math.max(1, parseInt(schemeMatch[1], 10)) : 2;
      const reps = schemeMatch ? schemeMatch[2].replace(/\s+/g, '') : '8';
      const { name, note } = splitNameNote(raw);
      current = { name, note, sets, reps, weight: 0, sawKg: false, history: [] };
    }
  }
  return { line, flush };
}

/**
 * @param {string} text raw pasted/uploaded log
 * @returns {{
 *   days: {num:number, exercises:object[]}[],
 *   dailyExercises: object[],
 *   pr: { bench?: number, deadlift?: number, squat?: number, date?: string },
 *   warnings: string[],
 * }}
 */
export function parseLog(text) {
  const lines = text.split(/\r?\n/).map(l => l.trim());
  const days = [];
  const warnings = [];
  const pr = {};
  const dailyExercises = [];

  let mode = 'preamble'; // 'preamble' | 'pr' | 'day'
  let dayAcc = null;
  const preambleAcc = makeAccumulator(dailyExercises, warnings, 'jeden Trainingstag');

  for (const raw of lines) {
    if (!raw) {
      if (mode === 'pr') mode = 'preamble';
      continue;
    }
    if (DIVIDER_LINE.test(raw)) continue; // "====" / "----" section dividers, not an exercise

    const dayMatch = raw.match(DAY_HEADER);
    if (dayMatch) {
      if (dayAcc) dayAcc.flush();
      preambleAcc.flush();
      const currentDay = { num: parseInt(dayMatch[1], 10), exercises: [] };
      days.push(currentDay);
      dayAcc = makeAccumulator(currentDay.exercises, warnings, `Tag ${currentDay.num}`);
      mode = 'day';
      continue;
    }

    if (mode !== 'day') {
      const prMatch = raw.match(PR_HEADER);
      if (prMatch) {
        mode = 'pr';
        const dm = prMatch[1].match(DATE_IN_TEXT);
        if (dm) {
          const year = dm[3].length === 2 ? '20' + dm[3] : dm[3];
          pr.date = `${year}-${dm[2].padStart(2, '0')}-${dm[1].padStart(2, '0')}`;
        }
        continue;
      }
    }

    if (mode === 'pr') {
      const m = raw.match(PR_LINE);
      if (m) {
        const name = m[1].trim().toLowerCase();
        const weight = parseFloat(m[2].replace(',', '.'));
        if (/bench|bankdrücken/.test(name)) pr.bench = weight;
        else if (/deadlift/.test(name)) pr.deadlift = weight;
        else if (/squat/.test(name)) pr.squat = weight;
      }
      continue;
    }

    if (mode === 'preamble') {
      preambleAcc.line(raw);
      continue;
    }

    dayAcc.line(raw);
  }
  if (dayAcc) dayAcc.flush();
  preambleAcc.flush();

  if (!days.length) {
    warnings.push('Es wurden keine Tage im Format "1. Wochentag" gefunden — es konnte nichts importiert werden.');
  }

  return { days, dailyExercises, pr, warnings };
}

/**
 * Reads raw weight/set lines for a SINGLE exercise (no day or name header —
 * the name is already known from the UI). Used by the "Verlauf einfügen"
 * paste-in on an existing exercise.
 * @returns {{ weight: number, history: {weight:number, reps:(number|string)[]}[] }}
 */
export function parseExerciseBlock(text) {
  const lines = text.split(/\r?\n/).map(l => l.trim()).filter(Boolean);
  let weight = 0;
  const history = [];
  for (const raw of lines) {
    if (DIVIDER_LINE.test(raw) || !SET_LINE.test(raw)) continue;
    const w = parseWeight(raw);
    if (w > 0) weight = w;
    const reps = parseHistoryReps(raw);
    if (reps.length) history.push({ weight: w, reps });
  }
  return { weight, history };
}

/**
 * Maps the parsed { num, exercises } days onto a 7-day weekday plan
 * (Tag 1 = Montag ... Tag 6 = Samstag, Tag 7 = Sonntag). Any weekday
 * without a matching parsed day becomes a rest day.
 */
export function toWeekdayPlan(parsedDays) {
  return WEEKDAYS.map((label, i) => {
    const found = parsedDays.find(d => d.num === i + 1);
    if (!found || !found.exercises.length) {
      return { label, rest: true, exercises: [] };
    }
    return {
      label,
      rest: false,
      exercises: found.exercises.map(ex =>
        freshEx(ex.name, '', 90, Array.from({ length: ex.sets }, () => ({ w: ex.weight, r: ex.reps })), ex.history, ex.note)
      ),
    };
  });
}

// Maps parsed "every training day" exercises onto freshEx objects.
export function toDailyExercises(list) {
  return list.map(ex =>
    freshEx(ex.name, '', 90, Array.from({ length: ex.sets }, () => ({ w: ex.weight, r: ex.reps })), ex.history, ex.note)
  );
}
