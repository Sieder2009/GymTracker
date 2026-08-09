export const WEEKDAYS = ['Montag', 'Dienstag', 'Mittwoch', 'Donnerstag', 'Freitag', 'Samstag', 'Sonntag'];
export const WEEKDAYS_SHORT = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

export function freshEx(name, muscle, rest, sets, history = [], note = '') {
  const clonedSets = sets.map((s) => ({ ...s }));
  const startW = clonedSets.reduce((m, s) => Math.max(m, s.w), 0);
  return { name, muscle, rest, sets: clonedSets, startW, history: history.map((h) => ({ ...h })), note };
}

// A fresh install has no programs yet — the user creates one, imports
// their own log, or loads the bundled example plan (see exampleLog.js).
export function defaultPrograms() {
  return [];
}

export function todayIndexForProgram(p) {
  if (p.mode === 'weekday') {
    const js = new Date().getDay();
    return (js + 6) % 7; // Mo=0 .. So=6
  }
  return p.currentDayIdx || 0;
}

export function daysSince(dateStr) {
  const start = new Date(dateStr + 'T00:00:00');
  const now = new Date();
  return Math.max(0, Math.round((now - start) / 86400000));
}

export const fmt = (n) => n.toLocaleString('de-DE');
export const fmt1 = (n) => n.toLocaleString('de-DE', { minimumFractionDigits: 1, maximumFractionDigits: 1 });
