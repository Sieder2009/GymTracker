<script>
  import { bigLifts } from './stores.js';
  import { fmt1 } from './data.js';
  import { toast } from './toast.js';
  import ThemeToggle from './ThemeToggle.svelte';

  const LIFTS = [
    { key: 'bench', label: 'Bench Press', color: 'var(--teal)' },
    { key: 'deadlift', label: 'Deadlift', color: 'var(--purple)' },
    { key: 'squat', label: 'Squat', color: 'var(--yellow)' },
  ];

  let prInputs = { bench: '', deadlift: '', squat: '' };
  let entryInputs = { bench: '', deadlift: '', squat: '' };

  function fmtDate(iso) {
    if (!iso) return '';
    const [y, m, d] = iso.split('-');
    return `${d}.${m}.${y}`;
  }

  $: for (const l of LIFTS) {
    if (prInputs[l.key] === '') prInputs[l.key] = $bigLifts[l.key].pr || '';
  }

  function savePR(key) {
    const v = +prInputs[key];
    if (!v) return;
    bigLifts.update((all) => ({ ...all, [key]: { ...all[key], pr: v } }));
    toast('PR gespeichert');
  }

  function addEntry(key) {
    const v = +entryInputs[key];
    if (!v) return;
    const today = new Date();
    const label = `${today.getDate()}.${today.getMonth() + 1}`;
    bigLifts.update((all) => ({
      ...all,
      [key]: { ...all[key], history: [...all[key].history, { l: label, v }] },
    }));
    entryInputs[key] = '';
    toast('Eingetragen');
  }
</script>

<div class="apphead">
  <div><h1>Kraft</h1><div class="sub">Fortschritt seit letztem PR</div></div>
  <ThemeToggle />
</div>

{#each LIFTS as lift}
  {@const data = $bigLifts[lift.key]}
  {@const points = data.history.slice(-8)}
  {@const vals = points.map((p) => p.v)}
  {@const chartMin = (vals.length ? Math.min(data.pr || vals[0], ...vals) : (data.pr || 0)) - 2}
  {@const chartMax = (vals.length ? Math.max(data.pr || 0, ...vals) : (data.pr || 10)) + 2}
  {@const prY = 100 - ((data.pr - chartMin) / (chartMax - chartMin)) * 100}
  {@const path = points.map((p, i) => {
    const x = points.length > 1 ? (i / (points.length - 1)) * 100 : 50;
    const y = 100 - ((p.v - chartMin) / (chartMax - chartMin)) * 100;
    return `${x},${y}`;
  }).join(' ')}
  <div class="card">
    <div class="row">
      <h2>{lift.label}</h2>
      <div style="display:flex;align-items:center;gap:6px">
        <span class="muted" style="font-size:11px">PR</span>
        <input class="pe-input small" type="number" min="0" bind:value={prInputs[lift.key]} on:change={() => savePR(lift.key)} style="width:56px">
        <span class="muted" style="font-size:11px">kg</span>
      </div>
    </div>

    {#if points.length}
      <svg class="chart" viewBox="0 0 100 100" preserveAspectRatio="none" style="margin-top:10px">
        {#if data.pr > 0}
          <line x1="0" y1={prY} x2="100" y2={prY} stroke={lift.color} stroke-width="0.6" stroke-dasharray="2,2" />
        {/if}
        <polyline points={path} fill="none" stroke="var(--accent)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" />
        {#each points as p, i}
          {@const x = points.length > 1 ? (i / (points.length - 1)) * 100 : 50}
          {@const y = 100 - ((p.v - chartMin) / (chartMax - chartMin)) * 100}
          <circle cx={x} cy={y} r="1.6" fill="var(--accent)" />
        {/each}
      </svg>
      <div class="legend">
        <span><i style="background:var(--accent)"></i>Eintrag</span>
        {#if data.pr > 0}<span><i style={`background:${lift.color}`}></i>PR {fmt1(data.pr)} kg{data.prDate ? ' · ' + fmtDate(data.prDate) : ''}</span>{/if}
      </div>
    {:else}
      <p class="radar-hint" style="text-align:left;margin-top:10px">Noch keine Einträge — trag deinen aktuellen Wert unten ein.</p>
      {#if data.pr > 0}
        <div class="legend"><span><i style={`background:${lift.color}`}></i>PR {fmt1(data.pr)} kg{data.prDate ? ' · ' + fmtDate(data.prDate) : ''}</span></div>
      {/if}
    {/if}

    <div style="display:flex;gap:8px;margin-top:12px">
      <input class="pe-input small" type="number" min="0" placeholder="kg heute" bind:value={entryInputs[lift.key]}>
      <button class="cta ghost" style="width:auto;padding:9px 16px;margin-top:0" on:click={() => addEntry(lift.key)}>+ Eintrag</button>
    </div>
  </div>
{/each}
