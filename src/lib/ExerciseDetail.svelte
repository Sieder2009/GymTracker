<script>
  import { onMount, onDestroy, createEventDispatcher } from 'svelte';
  import { fmt1 } from './data.js';
  import { parseExerciseBlock } from './logParser.js';
  import { toast } from './toast.js';
  import Icon from './Icon.svelte';

  export let exercises = [];
  export let startIdx = 0;
  export let onSave;
  export let onRename = null;
  export let onImportHistory = null;

  const dispatch = createEventDispatcher();
  const SWIPE_THRESHOLD = 55; // px

  let idx = startIdx;
  let weightInput = 0;
  let repsInputs = [];
  let renaming = false;
  let renameValue = '';
  let historyPasteOpen = false;
  let historyPasteText = '';

  let swiping = false;
  let swipeStartX = 0;
  let swipeStartY = 0;
  let swipeDx = 0;

  function loadExercise(i) {
    idx = i;
    const e = exercises[i];
    weightInput = e.sets[e.sets.length - 1]?.w ?? e.startW ?? 0;
    repsInputs = e.sets.map(() => '');
    renaming = false;
    historyPasteOpen = false;
    historyPasteText = '';
  }

  function goPrev() { if (idx > 0) loadExercise(idx - 1); }
  function goNext() { if (idx < exercises.length - 1) loadExercise(idx + 1); }

  function onKeydown(e) {
    if (e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') return;
    // don't hijack cursor movement while editing a text/number field
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;
    if (e.key === 'ArrowLeft') goPrev(); else goNext();
  }

  onMount(() => {
    loadExercise(startIdx);
    window.addEventListener('keydown', onKeydown);
  });
  onDestroy(() => window.removeEventListener('keydown', onKeydown));

  function isInteractive(target) {
    return target.closest?.('input, button, textarea, a');
  }
  function onSwipeStart(e) {
    if (isInteractive(e.target)) return;
    swiping = true;
    swipeStartX = e.clientX;
    swipeStartY = e.clientY;
    swipeDx = 0;
  }
  function onSwipeMove(e) {
    if (!swiping) return;
    swipeDx = e.clientX - swipeStartX;
  }
  function onSwipeEnd(e) {
    if (!swiping) return;
    swiping = false;
    const dy = e.clientY - swipeStartY;
    if (Math.abs(swipeDx) > SWIPE_THRESHOLD && Math.abs(swipeDx) > Math.abs(dy)) {
      if (swipeDx < 0) goNext(); else goPrev();
    }
    swipeDx = 0;
  }

  function startRename() { renameValue = ex.name; renaming = true; }
  function confirmRename() {
    const name = renameValue.trim();
    if (name && onRename) onRename(idx, name);
    renaming = false;
  }

  function applyHistoryPaste() {
    if (!historyPasteText.trim()) return;
    const { weight, history } = parseExerciseBlock(historyPasteText);
    if (!history.length) { toast('Keine Sätze im eingefügten Text erkannt'); return; }
    if (onImportHistory) onImportHistory(idx, weight, history);
    if (weight > 0) weightInput = weight;
    historyPasteText = '';
    historyPasteOpen = false;
    toast('Verlauf übernommen');
  }

  $: ex = exercises[idx];
  $: hasRepsEntered = repsInputs.some((r) => r !== '');

  function addSetRow() { repsInputs = [...repsInputs, '']; }
  function removeSetRow(i) { repsInputs = repsInputs.filter((_, j) => j !== i); }

  function save() {
    const reps = repsInputs.map((r) => (r === '' ? 0 : +r));
    onSave(idx, weightInput, reps);
    if (idx < exercises.length - 1) {
      loadExercise(idx + 1);
    } else {
      dispatch('close');
    }
  }

  function formatRep(r) {
    return typeof r === 'number' ? r : r.toUpperCase();
  }
</script>

{#if ex}
<div
  class="overlay open"
  on:pointerdown={onSwipeStart}
  on:pointermove={onSwipeMove}
  on:pointerup={onSwipeEnd}
  on:pointercancel={onSwipeEnd}
>
  <div class="ov-top">
    <button class="iconbtn" on:click={() => dispatch('close')}><Icon name="close" /></button>
    {#if renaming}
      <input class="pe-input small" style="max-width:200px" bind:value={renameValue} on:keydown={(e) => e.key === 'Enter' && confirmRename()}>
    {:else}
      <div style="font-family:'Sora';font-weight:700;font-size:15px">{ex.name}</div>
    {/if}
    {#if renaming}
      <button class="iconbtn" on:click={confirmRename}><Icon name="check" /></button>
    {:else}
      <button class="iconbtn" on:click={startRename}><Icon name="pencil" size={15} /></button>
    {/if}
  </div>
  {#if exercises.length > 1}
    <div class="muted" style="text-align:center;font-size:11.5px;margin-bottom:4px">Übung {idx + 1} / {exercises.length} · wischen oder ←/→ zum Wechseln</div>
  {/if}
  {#if ex.note}
    <p class="note-line">{ex.note}</p>
  {/if}

  <div class="pe-scroll">
    <div class="card" style="text-align:center">
      <div class="eyebrow">Gewicht heute</div>
      <div class="weight-row">
        <input class="weight-input" type="number" step="0.5" min="0" bind:value={weightInput}>
        <span class="weight-unit">kg</span>
      </div>

      <div class="eyebrow" style="text-align:left;margin-top:20px">Wiederholungen pro Satz</div>
      {#each repsInputs as r, i (i)}
        <div class="plain-set">
          <span class="plain-idx">{i + 1}</span>
          <input class="pe-input small" type="number" min="0" value={r} on:input={(e) => (repsInputs[i] = e.currentTarget.value)} placeholder="Wdh.">
          <button class="pe-remove" on:click={() => removeSetRow(i)}><Icon name="close" size={14} /></button>
        </div>
      {/each}
      <button class="cta ghost" style="margin-top:10px" on:click={addSetRow}>+ Satz</button>
    </div>

    <button class="cta" style="margin-top:14px" on:click={save}>
      Speichern{#if idx < exercises.length - 1} → nächste Übung{/if}
    </button>

    {#if ex.history?.length}
      <div class="eyebrow" style="margin:20px 4px 8px">Verlauf</div>
      {#each [...ex.history].reverse() as h, i}
        <div class="plain-ex hist-card" class:hist-latest={i === 0}>
          <div class="hist-w">
            {h.weight > 0 ? fmt1(h.weight) + ' kg' : 'BW'}
            {#if i === 0}<span class="hist-badge">Aktuell</span>{/if}
          </div>
          <div class="plain-setlist">
            {#each h.reps as r, j}
              <div class="plain-set">
                <span class="plain-idx">{j + 1}</span>
                <span class="plain-r" style="margin-left:0">× {formatRep(r)}</span>
              </div>
            {/each}
          </div>
        </div>
      {/each}
      <p class="radar-hint" style="text-align:left;margin-top:8px">X = weniger Gewicht verwendet · M = mehr Gewicht verwendet · ✓ = erledigt, ohne Wiederholungszahl</p>
    {/if}

    {#if onImportHistory && !hasRepsEntered}
      {#if !historyPasteOpen}
        <button class="cta ghost" style="margin-top:14px" on:click={() => (historyPasteOpen = true)}>+ Verlauf einfügen</button>
      {:else}
        <div class="card" style="margin-top:14px">
          <div class="eyebrow">Verlauf einfügen</div>
          <p class="radar-hint" style="text-align:left;margin-top:4px">Log-Text für diese Übung einfügen (z. B. "70kg x3 8.7.6 9.7.7") — wird genauso gelesen wie beim Log-Import.</p>
          <textarea class="pe-input import-textarea" rows="5" style="margin-top:8px" bind:value={historyPasteText}></textarea>
          <div style="display:flex;gap:8px;margin-top:8px">
            <button class="cta ghost" style="margin-top:0" on:click={() => { historyPasteOpen = false; historyPasteText = ''; }}>Abbrechen</button>
            <button class="cta" style="margin-top:0" on:click={applyHistoryPaste}>Übernehmen</button>
          </div>
        </div>
      {/if}
    {/if}
  </div>
</div>
{/if}
