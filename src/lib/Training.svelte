<script>
  import { onMount } from 'svelte';
  import { programs, trainState } from './stores.js';
  import { todayIndexForProgram, fmt1, WEEKDAYS_SHORT } from './data.js';
  import { EXAMPLE_LOG } from './exampleLog.js';
  import PlanEditor from './PlanEditor.svelte';
  import ImportLog from './ImportLog.svelte';
  import ExerciseDetail from './ExerciseDetail.svelte';
  import ThemeToggle from './ThemeToggle.svelte';

  let showAllPlans = false;
  let planPromptOpen = false;
  let peOpen = false;
  let ilOpen = false;
  let ilInitialText = '';
  let ilInitialName = 'Importierter Plan';
  let edOpen = false;
  let edStartIdx = 0;
  let edSource = 'day'; // 'day' | 'daily'

  // one-time cleanup: older imports (before the "====" divider parsing fix)
  // could have left a decorative, fully empty exercise entry behind
  function isEmptyDivider(ex) {
    return /^[=\-_*.\s]*$/.test(ex.name || '')
      && ex.sets.every(s => s.w === 0)
      && !(ex.history && ex.history.length);
  }
  onMount(() => {
    programs.update(all => all.map(p => ({
      ...p,
      days: p.days.map(d => ({ ...d, exercises: d.exercises.filter(ex => !isEmptyDivider(ex)) })),
      dailyExercises: (p.dailyExercises || []).filter(ex => !isEmptyDivider(ex)),
    })));
    if ($programs.length > 1) planPromptOpen = true;
  });

  $: plan = $programs.find(p => p.id === $trainState.activePlanId) || $programs[0];
  $: todayIdx = plan ? todayIndexForProgram(plan) : 0;
  $: dayIdx = plan ? (plan.mode === 'weekday' ? $trainState.viewedDayIdx : (plan.currentDayIdx || 0)) : 0;
  $: day = plan ? plan.days[dayIdx] : null;
  $: exercises = day && !day.rest ? day.exercises : [];
  $: dailyExercises = plan && day && !day.rest ? (plan.dailyExercises || []) : [];
  $: edExercises = edSource === 'daily' ? dailyExercises : exercises;

  function selectPlan(id) {
    const p = $programs.find(p => p.id === id);
    trainState.set({ activePlanId: id, viewedDayIdx: todayIndexForProgram(p) });
    showAllPlans = false;
    planPromptOpen = false;
  }
  function selectPlanKey(id, e) {
    if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectPlan(id); }
  }

  function selectDay(i) {
    trainState.update(s => ({ ...s, viewedDayIdx: i }));
  }

  function openNewPlan() { showAllPlans = false; peOpen = true; }
  function openImport() { showAllPlans = false; ilInitialText = ''; ilInitialName = 'Importierter Plan'; ilOpen = true; }
  function openExample() { showAllPlans = false; ilInitialText = EXAMPLE_LOG; ilInitialName = 'Beispielplan (6er-Split)'; ilOpen = true; }

  function exerciseListOf(p, source) {
    return source === 'daily' ? (p.dailyExercises || (p.dailyExercises = [])) : p.days[dayIdx].exercises;
  }

  function latestWeight(ex) {
    return ex.sets[ex.sets.length - 1]?.w ?? ex.startW ?? 0;
  }

  function openExerciseDetail(source, exIdx) { edSource = source; edStartIdx = exIdx; edOpen = true; }

  function saveExerciseLog(exIdx, weight, reps) {
    programs.update(all => {
      const p = all.find(p => p.id === $trainState.activePlanId);
      const ex = exerciseListOf(p, edSource)[exIdx];
      ex.history = [...(ex.history || []), { weight, reps }];
      ex.sets = ex.sets.map(s => ({ ...s, w: weight }));
      return all;
    });
  }

  function renameExercise(exIdx, newName) {
    programs.update(all => {
      const p = all.find(p => p.id === $trainState.activePlanId);
      exerciseListOf(p, edSource)[exIdx].name = newName;
      return all;
    });
  }

  function importExerciseHistory(exIdx, weight, history) {
    programs.update(all => {
      const p = all.find(p => p.id === $trainState.activePlanId);
      const ex = exerciseListOf(p, edSource)[exIdx];
      ex.history = [...(ex.history || []), ...history];
      if (weight > 0) {
        ex.sets = ex.sets.map(s => ({ ...s, w: weight }));
      }
      return all;
    });
  }
</script>

<div class="apphead">
  <div>
    <h1>{plan ? plan.name : 'Training'}</h1>
    <div class="sub">
      {#if plan}{day.rest ? 'Ruhetag' : day.label}{/if}
    </div>
  </div>
  <div style="display:flex;align-items:center;gap:8px">
    <ThemeToggle />
    <button class="allbtn" on:click={() => (showAllPlans = true)}>Alle Pläne</button>
  </div>
</div>

{#if plan && plan.mode === 'weekday'}
  <div class="dayrow">
    {#each WEEKDAYS_SHORT as d, i}
      <button class="daypill" class:today={i === todayIdx} class:sel={i === dayIdx} on:click={() => selectDay(i)}>{d}</button>
    {/each}
  </div>
{/if}

{#if !plan}
  <div class="card" style="text-align:center;padding:32px 20px">
    <p class="plain-rest" style="margin-bottom:16px">Noch kein Trainingsplan angelegt.</p>
    <button class="cta" on:click={openNewPlan}>+ Neuer Plan</button>
    <button class="cta ghost" style="margin-top:10px" on:click={openImport}>📄 Log importieren</button>
    <button class="cta ghost" style="margin-top:10px" on:click={openExample}>⭐ Beispielplan laden</button>
  </div>
{:else if day.rest}
  <p class="plain-rest">Heute ist Ruhetag.<br>Kein Training eingetragen.</p>
{:else}
  {#if exercises.length}
    <div class="section-title">Heutiger Tag</div>
  {/if}
  {#each exercises as ex, exIdx}
    <div class="plain-ex">
      <div
        class="plain-ex-name"
        role="button"
        tabindex="0"
        on:click={() => openExerciseDetail('day', exIdx)}
        on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openExerciseDetail('day', exIdx); } }}
      >{ex.name}</div>
      <div class="plain-ex-weight">{latestWeight(ex) > 0 ? fmt1(latestWeight(ex)) + ' kg' : 'BW'}</div>
      {#if ex.note}<span class="ex-note">{ex.note}</span>{/if}
    </div>
  {/each}

  {#if dailyExercises.length}
    <div class="section-title">Jeden Trainingstag</div>
    {#each dailyExercises as ex, exIdx}
      <div class="plain-ex">
        <div
          class="plain-ex-name"
          role="button"
          tabindex="0"
          on:click={() => openExerciseDetail('daily', exIdx)}
          on:keydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); openExerciseDetail('daily', exIdx); } }}
        >{ex.name}</div>
        <div class="plain-ex-weight">{latestWeight(ex) > 0 ? fmt1(latestWeight(ex)) + ' kg' : 'BW'}</div>
        {#if ex.note}<span class="ex-note">{ex.note}</span>{/if}
      </div>
    {/each}
  {/if}
{/if}

{#if planPromptOpen}
  <div class="overlay open">
    <div class="ov-top">
      <span style="width:40px"></span>
      <div style="font-family:'Sora';font-weight:700;font-size:15px">Trainingsplan wählen</div>
      <button class="iconbtn" on:click={() => (planPromptOpen = false)}>✕</button>
    </div>
    <div class="pe-scroll">
      <p class="radar-hint" style="text-align:left;margin-bottom:12px">Welchen Trainingsplan möchtest du heute nutzen?</p>
      {#each $programs as p}
        <div
          class="plan-row-item"
          class:sel={p.id === $trainState.activePlanId}
          role="button"
          tabindex="0"
          on:click={() => selectPlan(p.id)}
          on:keydown={(e) => selectPlanKey(p.id, e)}
        >
          <span>{p.name}</span>
          {#if p.id === $trainState.activePlanId}<span>✓</span>{/if}
        </div>
      {/each}
    </div>
  </div>
{/if}

{#if showAllPlans}
  <div class="overlay open">
    <div class="ov-top">
      <button class="iconbtn" on:click={() => (showAllPlans = false)}>✕</button>
      <div style="font-family:'Sora';font-weight:700;font-size:15px">Alle Trainingspläne</div>
      <span style="width:40px"></span>
    </div>
    <div class="pe-scroll">
      {#each $programs as p}
        <div
          class="plan-row-item"
          class:sel={p.id === $trainState.activePlanId}
          role="button"
          tabindex="0"
          on:click={() => selectPlan(p.id)}
          on:keydown={(e) => selectPlanKey(p.id, e)}
        >
          <span>{p.name}</span>
          {#if p.id === $trainState.activePlanId}<span>✓</span>{/if}
        </div>
      {/each}
      <button class="cta ghost" style="margin-top:14px" on:click={openNewPlan}>+ Neuer Plan</button>
      <button class="cta ghost" style="margin-top:10px" on:click={openImport}>📄 Log importieren</button>
      <button class="cta ghost" style="margin-top:10px" on:click={openExample}>⭐ Beispielplan laden</button>
    </div>
  </div>
{/if}

{#if edOpen && plan}
  <ExerciseDetail
    exercises={edExercises}
    startIdx={edStartIdx}
    onSave={saveExerciseLog}
    onRename={renameExercise}
    onImportHistory={importExerciseHistory}
    on:close={() => (edOpen = false)}
  />
{/if}

<PlanEditor bind:open={peOpen} />
<ImportLog bind:open={ilOpen} initialText={ilInitialText} initialName={ilInitialName} />
