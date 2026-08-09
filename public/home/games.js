(function () {
  const container = document.getElementById('game-container');

  document.querySelectorAll('.game-card[data-game]').forEach((card) => {
    card.addEventListener('click', () => loadGame(card.dataset.game));
  });

  function loadGame(game) {
    const template = document.getElementById(`${game}-template`);
    container.innerHTML = '';
    container.appendChild(template.content.cloneNode(true));

    if (game === 'tictactoe') initTTT();
    if (game === 'connectfour') initCF();
    if (game === 'blackjack') initBJ();
  }

  // --- 3 Gewinnt ---
  let tttBoard, currentPlayer, tttActive;

  function initTTT() {
    tttBoard = Array(9).fill('');
    currentPlayer = 'X';
    tttActive = true;

    document.querySelectorAll('.ttt-grid .cell').forEach((cell) => {
      cell.addEventListener('click', handleTTTClick);
    });
    document.getElementById('ttt-reset').addEventListener('click', initTTT);
    document.querySelectorAll('.ttt-grid .cell').forEach((cell) => (cell.textContent = ''));
    document.getElementById('ttt-player').textContent = 'Aktueller Spieler: X';
    document.getElementById('ttt-status').textContent = 'Status: läuft';
  }

  function handleTTTClick(e) {
    const cell = e.currentTarget;
    const index = parseInt(cell.dataset.index, 10);
    if (tttBoard[index] !== '' || !tttActive) return;

    tttBoard[index] = currentPlayer;
    cell.textContent = currentPlayer;
    checkTTTResult();

    if (tttActive) {
      currentPlayer = currentPlayer === 'X' ? 'O' : 'X';
      document.getElementById('ttt-player').textContent = `Aktueller Spieler: ${currentPlayer}`;
    }
  }

  const tttWinLines = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  function checkTTTResult() {
    const won = tttWinLines.some(([a, b, c]) => tttBoard[a] && tttBoard[a] === tttBoard[b] && tttBoard[b] === tttBoard[c]);

    if (won) {
      document.getElementById('ttt-status').textContent = `Status: ${currentPlayer} gewinnt!`;
      tttActive = false;
      return;
    }
    if (!tttBoard.includes('')) {
      document.getElementById('ttt-status').textContent = 'Status: unentschieden!';
      tttActive = false;
    }
  }

  // --- 4 Gewinnt ---
  const ROWS = 6;
  const COLS = 7;
  let cfBoard, currentCFPlayer, cfActive;

  function initCF() {
    cfBoard = Array.from({ length: ROWS }, () => Array(COLS).fill(''));
    currentCFPlayer = 'red';
    cfActive = true;

    const grid = document.querySelector('.cf-grid');
    grid.innerHTML = '';
    for (let col = 0; col < COLS; col++) {
      const column = document.createElement('div');
      column.className = 'cf-column';
      column.dataset.col = col;
      for (let row = ROWS - 1; row >= 0; row--) {
        const cell = document.createElement('div');
        cell.className = 'cf-cell';
        cell.dataset.row = row;
        column.appendChild(cell);
      }
      column.addEventListener('click', handleCFClick);
      grid.appendChild(column);
    }

    document.getElementById('cf-reset').addEventListener('click', initCF);
    document.getElementById('cf-player').textContent = 'Aktueller Spieler: Rot';
    document.getElementById('cf-status').textContent = 'Status: läuft';
  }

  function handleCFClick(e) {
    if (!cfActive) return;
    const col = parseInt(e.currentTarget.dataset.col, 10);
    const row = getEmptyRow(col);
    if (row === -1) return;

    cfBoard[row][col] = currentCFPlayer;
    const cells = document.querySelectorAll(`.cf-column[data-col="${col}"] .cf-cell`);
    cells[ROWS - 1 - row].classList.add(currentCFPlayer);

    if (checkCFWin(row, col)) {
      document.getElementById('cf-status').textContent = `Status: ${currentCFPlayer === 'red' ? 'Rot' : 'Gelb'} gewinnt!`;
      cfActive = false;
      return;
    }
    if (cfBoard.every((r) => r.every((c) => c !== ''))) {
      document.getElementById('cf-status').textContent = 'Status: unentschieden!';
      cfActive = false;
      return;
    }

    currentCFPlayer = currentCFPlayer === 'red' ? 'yellow' : 'red';
    document.getElementById('cf-player').textContent = `Aktueller Spieler: ${currentCFPlayer === 'red' ? 'Rot' : 'Gelb'}`;
  }

  function getEmptyRow(col) {
    for (let row = 0; row < ROWS; row++) {
      if (cfBoard[row][col] === '') return row;
    }
    return -1;
  }

  function checkCFWin(row, col) {
    const directions = [[0, 1], [1, 0], [1, 1], [1, -1]];
    return directions.some(([dx, dy]) => {
      const count = 1 + countCFDirection(row, col, dx, dy) + countCFDirection(row, col, -dx, -dy);
      return count >= 4;
    });
  }

  function countCFDirection(row, col, dx, dy) {
    const player = cfBoard[row][col];
    let count = 0;
    let r = row + dx;
    let c = col + dy;
    while (r >= 0 && r < ROWS && c >= 0 && c < COLS && cfBoard[r][c] === player) {
      count++;
      r += dx;
      c += dy;
    }
    return count;
  }

  // --- Blackjack ---
  const suits = ['♠', '♥', '♦', '♣'];
  const values = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  let bjDeck, bjDealerHand, bjPlayerHand, bjGameOver, bjCredits;

  function initBJ() {
    bjCredits = 100;
    document.getElementById('hit-btn').addEventListener('click', bjHit);
    document.getElementById('stand-btn').addEventListener('click', bjStand);
    document.getElementById('newgame-btn').addEventListener('click', startNewBJGame);
    startNewBJGame();
  }

  function createDeck() {
    bjDeck = [];
    for (const suit of suits) {
      for (const value of values) bjDeck.push({ suit, value });
    }
    for (let i = bjDeck.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [bjDeck[i], bjDeck[j]] = [bjDeck[j], bjDeck[i]];
    }
  }

  function dealCard(hand) {
    if (bjDeck.length === 0) createDeck();
    hand.push(bjDeck.pop());
  }

  function calculateScore(hand) {
    let score = 0;
    let aces = 0;
    for (const card of hand) {
      if (card.value === 'A') {
        aces++;
        score += 11;
      } else if (['K', 'Q', 'J'].includes(card.value)) {
        score += 10;
      } else {
        score += parseInt(card.value, 10);
      }
    }
    while (score > 21 && aces > 0) {
      score -= 10;
      aces--;
    }
    return score;
  }

  function updateBJUI() {
    const dealerHandEl = document.getElementById('dealer-hand');
    dealerHandEl.innerHTML = '';
    bjDealerHand.forEach((card, index) => {
      const el = document.createElement('span');
      el.className = 'bj-card';
      el.textContent = index === 0 && !bjGameOver ? '??' : `${card.suit}${card.value}`;
      dealerHandEl.appendChild(el);
    });

    const playerHandEl = document.getElementById('player-hand');
    playerHandEl.innerHTML = '';
    bjPlayerHand.forEach((card) => {
      const el = document.createElement('span');
      el.className = 'bj-card';
      el.textContent = `${card.suit}${card.value}`;
      playerHandEl.appendChild(el);
    });

    document.getElementById('dealer-score').textContent = bjGameOver ? `Punkte: ${calculateScore(bjDealerHand)}` : '';
    document.getElementById('player-score').textContent = `Punkte: ${calculateScore(bjPlayerHand)}`;
    document.getElementById('bj-status').textContent = `Credits: ${bjCredits}`;
    document.getElementById('bj-score').textContent = 'Einsatz: 10';
    document.getElementById('hit-btn').disabled = bjGameOver;
    document.getElementById('stand-btn').disabled = bjGameOver;
  }

  function startNewBJGame() {
    const messageEl = document.getElementById('bj-message');
    if (bjCredits < 10) {
      messageEl.textContent = 'Nicht genug Credits für eine neue Runde.';
      return;
    }

    bjCredits -= 10;
    bjGameOver = false;
    bjDealerHand = [];
    bjPlayerHand = [];
    messageEl.textContent = '';
    createDeck();

    dealCard(bjDealerHand);
    dealCard(bjPlayerHand);
    dealCard(bjDealerHand);
    dealCard(bjPlayerHand);

    updateBJUI();

    if (calculateScore(bjPlayerHand) === 21) bjStand();
  }

  function bjHit() {
    if (bjGameOver) return;
    dealCard(bjPlayerHand);
    updateBJUI();
    if (calculateScore(bjPlayerHand) > 21) endBJGame('Spieler busted! Dealer gewinnt.');
  }

  function bjStand() {
    if (bjGameOver) return;
    bjGameOver = true;
    while (calculateScore(bjDealerHand) < 17) dealCard(bjDealerHand);

    const dealerScore = calculateScore(bjDealerHand);
    const playerScore = calculateScore(bjPlayerHand);

    if (dealerScore > 21) endBJGame('Dealer busted! Spieler gewinnt.', 20);
    else if (dealerScore > playerScore) endBJGame('Dealer gewinnt!');
    else if (playerScore > dealerScore) endBJGame('Spieler gewinnt!', 20);
    else endBJGame('Unentschieden!', 10);
  }

  function endBJGame(message, winAmount = 0) {
    bjGameOver = true;
    bjCredits += winAmount;
    updateBJUI();
    document.getElementById('bj-message').textContent = message;
  }
})();
