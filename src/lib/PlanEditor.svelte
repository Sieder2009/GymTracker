<script>
  import { programs, trainState } from './stores.js';
  import { WEEKDAYS, freshEx, todayIndexForProgram } from './data.js';
  import { toast } from './toast.js';
  import Icon from './Icon.svelte';

  export let open = false;

  function blankDraft() {
    return {
      name: '',
      mode: 'weekday',
      days: WEEKDAYS.map(l => ({ label: l, rest: true, exercises: [] })),
    };
  }
  let draft = blankDraft();

  $: if (open) draft = blankDraft();

  function setMode(mode) {
    draft.mode = mode;
    draft.days = mode === 'weekday'
      ? WEEKDAYS.map(l => ({ label: l, rest: true, exercises: [] }))
      : [{ label: 'Tag 1', exercises: [] }, { label: 'Tag 2', exercises: [] }, { label: 'Tag 3', exercises: [] }];
  }
  function addDay() {
    draft.days = [...draft.days, { label: 'Tag ' + (draft.days.length + 1), exercises: [] }];
  }
  function removeDay(i) {
    draft.days = draft.days.filter((_, idx) => idx !== i);
  }
  function addExercise(dayIdx) {
    draft.days[dayIdx].exercises = [...draft.days[dayIdx].exercises, { name: '', sets: 3, reps: '8', weight: 20 }];
  }
  function removeExercise(dayIdx, exIdx) {
    draft.days[dayIdx].exercises = draft.days[dayIdx].exercises.filter((_, i) => i !== exIdx);
  }

  function close() {
    open = false;
  }

  function save() {
    const name = draft.name.trim();
    if (!name) { toast('Bitte einen Namen vergeben'); return; }
    const days = draft.days.map(d => ({
      label: d.label,
      rest: draft.mode === 'weekday' ? !!d.rest : false,
      exercises: (d.rest && draft.mode === 'weekday') ? [] : d.exercises
        .filter(ex => ex.name.trim())
        .map(ex => {
          const w = ex.weight || 0, r = ex.reps || '—', n = Math.max(1, +ex.sets || 1);
          return freshEx(ex.name.trim(), '', 90, Array.from({ length: n }, () => ({ w, r })));
        }),
    }));
    const id = 'plan_' + Date.now();
    const newPlan = { id, name, mode: draft.mode, completed: 0, currentDayIdx: 0, startDate: new Date().toISOString().slice(0, 10), days, dailyExercises: [] };
    programs.update(all => [...all, newPlan]);
    trainState.set({ activePlanId: id, viewedDayIdx: todayIndexForProgram(newPlan) });
    open = false;
    toast('Trainingsplan gespeichert');
  }
</script>

{#if open}
<div class="overlay open">
  <div class="ov-top">
    <button class="iconbtn" on:click={close}><Icon name="close" /></button>
    <div style="font-family:'Sora';font-weight:700;font-size:15px">Neuer Trainingsplan</div>
    <button class="iconbtn" on:click={save}><Icon name="check" /></button>
  </div>
  <div class="pe-scroll">
    <div class="card">
      <div class="eyebrow">Name des Plans</div>
      <input class="pe-input" placeholder="z. B. Push Pull Legs" bind:value={draft.name}>

      <div class="eyebrow" style="margin-top:16px">Struktur</div>
      <div class="segmented">
        <button class="seg-btn" class:sel={draft.mode === 'weekday'} on:click={() => setMode('weekday')}>Nach Wochentag</button>
        <button class="seg-btn" class:sel={draft.mode === 'rotation'} on:click={() => setMode('rotation')}>Rotierende Routine</button>
      </div>
    </div>

    {#each draft.days as d, di}
      <div class="card pe-day">
        <div class="pe-daytop">
          {#if draft.mode === 'weekday'}
            <div style="flex:1;font-weight:700;font-size:14px">{d.label}</div>
            <label class="pe-resttoggle"><input type="checkbox" bind:checked={d.rest}> Ruhetag</label>
          {:else}
            <input class="pe-input small" style="margin-top:0" bind:value={d.label}>
            <button class="pe-remove" on:click={() => removeDay(di)}><Icon name="close" size={14} /></button>
          {/if}
        </div>
        {#if !(draft.mode === 'weekday' && d.rest)}
          <div class="pe-exlist">
            {#each d.exercises as ex, ei}
              <div class="pe-exrow">
                <input class="pe-input small nm" placeholder="Übung" bind:value={ex.name}>
                <input class="pe-input small" type="number" placeholder="Sätze" bind:value={ex.sets}>
                <input class="pe-input small" placeholder="Wdh." bind:value={ex.reps}>
                <input class="pe-input small" type="number" placeholder="kg" bind:value={ex.weight}>
                <button class="pe-remove" on:click={() => removeExercise(di, ei)}><Icon name="close" size={14} /></button>
              </div>
            {:else}
              <div class="pe-empty">Noch keine Übung</div>
            {/each}
            <button class="cta ghost pe-addex" on:click={() => addExercise(di)}>+ Übung hinzufügen</button>
          </div>
        {/if}
      </div>
    {/each}

    {#if draft.mode === 'rotation'}
      <button class="cta ghost pe-addex" on:click={addDay}>+ Tag / Routine hinzufügen</button>
    {/if}
  </div>
</div>
{/if}
