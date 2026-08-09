<script>
  export let name;
  export let size = 17;
  export let strokeWidth = 2;

  const PATHS = {
    close: 'M18 6 6 18M6 6l12 12',
    check: 'M20 6 9 17l-5-5',
    pencil: 'M17 3a2.83 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5L17 3z',
    file: 'M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8l-6-6zM14 2v6h6M9 13h6M9 17h6',
    star: 'M12 2l3.09 6.26L22 9.27l-5 4.87L18.18 21 12 17.77 5.82 21 7 14.14 2 9.27l6.91-1.01L12 2z',
    pause: 'M8 5v14M16 5v14',
  };
</script>

<svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width={strokeWidth} stroke-linecap="round" stroke-linejoin="round">
  <path d={PATHS[name]} />
</svg>
