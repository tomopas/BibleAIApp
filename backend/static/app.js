/* Bible AI Web Application — Client Logic */
(function () {
  'use strict';

  const CANONICAL_BOOKS = [
    { id: 'gen', name: 'Genesis', abbr: 'Gen', testament: 'OT', chapters: 50 },
    { id: 'exo', name: 'Exodus', abbr: 'Exo', testament: 'OT', chapters: 40 },
    { id: 'lev', name: 'Leviticus', abbr: 'Lev', testament: 'OT', chapters: 27 },
    { id: 'num', name: 'Numbers', abbr: 'Num', testament: 'OT', chapters: 36 },
    { id: 'deu', name: 'Deuteronomy', abbr: 'Deut', testament: 'OT', chapters: 34 },
    { id: 'jos', name: 'Joshua', abbr: 'Josh', testament: 'OT', chapters: 24 },
    { id: 'jdg', name: 'Judges', abbr: 'Judg', testament: 'OT', chapters: 21 },
    { id: 'rut', name: 'Ruth', abbr: 'Ruth', testament: 'OT', chapters: 4 },
    { id: '1sa', name: '1 Samuel', abbr: '1Sam', testament: 'OT', chapters: 31 },
    { id: '2sa', name: '2 Samuel', abbr: '2Sam', testament: 'OT', chapters: 24 },
    { id: '1ki', name: '1 Kings', abbr: '1Kgs', testament: 'OT', chapters: 22 },
    { id: '2ki', name: '2 Kings', abbr: '2Kgs', testament: 'OT', chapters: 25 },
    { id: '1ch', name: '1 Chronicles', abbr: '1Chr', testament: 'OT', chapters: 29 },
    { id: '2ch', name: '2 Chronicles', abbr: '2Chr', testament: 'OT', chapters: 36 },
    { id: 'ezr', name: 'Ezra', abbr: 'Ezra', testament: 'OT', chapters: 10 },
    { id: 'neh', name: 'Nehemiah', abbr: 'Neh', testament: 'OT', chapters: 13 },
    { id: 'est', name: 'Esther', abbr: 'Esth', testament: 'OT', chapters: 10 },
    { id: 'job', name: 'Job', abbr: 'Job', testament: 'OT', chapters: 42 },
    { id: 'psa', name: 'Psalms', abbr: 'Ps', testament: 'OT', chapters: 150 },
    { id: 'pro', name: 'Proverbs', abbr: 'Prov', testament: 'OT', chapters: 31 },
    { id: 'ecc', name: 'Ecclesiastes', abbr: 'Eccl', testament: 'OT', chapters: 12 },
    { id: 'sng', name: 'Song of Songs', abbr: 'Song', testament: 'OT', chapters: 8 },
    { id: 'isa', name: 'Isaiah', abbr: 'Isa', testament: 'OT', chapters: 66 },
    { id: 'jer', name: 'Jeremiah', abbr: 'Jer', testament: 'OT', chapters: 52 },
    { id: 'lam', name: 'Lamentations', abbr: 'Lam', testament: 'OT', chapters: 5 },
    { id: 'eze', name: 'Ezekiel', abbr: 'Ezek', testament: 'OT', chapters: 48 },
    { id: 'dan', name: 'Daniel', abbr: 'Dan', testament: 'OT', chapters: 12 },
    { id: 'hos', name: 'Hosea', abbr: 'Hos', testament: 'OT', chapters: 14 },
    { id: 'joe', name: 'Joel', abbr: 'Joel', testament: 'OT', chapters: 3 },
    { id: 'amo', name: 'Amos', abbr: 'Amos', testament: 'OT', chapters: 9 },
    { id: 'oba', name: 'Obadiah', abbr: 'Obad', testament: 'OT', chapters: 1 },
    { id: 'jon', name: 'Jonah', abbr: 'Jonah', testament: 'OT', chapters: 4 },
    { id: 'mic', name: 'Micah', abbr: 'Mic', testament: 'OT', chapters: 7 },
    { id: 'nah', name: 'Nahum', abbr: 'Nah', testament: 'OT', chapters: 3 },
    { id: 'hab', name: 'Habakkuk', abbr: 'Hab', testament: 'OT', chapters: 3 },
    { id: 'zep', name: 'Zephaniah', abbr: 'Zeph', testament: 'OT', chapters: 3 },
    { id: 'hag', name: 'Haggai', abbr: 'Hag', testament: 'OT', chapters: 2 },
    { id: 'zec', name: 'Zechariah', abbr: 'Zech', testament: 'OT', chapters: 14 },
    { id: 'mal', name: 'Malachi', abbr: 'Mal', testament: 'OT', chapters: 4 },
    { id: 'mat', name: 'Matthew', abbr: 'Matt', testament: 'NT', chapters: 28 },
    { id: 'mrk', name: 'Mark', abbr: 'Mark', testament: 'NT', chapters: 16 },
    { id: 'luk', name: 'Luke', abbr: 'Luke', testament: 'NT', chapters: 24 },
    { id: 'jhn', name: 'John', abbr: 'John', testament: 'NT', chapters: 21 },
    { id: 'act', name: 'Acts', abbr: 'Acts', testament: 'NT', chapters: 28 },
    { id: 'rom', name: 'Romans', abbr: 'Rom', testament: 'NT', chapters: 16 },
    { id: '1co', name: '1 Corinthians', abbr: '1Cor', testament: 'NT', chapters: 16 },
    { id: '2co', name: '2 Corinthians', abbr: '2Cor', testament: 'NT', chapters: 13 },
    { id: 'gal', name: 'Galatians', abbr: 'Gal', testament: 'NT', chapters: 6 },
    { id: 'eph', name: 'Ephesians', abbr: 'Eph', testament: 'NT', chapters: 6 },
    { id: 'php', name: 'Philippians', abbr: 'Phil', testament: 'NT', chapters: 4 },
    { id: 'col', name: 'Colossians', abbr: 'Col', testament: 'NT', chapters: 4 },
    { id: '1th', name: '1 Thessalonians', abbr: '1Thess', testament: 'NT', chapters: 5 },
    { id: '2th', name: '2 Thessalonians', abbr: '2Thess', testament: 'NT', chapters: 3 },
    { id: '1ti', name: '1 Timothy', abbr: '1Tim', testament: 'NT', chapters: 6 },
    { id: '2ti', name: '2 Timothy', abbr: '2Tim', testament: 'NT', chapters: 4 },
    { id: 'tit', name: 'Titus', abbr: 'Titus', testament: 'NT', chapters: 3 },
    { id: 'phm', name: 'Philemon', abbr: 'Phlm', testament: 'NT', chapters: 1 },
    { id: 'heb', name: 'Hebrews', abbr: 'Heb', testament: 'NT', chapters: 13 },
    { id: 'jas', name: 'James', abbr: 'Jas', testament: 'NT', chapters: 5 },
    { id: '1pe', name: '1 Peter', abbr: '1Pet', testament: 'NT', chapters: 5 },
    { id: '2pe', name: '2 Peter', abbr: '2Pet', testament: 'NT', chapters: 3 },
    { id: '1jn', name: '1 John', abbr: '1John', testament: 'NT', chapters: 5 },
    { id: '2jn', name: '2 John', abbr: '2John', testament: 'NT', chapters: 1 },
    { id: '3jn', name: '3 John', abbr: '3John', testament: 'NT', chapters: 1 },
    { id: 'jud', name: 'Jude', abbr: 'Jude', testament: 'NT', chapters: 1 },
    { id: 'rev', name: 'Revelation', abbr: 'Rev', testament: 'NT', chapters: 22 }
  ];

  const BOOK_BY_ID = {};
  CANONICAL_BOOKS.forEach((b) => { BOOK_BY_ID[b.id] = b; });

  const DEFAULT_PERSPECTIVES = [
    { id: 'protestant', label: 'Protestant / Reformed', short: 'Scripture, grace & covenant', color: '#3E6B5A', description: 'Reads through Reformation emphases such as grace alone, faith alone, covenant and the clarity of Scripture.' },
    { id: 'catholic', label: 'Catholic', short: 'Sacramental & magisterial', color: '#9A4A3A', description: 'Reads with the Catholic canon, the sacraments, the Church Fathers and the teaching office of the Church.' },
    { id: 'orthodox', label: 'Orthodox', short: 'Theosis & liturgy', color: '#7A5C99', description: 'Reads within the Eastern Orthodox liturgical and patristic tradition, with attention to deification and mystery.' },
    { id: 'historical_critical', label: 'Historical-critical', short: 'Context, sources & history', color: '#4B6178', description: 'Asks about the historical setting, literary sources, redaction and the world behind the text.' },
    { id: 'evangelical', label: 'Evangelical', short: 'Conversion & mission', color: '#B5651D', description: 'Highlights personal conversion, the authority of Scripture, evangelism and a living relationship with Christ.' },
    { id: 'jewish', label: 'Jewish', short: 'Tanakh & Jewish reading', color: '#2F6690', description: 'Reads the text within Jewish scripture, interpretation and covenantal practice.' }
  ];

  const DAILY_VERSES = [
    { book: 'jhn', chapter: 1, verse: 1, ref: 'John 1:1', text: 'In the beginning was the Word, and the Word was with God, and the Word was God.' },
    { book: 'psa', chapter: 23, verse: 1, ref: 'Psalm 23:1', text: 'The LORD is my shepherd; I shall not want.' },
    { book: 'rom', chapter: 8, verse: 28, ref: 'Romans 8:28', text: 'And we know that all things work together for good to them that love God, to them who are the called according to his purpose.' },
    { book: 'pro', chapter: 3, verse: 5, ref: 'Proverbs 3:5', text: 'Trust in the LORD with all thine heart; and lean not unto thine own understanding.' },
    { book: 'isa', chapter: 40, verse: 31, ref: 'Isaiah 40:31', text: 'But they that wait upon the LORD shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.' },
    { book: 'mat', chapter: 11, verse: 28, ref: 'Matthew 11:28', text: 'Come unto me, all ye that labour and are heavy laden, and I will give you rest.' },
    { book: 'php', chapter: 4, verse: 13, ref: 'Philippians 4:13', text: 'I can do all things through Christ which strengtheneth me.' }
  ];

  const HF_AUDIO_CDN = 'https://huggingface.co/datasets/Tomopas/bibleai-audio/resolve/main';

  // Build Reading Plans matching Flutter's PlanService
  function splitPlanChapters(booksList, totalDays) {
    const allRefs = [];
    booksList.forEach((b) => {
      for (let c = 1; c <= b.chapters; c++) {
        allRefs.push({ book: b.id, bookName: b.name, chapter: c });
      }
    });
    const days = [];
    for (let d = 1; d <= totalDays; d++) {
      const start = Math.floor(((d - 1) * allRefs.length) / totalDays);
      const end = Math.floor((d * allRefs.length) / totalDays);
      const slice = allRefs.slice(start, Math.max(start + 1, end));
      days.push({ day: d, readings: slice });
    }
    return days;
  }

  const READING_PLANS = [
    {
      id: 'bible-year',
      name: 'Bible in a Year',
      description: 'Every chapter of the Bible in 365 days (3–4 chapters a day).',
      length: 365,
      days: splitPlanChapters(CANONICAL_BOOKS, 365)
    },
    {
      id: 'nt-90',
      name: 'New Testament in 90 Days',
      description: 'Read through the entire New Testament in three months.',
      length: 90,
      days: splitPlanChapters(CANONICAL_BOOKS.filter((b) => b.testament === 'NT'), 90)
    },
    {
      id: 'gospels-60',
      name: 'Four Gospels in 60 Days',
      description: 'Walk through Matthew, Mark, Luke, and John in two months.',
      length: 60,
      days: splitPlanChapters(['mat', 'mrk', 'luk', 'jhn'].map((id) => BOOK_BY_ID[id]), 60)
    },
    {
      id: 'psalms-30',
      name: 'Psalms in 30 Days',
      description: 'Five psalms a day for a month of worship and prayer.',
      length: 30,
      days: splitPlanChapters([BOOK_BY_ID['psa']], 30)
    },
    {
      id: 'proverbs-31',
      name: 'Proverbs in 31 Days',
      description: 'One chapter of wisdom for each day of the month.',
      length: 31,
      days: splitPlanChapters([BOOK_BY_ID['pro']], 31)
    }
  ];

  // Application State
  const STORAGE_KEY = 'bibleai_web_state_v1';
  const defaultUserId = 'web-' + Math.random().toString(36).substring(2, 10) + '-' + Date.now().toString(36);

  const state = {
    tab: 'home',
    translationId: 'en-kjv',
    bookId: 'jhn',
    chapter: 1,
    selectedVerse: null,
    theme: 'parchment',
    fontFamily: 'serif',
    fontSize: 19,
    lineHeight: 1.75,
    showVerseNumbers: true,
    defaultPerspective: 'protestant',
    activePerspectiveFilter: 'all',
    aiPanelOpen: true,
    narrationSource: 'auto',
    audioSpeed: 1.0,
    audioAutoNext: false,
    userId: defaultUserId,
    activePlanId: 'gospels-60',
    bookmarks: [],
    highlights: {}, // key: `${translationId}:${bookId}:${chapter}:${verse}` -> color
    notes: [],
    planProgress: {}, // planId -> array of completed day numbers
    history: [],
    catalog: [{ id: 'en-kjv', name: 'King James Version', abbreviation: 'KJV' }],
    perspectives: DEFAULT_PERSPECTIVES,
    currentVerses: [],
    currentInterpretations: [],
    modalBookId: 'jhn',
    modalTestament: 'all'
  };

  function loadState() {
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (!raw) return;
      const saved = JSON.parse(raw);
      Object.assign(state, saved);
    } catch (err) {
      console.warn('Could not load saved state:', err);
    }
  }

  function saveState() {
    try {
      const toSave = {
        translationId: state.translationId,
        bookId: state.bookId,
        chapter: state.chapter,
        theme: state.theme,
        fontFamily: state.fontFamily,
        fontSize: state.fontSize,
        lineHeight: state.lineHeight,
        showVerseNumbers: state.showVerseNumbers,
        defaultPerspective: state.defaultPerspective,
        aiPanelOpen: state.aiPanelOpen,
        narrationSource: state.narrationSource,
        audioSpeed: state.audioSpeed,
        audioAutoNext: state.audioAutoNext,
        userId: state.userId,
        activePlanId: state.activePlanId,
        bookmarks: state.bookmarks,
        highlights: state.highlights,
        notes: state.notes,
        planProgress: state.planProgress,
        history: state.history
      };
      localStorage.setItem(STORAGE_KEY, JSON.stringify(toSave));
    } catch (err) {
      console.warn('Could not save state:', err);
    }
  }

  // Toast helper
  let toastTimer = null;
  function showToast(msg) {
    const el = document.getElementById('toastNotification');
    if (!el) return;
    el.textContent = msg;
    el.classList.remove('hidden');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => el.classList.add('hidden'), 2600);
  }

  // Apply visual preferences
  function applyThemeAndTypography() {
    document.documentElement.setAttribute('data-theme', state.theme);
    document.documentElement.style.setProperty(
      '--reader-font',
      state.fontFamily === 'sans'
        ? "'Inter', -apple-system, BlinkMacSystemFont, sans-serif"
        : "'Lora', Georgia, 'Times New Roman', serif"
    );
    document.documentElement.style.setProperty('--reader-size', state.fontSize + 'px');
    document.documentElement.style.setProperty('--reader-lh', String(state.lineHeight));

    const paper = document.getElementById('versesContainer');
    if (paper) {
      paper.classList.toggle('hide-verse-nums', !state.showVerseNumbers);
    }

    document.querySelectorAll('.theme-option-btn').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.setTheme === state.theme);
    });

    const ffSelect = document.getElementById('fontFamilySelect');
    if (ffSelect) ffSelect.value = state.fontFamily;
    const fsRange = document.getElementById('fontSizeRange');
    if (fsRange) fsRange.value = state.fontSize;
    const fsVal = document.getElementById('fontSizeVal');
    if (fsVal) fsVal.textContent = state.fontSize + 'px';
    const lhRange = document.getElementById('lineHeightRange');
    if (lhRange) lhRange.value = state.lineHeight;
    const lhVal = document.getElementById('lineHeightVal');
    if (lhVal) lhVal.textContent = state.lineHeight;
    const vnToggle = document.getElementById('showVerseNumsToggle');
    if (vnToggle) vnToggle.checked = state.showVerseNumbers;
    const nsSelect = document.getElementById('narrationSourceSelect');
    if (nsSelect) nsSelect.value = state.narrationSource;
    const autoNextToggle = document.getElementById('audioAutoNextToggle');
    if (autoNextToggle) autoNextToggle.checked = state.audioAutoNext;
    const syncIdInput = document.getElementById('syncUserIdInput');
    if (syncIdInput) syncIdInput.value = state.userId;

    const splitLayout = document.getElementById('readerSplitLayout');
    if (splitLayout) {
      splitLayout.classList.toggle('ai-closed', !state.aiPanelOpen);
    }
  }

  // Navigation Tabs
  function setTab(tabName) {
    state.tab = tabName;
    document.querySelectorAll('.tab-view').forEach((sec) => {
      sec.classList.toggle('active', sec.id === 'view-' + tabName);
    });
    document.querySelectorAll('[data-tab]').forEach((btn) => {
      btn.classList.toggle('active', btn.dataset.tab === tabName);
    });
    if (tabName === 'home') renderDashboard();
    if (tabName === 'library') renderLibrary();
    if (tabName === 'settings') refreshServerDiagnostics();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }

  // Book & Chapter Navigation
  async function navigateToPassage(bookId, chapter, verse = null, switchTab = true) {
    const book = BOOK_BY_ID[bookId] || BOOK_BY_ID['jhn'];
    const ch = Math.max(1, Math.min(book.chapters, parseInt(chapter, 10) || 1));
    state.bookId = book.id;
    state.chapter = ch;
    state.selectedVerse = verse ? parseInt(verse, 10) : null;

    // Record reading history
    state.history = [
      {
        translationId: state.translationId,
        bookId: book.id,
        bookName: book.name,
        chapter: ch,
        verse: state.selectedVerse || 1,
        readAt: new Date().toISOString()
      },
      ...state.history.filter((h) => !(h.bookId === book.id && h.chapter === ch)).slice(0, 39)
    ];

    saveState();
    updateHeaderLabels();
    if (switchTab) setTab('read');
    await Promise.all([loadChapterScripture(), loadChapterInterpretations()]);

    if (state.selectedVerse) {
      setTimeout(() => {
        const vEl = document.querySelector(`.verse-item[data-verse="${state.selectedVerse}"]`);
        if (vEl) {
          vEl.scrollIntoView({ behavior: 'smooth', block: 'center' });
          selectVerse(state.selectedVerse);
        }
      }, 80);
    } else {
      closeVerseToolbar();
    }
  }

  function updateHeaderLabels() {
    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    const refText = `${book.name} ${state.chapter}`;
    const refLbl = document.getElementById('currentRefLabel');
    if (refLbl) refLbl.textContent = refText;
    const heroRef = document.getElementById('heroCurrentRef');
    if (heroRef) heroRef.textContent = refText;
    const readerTitle = document.getElementById('readerBookChapterTitle');
    if (readerTitle) readerTitle.textContent = refText;

    const transObj = state.catalog.find((t) => t.id === state.translationId);
    const transName = transObj ? `${transObj.name} (${transObj.abbreviation || transObj.id})` : state.translationId.toUpperCase();
    const heroTrans = document.getElementById('heroTranslationName');
    if (heroTrans) heroTrans.textContent = transName;
  }

  // Load Scripture Chapter from Backend API
  async function loadChapterScripture() {
    const container = document.getElementById('versesContainer');
    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    if (container) {
      container.innerHTML = `<div class="loading-spinner">Loading ${book.name} ${state.chapter}…</div>`;
    }

    try {
      const res = await fetch(`/api/chapter/${encodeURIComponent(state.translationId)}/${encodeURIComponent(state.bookId)}/${state.chapter}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();

      let verses = [];
      if (Array.isArray(data.verses)) {
        verses = data.verses;
      } else if (typeof data.text === 'string') {
        verses = data.text.split('\n').map((line, idx) => {
          const m = line.match(/^(\d+)\.\s*(.*)$/);
          return m ? { verse: parseInt(m[1], 10), text: m[2] } : { verse: idx + 1, text: line };
        });
      }
      state.currentVerses = verses;

      const metaEl = document.getElementById('readerChapterMeta');
      const transObj = state.catalog.find((t) => t.id === state.translationId);
      if (metaEl) {
        metaEl.textContent = `${verses.length} verses • ${transObj ? transObj.name : state.translationId}`;
      }

      renderVersesList();
    } catch (err) {
      if (container) {
        container.innerHTML = `<p class="muted-text">Could not load chapter text (${err.message}). Please check server connection.</p>`;
      }
    }
  }

  function highlightKey(bookId, chapter, verse) {
    return `${state.translationId}:${bookId}:${chapter}:${verse}`;
  }

  function renderVersesList() {
    const container = document.getElementById('versesContainer');
    if (!container) return;
    if (!state.currentVerses.length) {
      container.innerHTML = `<p class="muted-text">No verses found for this chapter.</p>`;
      return;
    }

    const html = state.currentVerses.map((v) => {
      const hlColor = state.highlights[highlightKey(state.bookId, state.chapter, v.verse)] || '';
      const isBookmarked = state.bookmarks.some(
        (b) => b.book_id === state.bookId && b.chapter === state.chapter && b.verse === v.verse
      );
      const hasNote = state.notes.some(
        (n) => n.book_id === state.bookId && n.chapter === state.chapter && n.verse === v.verse
      );
      const isSelected = state.selectedVerse === v.verse;

      let badgesHtml = '';
      if (isBookmarked || hasNote) {
        badgesHtml = `<span class="verse-badges">
          ${isBookmarked ? '<span class="v-badge" title="Bookmarked">🔖</span>' : ''}
          ${hasNote ? '<span class="v-badge" title="Study Note">📝</span>' : ''}
        </span>`;
      }

      return `<div class="verse-item${isSelected ? ' selected' : ''}" data-verse="${v.verse}" ${hlColor ? `data-hl="${hlColor}"` : ''}>
        <span class="verse-num">${v.verse}</span>
        <span class="verse-text">${escapeHtml(v.text)}</span>
        ${badgesHtml}
      </div>`;
    }).join('');

    container.innerHTML = html;

    container.querySelectorAll('.verse-item').forEach((el) => {
      el.addEventListener('click', () => {
        const vNum = parseInt(el.dataset.verse, 10);
        if (state.selectedVerse === vNum) {
          closeVerseToolbar();
        } else {
          selectVerse(vNum);
        }
      });
    });
  }

  function selectVerse(verseNum) {
    state.selectedVerse = verseNum;
    document.querySelectorAll('.verse-item').forEach((el) => {
      el.classList.toggle('selected', parseInt(el.dataset.verse, 10) === verseNum);
    });
    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    const toolbar = document.getElementById('verseActionToolbar');
    const lbl = document.getElementById('selectedVerseLabel');
    if (lbl) lbl.textContent = `${book.name} ${state.chapter}:${verseNum}`;
    if (toolbar) toolbar.classList.remove('hidden');

    const isBookmarked = state.bookmarks.some(
      (b) => b.book_id === state.bookId && b.chapter === state.chapter && b.verse === verseNum
    );
    const bmText = document.getElementById('vatBookmarkText');
    if (bmText) bmText.textContent = isBookmarked ? 'Bookmarked ★' : 'Bookmark';
  }

  function closeVerseToolbar() {
    state.selectedVerse = null;
    document.querySelectorAll('.verse-item.selected').forEach((el) => el.classList.remove('selected'));
    const toolbar = document.getElementById('verseActionToolbar');
    if (toolbar) toolbar.classList.add('hidden');
  }

  // Load AI Study Perspectives for Current Chapter
  async function loadChapterInterpretations() {
    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    const scopeLbl = document.getElementById('aiPanelScopeLabel');
    if (scopeLbl) scopeLbl.textContent = `${book.name} ${state.chapter} • Comparative Commentary`;

    try {
      const res = await fetch(`/api/interpretations?book=${encodeURIComponent(state.bookId)}&chapter=${state.chapter}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      state.currentInterpretations = Array.isArray(data.all)
        ? data.all
        : Array.isArray(data.chapterOverview)
          ? data.chapterOverview
          : Array.isArray(data.items)
            ? data.items
            : [];
    } catch (_) {
      state.currentInterpretations = [];
    }

    const badge = document.getElementById('aiCountBadge');
    if (badge) badge.textContent = String(state.currentInterpretations.length);

    renderAiPerspectivesPanel();
  }

  function renderAiPerspectivesPanel() {
    const tabsBar = document.getElementById('perspectiveTabsBar');
    const banner = document.getElementById('perspectiveDescBanner');
    const listEl = document.getElementById('aiNotesList');
    if (!tabsBar || !listEl) return;

    const availablePerspectives = state.perspectives;
    const allChip = `<button class="persp-tab-btn ${state.activePerspectiveFilter === 'all' ? 'active' : ''}" data-persp="all">All (${state.currentInterpretations.length})</button>`;
    const traditionChips = availablePerspectives.map((p) => {
      const hasNote = state.currentInterpretations.some((item) => item.perspective === p.id);
      return `<button class="persp-tab-btn ${state.activePerspectiveFilter === p.id ? 'active' : ''}" data-persp="${p.id}">
        <span class="persp-dot" style="background:${p.color || '#8C3B2E'}"></span>
        <span>${escapeHtml(p.label)}${hasNote ? ' •' : ''}</span>
      </button>`;
    }).join('');

    tabsBar.innerHTML = allChip + traditionChips;

    tabsBar.querySelectorAll('.persp-tab-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.activePerspectiveFilter = btn.dataset.persp;
        renderAiPerspectivesPanel();
      });
    });

    if (banner) {
      if (state.activePerspectiveFilter === 'all') {
        banner.textContent = 'Comparing theological traditions and scholarly readings for this chapter.';
      } else {
        const pInfo = availablePerspectives.find((p) => p.id === state.activePerspectiveFilter);
        banner.textContent = pInfo ? pInfo.description : '';
      }
    }

    const filtered = state.activePerspectiveFilter === 'all'
      ? state.currentInterpretations
      : state.currentInterpretations.filter((i) => i.perspective === state.activePerspectiveFilter);

    if (!filtered.length) {
      listEl.innerHTML = `<div class="ai-note-card">
        <p class="muted-text">No pre-generated study note found for this selection yet. Try selecting "All" perspectives or browsing Genesis, Psalms, or the Gospels.</p>
      </div>`;
      return;
    }

    listEl.innerHTML = filtered.map((item) => {
      const pMeta = availablePerspectives.find((p) => p.id === item.perspective);
      const color = pMeta ? pMeta.color : '#8C3B2E';
      const label = item.label || (pMeta ? pMeta.label : item.perspective);
      const verseSpan = item.verse_start && item.verse_end && item.verse_end < 900
        ? `v. ${item.verse_start}–${item.verse_end}`
        : 'Chapter Overview';
      return `<div class="ai-note-card">
        <div class="ai-note-top">
          <span class="ai-tradition-badge" style="color:${color}">
            <span class="persp-dot" style="background:${color}"></span>
            ${escapeHtml(label)}
          </span>
          <span class="ai-scope-tag">${escapeHtml(verseSpan)}</span>
        </div>
        <div class="ai-note-body">${escapeHtml(item.content)}</div>
        <div class="ai-note-meta">
          <span>Model: ${escapeHtml(item.model || 'Pre-generated')}</span>
          <span>${escapeHtml(item.scope || 'chapter')}</span>
        </div>
      </div>`;
    }).join('');
  }

  // Audio Narration Player (Kokoro-82M Server/CDN + Browser Speech Synthesis fallback)
  const audioEl = document.getElementById('htmlAudioElement');
  let ttsActive = false;

  async function startChapterAudio() {
    const dock = document.getElementById('audioPlayerDock');
    if (dock) dock.classList.remove('hidden');

    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    const titleEl = document.getElementById('audioNowPlayingTitle');
    const statusEl = document.getElementById('audioStatusText');
    const badgeEl = document.getElementById('audioSourceBadge');
    if (titleEl) titleEl.textContent = `${book.name} ${state.chapter}`;

    stopAllAudio();

    if (state.narrationSource === 'device') {
      startBrowserSpeech();
      return;
    }

    if (statusEl) statusEl.textContent = 'Connecting audio stream…';
    if (badgeEl) badgeEl.textContent = 'Kokoro-82M';

    let streamUrl = `${HF_AUDIO_CDN}/audio/en-kjv/${state.bookId}/${state.chapter}.mp3`;
    try {
      const audioTrans = state.translationId || 'en-kjv';
      const infoRes = await fetch(`/api/audio/info/${encodeURIComponent(audioTrans)}/${encodeURIComponent(state.bookId)}/${state.chapter}`);
      if (infoRes.ok) {
        const info = await infoRes.json();
        if (info.url && (info.available || info.url.startsWith('http'))) {
          streamUrl = info.url;
        }
      }
    } catch (_) {
      // Fallback to direct Hugging Face KJV CDN
    }

    audioEl.src = streamUrl;
    audioEl.playbackRate = state.audioSpeed;

    try {
      await audioEl.play();
      if (statusEl) statusEl.textContent = 'Streaming chapter narration';
      updatePlayPauseIcon(true);
    } catch (err) {
      if (state.narrationSource === 'auto') {
        showToast('Recorded audio unavailable; using Browser TTS');
        startBrowserSpeech();
      } else {
        if (statusEl) statusEl.textContent = 'Audio unavailable for this chapter';
        updatePlayPauseIcon(false);
      }
    }
  }

  function startBrowserSpeech() {
    if (!('speechSynthesis' in window)) {
      showToast('Speech synthesis not supported in this browser.');
      return;
    }
    window.speechSynthesis.cancel();
    const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
    const badgeEl = document.getElementById('audioSourceBadge');
    const statusEl = document.getElementById('audioStatusText');
    if (badgeEl) badgeEl.textContent = 'Browser TTS';
    if (statusEl) statusEl.textContent = 'Speaking via device voice';

    const fullText = `${book.name} chapter ${state.chapter}. ` +
      state.currentVerses.map((v) => v.text).join(' ');
    const utter = new SpeechSynthesisUtterance(fullText);
    utter.rate = state.audioSpeed;
    utter.onend = () => {
      ttsActive = false;
      updatePlayPauseIcon(false);
      if (statusEl) statusEl.textContent = 'Finished';
      if (state.audioAutoNext) stepChapter(1).then(() => startChapterAudio());
    };
    ttsActive = true;
    updatePlayPauseIcon(true);
    window.speechSynthesis.speak(utter);
  }

  function stopAllAudio() {
    if (audioEl) {
      audioEl.pause();
      audioEl.currentTime = 0;
    }
    if ('speechSynthesis' in window) {
      window.speechSynthesis.cancel();
    }
    ttsActive = false;
    updatePlayPauseIcon(false);
  }

  function toggleAudioPlayPause() {
    if (ttsActive && 'speechSynthesis' in window) {
      if (window.speechSynthesis.paused) {
        window.speechSynthesis.resume();
        updatePlayPauseIcon(true);
      } else {
        window.speechSynthesis.pause();
        updatePlayPauseIcon(false);
      }
      return;
    }
    if (!audioEl.src) {
      startChapterAudio();
      return;
    }
    if (audioEl.paused) {
      audioEl.play();
      updatePlayPauseIcon(true);
    } else {
      audioEl.pause();
      updatePlayPauseIcon(false);
    }
  }

  function updatePlayPauseIcon(playing) {
    const icon = document.getElementById('audioPlayIcon');
    if (icon) icon.textContent = playing ? '⏸' : '▶';
  }

  function formatSeconds(sec) {
    if (!isFinite(sec) || sec < 0) return '0:00';
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  if (audioEl) {
    audioEl.addEventListener('timeupdate', () => {
      const curEl = document.getElementById('audioCurrentTime');
      const durEl = document.getElementById('audioDurationTime');
      const seek = document.getElementById('audioSeekRange');
      if (curEl) curEl.textContent = formatSeconds(audioEl.currentTime);
      if (durEl) durEl.textContent = formatSeconds(audioEl.duration);
      if (seek && isFinite(audioEl.duration) && audioEl.duration > 0) {
        seek.value = String((audioEl.currentTime / audioEl.duration) * 100);
      }
    });
    audioEl.addEventListener('ended', () => {
      updatePlayPauseIcon(false);
      const statusEl = document.getElementById('audioStatusText');
      if (statusEl) statusEl.textContent = 'Completed';
      if (state.audioAutoNext) {
        stepChapter(1).then(() => startChapterAudio());
      }
    });
  }

  // Step Next / Previous Chapter
  async function stepChapter(delta) {
    const idx = CANONICAL_BOOKS.findIndex((b) => b.id === state.bookId);
    const currentBook = CANONICAL_BOOKS[idx] || CANONICAL_BOOKS[0];
    let targetBook = currentBook;
    let targetChap = state.chapter + delta;

    if (targetChap < 1) {
      if (idx > 0) {
        targetBook = CANONICAL_BOOKS[idx - 1];
        targetChap = targetBook.chapters;
      } else {
        targetChap = 1;
      }
    } else if (targetChap > currentBook.chapters) {
      if (idx < CANONICAL_BOOKS.length - 1) {
        targetBook = CANONICAL_BOOKS[idx + 1];
        targetChap = 1;
      } else {
        targetChap = currentBook.chapters;
      }
    }
    await navigateToPassage(targetBook.id, targetChap, null, false);
  }

  // Reference Parser (e.g., "John 3:16", "Ps 23", "1 Cor 13:4", "Gen 1")
  function parseBibleReference(input) {
    const clean = input.trim();
    const m = clean.match(/^([1-3]?\s*[a-zA-Z]+)\s+(\d+)(?::(\d+))?$/);
    if (!m) return null;
    const bookQuery = m[1].toLowerCase().replace(/\s+/g, '');
    const chapter = parseInt(m[2], 10);
    const verse = m[3] ? parseInt(m[3], 10) : null;

    const matchedBook = CANONICAL_BOOKS.find((b) => {
      const nameClean = b.name.toLowerCase().replace(/\s+/g, '');
      const abbrClean = b.abbr.toLowerCase().replace(/\s+/g, '');
      return (
        b.id === bookQuery ||
        nameClean === bookQuery ||
        abbrClean === bookQuery ||
        nameClean.startsWith(bookQuery)
      );
    });

    if (!matchedBook) return null;
    return { bookId: matchedBook.id, chapter, verse };
  }

  // Render Home Dashboard
  function renderDashboard() {
    updateHeaderLabels();
    const bmEl = document.getElementById('statBookmarks');
    const hlEl = document.getElementById('statHighlights');
    const ntEl = document.getElementById('statNotes');
    if (bmEl) bmEl.textContent = String(state.bookmarks.length);
    if (hlEl) hlEl.textContent = String(Object.keys(state.highlights).length);
    if (ntEl) ntEl.textContent = String(state.notes.length);

    // Verse of the Day based on day of year
    const dayIndex = Math.floor(Date.now() / 86400000) % DAILY_VERSES.length;
    const votd = DAILY_VERSES[dayIndex];
    const votdRef = document.getElementById('votdRef');
    const votdText = document.getElementById('votdText');
    if (votdRef) votdRef.textContent = votd.ref;
    if (votdText) votdText.textContent = `“${votd.text}”`;

    const votdBtn = document.getElementById('votdReadContextBtn');
    if (votdBtn) {
      votdBtn.onclick = () => navigateToPassage(votd.book, votd.chapter, votd.verse, true);
    }
    const votdCopy = document.getElementById('votdCopyBtn');
    if (votdCopy) {
      votdCopy.onclick = () => {
        navigator.clipboard.writeText(`${votd.ref} (KJV) — "${votd.text}"`);
        showToast('Copied Verse of the Day');
      };
    }

    // Active Reading Plan Summary
    const planWrap = document.getElementById('homePlanContainer');
    const plan = READING_PLANS.find((p) => p.id === state.activePlanId) || READING_PLANS[0];
    const doneDays = state.planProgress[plan.id] || [];
    const pct = Math.round((doneDays.length / plan.length) * 100);
    let nextDayObj = plan.days.find((d) => !doneDays.includes(d.day)) || plan.days[0];
    if (planWrap) {
      const readingsStr = nextDayObj.readings.map((r) => `${r.bookName} ${r.chapter}`).join(', ');
      planWrap.innerHTML = `
        <h4 style="margin-bottom:4px;">${escapeHtml(plan.name)}</h4>
        <p class="card-desc" style="margin-bottom:8px;">${doneDays.length} of ${plan.length} days completed (${pct}%)</p>
        <div class="progress-bar-track"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
        <div style="display:flex;justify-content:space-between;align-items:center;margin-top:12px;gap:8px;">
          <span style="font-size:13px;"><strong>Day ${nextDayObj.day}:</strong> ${escapeHtml(readingsStr)}</span>
          <button class="btn-outline btn-sm" id="homeStartDayReadingBtn">Read Today →</button>
        </div>
      `;
      const startDayBtn = document.getElementById('homeStartDayReadingBtn');
      if (startDayBtn && nextDayObj.readings[0]) {
        startDayBtn.onclick = () => navigateToPassage(nextDayObj.readings[0].book, nextDayObj.readings[0].chapter, null, true);
      }
    }

    // Recent Bookmarks & Notes
    const recentEl = document.getElementById('homeRecentSaved');
    if (recentEl) {
      const combined = [
        ...state.notes.map((n) => ({ type: 'Note', ...n })),
        ...state.bookmarks.map((b) => ({ type: 'Bookmark', ...b }))
      ].slice(0, 4);

      if (!combined.length) {
        recentEl.innerHTML = `<p class="muted-text" style="font-size:14px;">Click any verse while reading to bookmark, highlight, or write study notes.</p>`;
      } else {
        recentEl.innerHTML = combined.map((item) => `
          <div style="padding:8px 0;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;">
            <div>
              <strong class="saved-ref" data-jump-ref="${item.book_id}:${item.chapter}:${item.verse}">${escapeHtml(item.book_name)} ${item.chapter}:${item.verse}</strong>
              <span style="font-size:12px;color:var(--text-muted);margin-left:6px;">(${item.type})</span>
              <p style="font-size:13px;color:var(--text-muted);margin-top:2px;">${escapeHtml((item.body || item.text || '').slice(0, 80))}</p>
            </div>
          </div>
        `).join('');
        recentEl.querySelectorAll('[data-jump-ref]').forEach((el) => {
          el.addEventListener('click', () => {
            const [b, c, v] = el.dataset.jumpRef.split(':');
            navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
          });
        });
      }
    }

    // Perspective pills
    const pillsWrap = document.getElementById('homePerspectivePills');
    if (pillsWrap) {
      pillsWrap.innerHTML = state.perspectives.map((p) => `
        <button class="persp-chip" data-open-persp="${p.id}">
          <span class="persp-dot" style="background:${p.color || '#8C3B2E'}"></span>
          <span>${escapeHtml(p.label)}</span>
        </button>
      `).join('');
      pillsWrap.querySelectorAll('[data-open-persp]').forEach((btn) => {
        btn.addEventListener('click', () => {
          state.activePerspectiveFilter = btn.dataset.openPersp;
          state.aiPanelOpen = true;
          applyThemeAndTypography();
          setTab('read');
          renderAiPerspectivesPanel();
        });
      });
    }
  }

  // Render Library View
  function renderLibrary() {
    // Bookmarks
    const bmContainer = document.getElementById('bookmarksListContainer');
    if (bmContainer) {
      if (!state.bookmarks.length) {
        bmContainer.innerHTML = `<p class="muted-text">No bookmarks saved yet. Click any verse in the reader to bookmark it.</p>`;
      } else {
        bmContainer.innerHTML = state.bookmarks.map((bm, idx) => `
          <div class="saved-card">
            <div>
              <div class="saved-card-header">
                <span class="saved-ref" data-lib-jump="${bm.book_id}:${bm.chapter}:${bm.verse}">${escapeHtml(bm.book_name)} ${bm.chapter}:${bm.verse}</span>
                <button class="btn-text" data-del-bm="${idx}" style="color:var(--text-muted)">Remove</button>
              </div>
              <p class="saved-verse-text" style="margin-top:8px;">“${escapeHtml(bm.text)}”</p>
            </div>
          </div>
        `).join('');
        bmContainer.querySelectorAll('[data-lib-jump]').forEach((el) => {
          el.onclick = () => {
            const [b, c, v] = el.dataset.libJump.split(':');
            navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
          };
        });
        bmContainer.querySelectorAll('[data-del-bm]').forEach((btn) => {
          btn.onclick = () => {
            state.bookmarks.splice(parseInt(btn.dataset.delBm, 10), 1);
            saveState();
            renderLibrary();
          };
        });
      }
    }

    // Highlights
    const hlContainer = document.getElementById('highlightsListContainer');
    if (hlContainer) {
      const entries = Object.entries(state.highlights);
      if (!entries.length) {
        hlContainer.innerHTML = `<p class="muted-text">No highlighted verses yet. Select any verse while reading to choose a highlight color.</p>`;
      } else {
        hlContainer.innerHTML = entries.map(([key, color]) => {
          const parts = key.split(':');
          const bId = parts[1];
          const ch = parts[2];
          const v = parts[3];
          const bObj = BOOK_BY_ID[bId] || { name: bId };
          return `
            <div class="saved-card">
              <div class="saved-card-header">
                <span class="saved-ref" data-lib-jump="${bId}:${ch}:${v}">${escapeHtml(bObj.name)} ${ch}:${v}</span>
                <span class="v-badge" style="text-transform:capitalize;">${escapeHtml(color)}</span>
              </div>
              <div style="display:flex;justify-content:flex-end;margin-top:8px;">
                <button class="btn-text" data-del-hl="${key}">Clear Highlight</button>
              </div>
            </div>
          `;
        }).join('');
        hlContainer.querySelectorAll('[data-lib-jump]').forEach((el) => {
          el.onclick = () => {
            const [b, c, v] = el.dataset.libJump.split(':');
            navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
          };
        });
        hlContainer.querySelectorAll('[data-del-hl]').forEach((btn) => {
          btn.onclick = () => {
            delete state.highlights[btn.dataset.delHl];
            saveState();
            renderLibrary();
            renderVersesList();
          };
        });
      }
    }

    // Notes
    const notesContainer = document.getElementById('notesListContainer');
    if (notesContainer) {
      if (!state.notes.length) {
        notesContainer.innerHTML = `<p class="muted-text">No personal study notes yet. Click any verse and press "Note" to write reflections.</p>`;
      } else {
        notesContainer.innerHTML = state.notes.map((n, idx) => `
          <div class="saved-card">
            <div>
              <div class="saved-card-header">
                <span class="saved-ref" data-lib-jump="${n.book_id}:${n.chapter}:${n.verse}">${escapeHtml(n.book_name)} ${n.chapter}:${n.verse}</span>
                <button class="btn-text" data-del-note="${idx}" style="color:var(--text-muted)">Delete</button>
              </div>
              <p class="saved-verse-text" style="margin:6px 0;font-size:13.5px;opacity:0.85;">“${escapeHtml(n.text)}”</p>
              <div class="saved-note-body">${escapeHtml(n.body)}</div>
            </div>
          </div>
        `).join('');
        notesContainer.querySelectorAll('[data-lib-jump]').forEach((el) => {
          el.onclick = () => {
            const [b, c, v] = el.dataset.libJump.split(':');
            navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
          };
        });
        notesContainer.querySelectorAll('[data-del-note]').forEach((btn) => {
          btn.onclick = () => {
            state.notes.splice(parseInt(btn.dataset.delNote, 10), 1);
            saveState();
            renderLibrary();
          };
        });
      }
    }

    // Reading Plans
    const plansContainer = document.getElementById('plansListContainer');
    if (plansContainer) {
      plansContainer.innerHTML = READING_PLANS.map((plan) => {
        const done = state.planProgress[plan.id] || [];
        const pct = Math.round((done.length / plan.length) * 100);
        const isActive = state.activePlanId === plan.id;
        const daysBoxes = plan.days.slice(0, 60).map((d) => {
          const isDone = done.includes(d.day);
          const firstRef = d.readings[0];
          const label = d.readings.map((r) => `${r.bookName} ${r.chapter}`).join(', ');
          return `
            <div class="plan-day-box ${isDone ? 'done' : ''}">
              <label style="display:flex;align-items:center;gap:6px;cursor:pointer;flex:1;">
                <input type="checkbox" data-plan-check="${plan.id}:${d.day}" ${isDone ? 'checked' : ''} />
                <span><strong>Day ${d.day}:</strong> ${escapeHtml(label)}</span>
              </label>
              ${firstRef ? `<button class="btn-text" data-lib-jump="${firstRef.book}:${firstRef.chapter}:1">Read</button>` : ''}
            </div>
          `;
        }).join('');

        return `
          <div class="plan-card">
            <div class="plan-card-top">
              <div>
                <h3>${escapeHtml(plan.name)} ${isActive ? '<span class="v-badge">Active Plan</span>' : ''}</h3>
                <p class="card-desc" style="margin-bottom:0;">${escapeHtml(plan.description)}</p>
              </div>
              <button class="btn-outline btn-sm" data-activate-plan="${plan.id}">
                ${isActive ? 'Selected' : 'Set as Active'}
              </button>
            </div>
            <div class="progress-bar-track"><div class="progress-bar-fill" style="width:${pct}%"></div></div>
            <span style="font-size:12.5px;color:var(--text-muted);">${done.length} / ${plan.length} days completed (${pct}%)</span>
            <div class="plan-days-grid">${daysBoxes}</div>
          </div>
        `;
      }).join('');

      plansContainer.querySelectorAll('[data-activate-plan]').forEach((btn) => {
        btn.onclick = () => {
          state.activePlanId = btn.dataset.activatePlan;
          saveState();
          renderLibrary();
          showToast('Active reading plan updated');
        };
      });

      plansContainer.querySelectorAll('[data-plan-check]').forEach((chk) => {
        chk.onchange = () => {
          const [pId, dayStr] = chk.dataset.planCheck.split(':');
          const dayNum = parseInt(dayStr, 10);
          const arr = new Set(state.planProgress[pId] || []);
          if (chk.checked) arr.add(dayNum);
          else arr.delete(dayNum);
          state.planProgress[pId] = Array.from(arr);
          saveState();
          renderLibrary();
        };
      });

      plansContainer.querySelectorAll('[data-lib-jump]').forEach((el) => {
        el.onclick = () => {
          const [b, c, v] = el.dataset.libJump.split(':');
          navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
        };
      });
    }

    // History
    const histContainer = document.getElementById('historyListContainer');
    if (histContainer) {
      if (!state.history.length) {
        histContainer.innerHTML = `<p class="muted-text">No reading history yet.</p>`;
      } else {
        histContainer.innerHTML = state.history.map((h) => `
          <div class="saved-card">
            <div class="saved-card-header">
              <span class="saved-ref" data-lib-jump="${h.bookId}:${h.chapter}:${h.verse || 1}">${escapeHtml(h.bookName)} ${h.chapter}</span>
              <span style="font-size:12px;color:var(--text-muted);">${new Date(h.readAt).toLocaleDateString()}</span>
            </div>
          </div>
        `).join('');
        histContainer.querySelectorAll('[data-lib-jump]').forEach((el) => {
          el.onclick = () => {
            const [b, c, v] = el.dataset.libJump.split(':');
            navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
          };
        });
      }
    }
  }

  // Book & Chapter Picker Modal
  function openBookPickerModal() {
    state.modalBookId = state.bookId;
    const modal = document.getElementById('bookPickerModal');
    if (modal) modal.classList.remove('hidden');
    renderModalBooksAndChapters();
  }

  function renderModalBooksAndChapters() {
    const filterInput = document.getElementById('bookFilterInput');
    const query = (filterInput ? filterInput.value : '').trim().toLowerCase();
    const booksListEl = document.getElementById('modalBooksList');
    const chapsGridEl = document.getElementById('modalChaptersGrid');
    const selectedTitleEl = document.getElementById('modalSelectedBookTitle');

    const filteredBooks = CANONICAL_BOOKS.filter((b) => {
      if (state.modalTestament !== 'all' && b.testament !== state.modalTestament) return false;
      if (query && !b.name.toLowerCase().includes(query) && !b.abbr.toLowerCase().includes(query)) return false;
      return true;
    });

    if (booksListEl) {
      booksListEl.innerHTML = filteredBooks.map((b) => `
        <button class="book-row-btn ${b.id === state.modalBookId ? 'active' : ''}" data-pick-book="${b.id}">
          <span>${escapeHtml(b.name)}</span>
          <span style="font-size:12px;opacity:0.75;">${b.chapters} ch</span>
        </button>
      `).join('');

      booksListEl.querySelectorAll('[data-pick-book]').forEach((btn) => {
        btn.onclick = () => {
          state.modalBookId = btn.dataset.pickBook;
          renderModalBooksAndChapters();
        };
      });
    }

    const activeBook = BOOK_BY_ID[state.modalBookId] || CANONICAL_BOOKS[0];
    if (selectedTitleEl) selectedTitleEl.textContent = `${activeBook.name} (${activeBook.chapters} Chapters)`;

    if (chapsGridEl) {
      let buttons = '';
      for (let c = 1; c <= activeBook.chapters; c++) {
        const isCurrent = activeBook.id === state.bookId && c === state.chapter;
        buttons += `<button class="chap-num-btn ${isCurrent ? 'active' : ''}" data-pick-chap="${c}">${c}</button>`;
      }
      chapsGridEl.innerHTML = buttons;
      chapsGridEl.querySelectorAll('[data-pick-chap]').forEach((btn) => {
        btn.onclick = () => {
          const ch = parseInt(btn.dataset.pickChap, 10);
          document.getElementById('bookPickerModal').classList.add('hidden');
          navigateToPassage(activeBook.id, ch, null, true);
        };
      });
    }
  }

  // Search Modal
  async function executeSearch(queryText) {
    const q = queryText.trim();
    if (!q) return;

    // Check if it's a direct scripture reference first
    const parsedRef = parseBibleReference(q);
    if (parsedRef) {
      document.getElementById('searchModal').classList.add('hidden');
      await navigateToPassage(parsedRef.bookId, parsedRef.chapter, parsedRef.verse, true);
      return;
    }

    const modal = document.getElementById('searchModal');
    if (modal) modal.classList.remove('hidden');
    const inputEl = document.getElementById('modalSearchInput');
    if (inputEl) inputEl.value = q;
    const metaEl = document.getElementById('searchMetaBar');
    const listEl = document.getElementById('searchResultsList');
    if (metaEl) metaEl.textContent = `Searching "${q}" in ${state.translationId.toUpperCase()}…`;
    if (listEl) listEl.innerHTML = '';

    try {
      const res = await fetch(`/api/search?q=${encodeURIComponent(q)}&translation_id=${encodeURIComponent(state.translationId)}&limit=60`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      const results = data.results || [];
      if (metaEl) metaEl.textContent = `Found ${results.length} matching verses for "${q}"`;
      if (!results.length) {
        listEl.innerHTML = `<p class="muted-text">No matching verses found.</p>`;
        return;
      }
      listEl.innerHTML = results.map((r) => `
        <div class="search-hit-card" data-hit="${r.book}:${r.chapter}:${r.verse}">
          <strong style="color:var(--primary)">${escapeHtml(r.bookName)} ${r.chapter}:${r.verse}</strong>
          <p class="saved-verse-text" style="margin-top:4px;">${escapeHtml(r.text)}</p>
        </div>
      `).join('');
      listEl.querySelectorAll('[data-hit]').forEach((card) => {
        card.onclick = () => {
          const [b, c, v] = card.dataset.hit.split(':');
          modal.classList.add('hidden');
          navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
        };
      });
    } catch (err) {
      if (metaEl) metaEl.textContent = `Search failed: ${err.message}`;
    }
  }

  // Cloud Sync & Server Diagnostics
  async function refreshServerDiagnostics() {
    try {
      const res = await fetch('/api/health');
      if (!res.ok) throw new Error('Offline');
      const data = await res.json();
      const st = document.getElementById('diagStatus');
      const sg = document.getElementById('diagStorage');
      const ip = document.getElementById('diagInterpretations');
      const ch = document.getElementById('diagChapters');
      const totalNotes = data.interpretations ?? data.coverage?.total_interpretations ?? 0;
      const chaptersCov = data.chaptersCovered ?? data.coverage?.chapters_covered ?? 0;
      if (st) st.textContent = 'Online ✓';
      if (sg) sg.textContent = (data.storage || 'sqlite').toUpperCase();
      if (ip) ip.textContent = totalNotes.toLocaleString();
      if (ch) ch.textContent = `${chaptersCov.toLocaleString()} / 1,189`;

      const homeBadge = document.getElementById('homeCoverageBadge');
      if (homeBadge && totalNotes) {
        homeBadge.textContent = `${totalNotes.toLocaleString()} Notes`;
      }
    } catch (_) {
      const st = document.getElementById('diagStatus');
      if (st) st.textContent = 'Offline (Local Mode)';
    }
  }

  function buildSyncPayload() {
    const hlList = Object.entries(state.highlights).map(([key, color]) => {
      const [translation_id, book_id, ch, v] = key.split(':');
      const bookObj = BOOK_BY_ID[book_id] || { name: book_id };
      return {
        translation_id,
        book_id,
        book_name: bookObj.name,
        chapter: parseInt(ch, 10),
        verse: parseInt(v, 10),
        text: '',
        color: color === 'gold' ? 1 : color === 'green' ? 2 : color === 'blue' ? 3 : 4,
        created_at: new Date().toISOString()
      };
    });
    const planRows = [];
    Object.entries(state.planProgress).forEach(([plan_id, days]) => {
      days.forEach((day) => {
        planRows.push({ plan_id, day, completed_at: new Date().toISOString() });
      });
    });

    return {
      bookmarks: state.bookmarks,
      highlights: hlList,
      notes: state.notes,
      planProgress: planRows,
      settings: {
        translationId: state.translationId,
        bookId: state.bookId,
        defaultPerspective: state.defaultPerspective
      },
      exportedAt: new Date().toISOString()
    };
  }

  async function pushCloudSync() {
    const msgEl = document.getElementById('syncStatusMsg');
    const uid = (document.getElementById('syncUserIdInput')?.value || state.userId).trim();
    if (!uid || uid.length < 3) {
      showToast('Enter a valid Sync ID (at least 3 characters)');
      return;
    }
    state.userId = uid;
    saveState();
    if (msgEl) msgEl.textContent = 'Syncing to server…';
    try {
      const res = await fetch(`/api/sync?user_id=${encodeURIComponent(uid)}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ data: buildSyncPayload() })
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      if (msgEl) msgEl.textContent = `Synced to cloud at ${new Date().toLocaleTimeString()}`;
      showToast('Cloud sync complete ✓');
    } catch (err) {
      if (msgEl) msgEl.textContent = `Sync failed: ${err.message}`;
    }
  }

  async function pullCloudSync() {
    const msgEl = document.getElementById('syncStatusMsg');
    const uid = (document.getElementById('syncUserIdInput')?.value || state.userId).trim();
    if (!uid) return;
    state.userId = uid;
    if (msgEl) msgEl.textContent = 'Pulling from server…';
    try {
      const res = await fetch(`/api/sync/${encodeURIComponent(uid)}`);
      if (res.status === 404) {
        if (msgEl) msgEl.textContent = 'No cloud data found for this Sync ID yet.';
        return;
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const raw = await res.json();
      const data = raw.data || raw;
      if (Array.isArray(data.bookmarks)) state.bookmarks = data.bookmarks;
      if (Array.isArray(data.notes)) state.notes = data.notes;
      if (Array.isArray(data.highlights)) {
        const hlMap = {};
        data.highlights.forEach((h) => {
          const colorName = h.color === 2 ? 'green' : h.color === 3 ? 'blue' : h.color === 4 ? 'pink' : 'gold';
          hlMap[`${h.translation_id || 'en-kjv'}:${h.book_id}:${h.chapter}:${h.verse}`] = colorName;
        });
        state.highlights = hlMap;
      }
      if (Array.isArray(data.planProgress)) {
        const pMap = {};
        data.planProgress.forEach((p) => {
          if (!pMap[p.plan_id]) pMap[p.plan_id] = [];
          if (!pMap[p.plan_id].includes(p.day)) pMap[p.plan_id].push(p.day);
        });
        state.planProgress = pMap;
      }
      saveState();
      renderDashboard();
      renderVersesList();
      if (msgEl) msgEl.textContent = `Restored from cloud at ${new Date().toLocaleTimeString()}`;
      showToast('Restored study data from cloud ✓');
    } catch (err) {
      if (msgEl) msgEl.textContent = `Restore failed: ${err.message}`;
    }
  }

  function escapeHtml(str) {
    return String(str ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  // Wire up Event Listeners
  function bindEvents() {
    // Tab switching
    document.querySelectorAll('[data-tab]').forEach((btn) => {
      btn.addEventListener('click', () => setTab(btn.dataset.tab));
    });
    document.querySelectorAll('[data-goto-tab]').forEach((btn) => {
      btn.addEventListener('click', () => setTab(btn.dataset.gotoTab));
    });
    document.getElementById('brandHomeBtn')?.addEventListener('click', () => setTab('home'));
    document.getElementById('homeManagePlansBtn')?.addEventListener('click', () => {
      setTab('library');
      document.querySelector('[data-libtab="plans"]')?.click();
    });

    // Hero buttons
    document.getElementById('heroReadBtn')?.addEventListener('click', () => setTab('read'));
    document.getElementById('heroListenBtn')?.addEventListener('click', () => {
      setTab('read');
      startChapterAudio();
    });

    // Quick Jump Form & Chips
    document.getElementById('quickJumpForm')?.addEventListener('submit', (e) => {
      e.preventDefault();
      const val = document.getElementById('quickJumpInput')?.value || '';
      if (val.trim()) executeSearch(val);
    });
    document.querySelectorAll('[data-jump]').forEach((chip) => {
      chip.addEventListener('click', () => {
        const [b, c, v] = chip.dataset.jump.split(':');
        navigateToPassage(b, parseInt(c, 10), parseInt(v, 10), true);
      });
    });

    // Header actions
    document.getElementById('openBookPickerBtn')?.addEventListener('click', openBookPickerModal);
    document.getElementById('readerTitlePickerBtn')?.addEventListener('click', openBookPickerModal);
    document.getElementById('closeBookPickerBtn')?.addEventListener('click', () => {
      document.getElementById('bookPickerModal')?.classList.add('hidden');
    });
    document.getElementById('bookFilterInput')?.addEventListener('input', renderModalBooksAndChapters);
    document.querySelectorAll('.test-tab').forEach((tab) => {
      tab.addEventListener('click', () => {
        document.querySelectorAll('.test-tab').forEach((t) => t.classList.remove('active'));
        tab.classList.add('active');
        state.modalTestament = tab.dataset.testament;
        renderModalBooksAndChapters();
      });
    });

    // Translation select
    document.getElementById('headerTranslationSelect')?.addEventListener('change', (e) => {
      state.translationId = e.target.value;
      saveState();
      updateHeaderLabels();
      loadChapterScripture();
    });

    // Search Modal
    document.getElementById('openSearchBtn')?.addEventListener('click', () => {
      document.getElementById('searchModal')?.classList.remove('hidden');
      document.getElementById('modalSearchInput')?.focus();
    });
    document.getElementById('closeSearchModalBtn')?.addEventListener('click', () => {
      document.getElementById('searchModal')?.classList.add('hidden');
    });
    document.getElementById('modalSearchForm')?.addEventListener('submit', (e) => {
      e.preventDefault();
      const q = document.getElementById('modalSearchInput')?.value || '';
      executeSearch(q);
    });

    // Keyboard shortcut Ctrl+K / Cmd+K for search
    window.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        document.getElementById('searchModal')?.classList.remove('hidden');
        document.getElementById('modalSearchInput')?.focus();
      }
      if (e.key === 'Escape') {
        document.getElementById('bookPickerModal')?.classList.add('hidden');
        document.getElementById('searchModal')?.classList.add('hidden');
        document.getElementById('noteModal')?.classList.add('hidden');
      }
    });

    // Reader Prev / Next chapter
    document.getElementById('prevChapterBtn')?.addEventListener('click', () => stepChapter(-1));
    document.getElementById('nextChapterBtn')?.addEventListener('click', () => stepChapter(1));
    document.getElementById('bottomPrevChapterBtn')?.addEventListener('click', () => stepChapter(-1));
    document.getElementById('bottomNextChapterBtn')?.addEventListener('click', () => stepChapter(1));

    // AI Panel Toggle
    const toggleAi = () => {
      state.aiPanelOpen = !state.aiPanelOpen;
      saveState();
      applyThemeAndTypography();
      if (state.tab !== 'read') setTab('read');
    };
    document.getElementById('toggleAiDrawerBtn')?.addEventListener('click', toggleAi);
    document.getElementById('closeAiPanelBtn')?.addEventListener('click', () => {
      state.aiPanelOpen = false;
      saveState();
      applyThemeAndTypography();
    });
    document.getElementById('bottomOpenAiBtn')?.addEventListener('click', () => {
      state.aiPanelOpen = true;
      saveState();
      applyThemeAndTypography();
    });

    // Quick Theme Cycle
    const themes = ['parchment', 'sepia', 'midnight', 'obsidian'];
    document.getElementById('quickThemeBtn')?.addEventListener('click', () => {
      const nextIdx = (themes.indexOf(state.theme) + 1) % themes.length;
      state.theme = themes[nextIdx];
      saveState();
      applyThemeAndTypography();
      showToast(`Theme: ${state.theme.charAt(0).toUpperCase() + state.theme.slice(1)}`);
    });

    // Verse Action Toolbar actions
    document.getElementById('closeVerseToolbarBtn')?.addEventListener('click', closeVerseToolbar);
    document.querySelectorAll('.swatch').forEach((sw) => {
      sw.addEventListener('click', () => {
        if (!state.selectedVerse) return;
        const color = sw.dataset.hl;
        const key = highlightKey(state.bookId, state.chapter, state.selectedVerse);
        if (color === 'none') {
          delete state.highlights[key];
          showToast('Highlight cleared');
        } else {
          state.highlights[key] = color;
          showToast('Verse highlighted');
        }
        saveState();
        renderVersesList();
      });
    });

    document.getElementById('vatBookmarkBtn')?.addEventListener('click', () => {
      if (!state.selectedVerse) return;
      const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
      const vObj = state.currentVerses.find((v) => v.verse === state.selectedVerse);
      const existingIdx = state.bookmarks.findIndex(
        (b) => b.book_id === state.bookId && b.chapter === state.chapter && b.verse === state.selectedVerse
      );
      if (existingIdx >= 0) {
        state.bookmarks.splice(existingIdx, 1);
        showToast('Bookmark removed');
      } else {
        state.bookmarks.unshift({
          id: `${state.translationId}:${state.bookId}:${state.chapter}:${state.selectedVerse}`,
          translation_id: state.translationId,
          book_id: state.bookId,
          book_name: book.name,
          chapter: state.chapter,
          verse: state.selectedVerse,
          text: vObj ? vObj.text : '',
          created_at: new Date().toISOString()
        });
        showToast('Verse bookmarked ★');
      }
      saveState();
      selectVerse(state.selectedVerse);
      renderVersesList();
    });

    document.getElementById('vatCopyBtn')?.addEventListener('click', () => {
      if (!state.selectedVerse) return;
      const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
      const vObj = state.currentVerses.find((v) => v.verse === state.selectedVerse);
      if (vObj) {
        navigator.clipboard.writeText(`${book.name} ${state.chapter}:${state.selectedVerse} — "${vObj.text}"`);
        showToast('Copied verse to clipboard');
      }
    });

    document.getElementById('vatStudyAiBtn')?.addEventListener('click', () => {
      state.aiPanelOpen = true;
      saveState();
      applyThemeAndTypography();
    });

    // Note Modal
    document.getElementById('vatNoteBtn')?.addEventListener('click', () => {
      if (!state.selectedVerse) return;
      const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
      const vObj = state.currentVerses.find((v) => v.verse === state.selectedVerse);
      const existing = state.notes.find(
        (n) => n.book_id === state.bookId && n.chapter === state.chapter && n.verse === state.selectedVerse
      );
      document.getElementById('noteModalTitle').textContent = `Note on ${book.name} ${state.chapter}:${state.selectedVerse}`;
      document.getElementById('noteVersePreview').textContent = vObj ? `“${vObj.text}”` : '';
      document.getElementById('noteBodyTextarea').value = existing ? existing.body : '';
      document.getElementById('noteModal').classList.remove('hidden');
      document.getElementById('noteBodyTextarea').focus();
    });

    const closeNoteModal = () => document.getElementById('noteModal')?.classList.add('hidden');
    document.getElementById('closeNoteModalBtn')?.addEventListener('click', closeNoteModal);
    document.getElementById('cancelNoteBtn')?.addEventListener('click', closeNoteModal);

    document.getElementById('saveNoteBtn')?.addEventListener('click', () => {
      if (!state.selectedVerse) return;
      const body = document.getElementById('noteBodyTextarea').value.trim();
      if (!body) {
        closeNoteModal();
        return;
      }
      const book = BOOK_BY_ID[state.bookId] || BOOK_BY_ID['jhn'];
      const vObj = state.currentVerses.find((v) => v.verse === state.selectedVerse);
      const idx = state.notes.findIndex(
        (n) => n.book_id === state.bookId && n.chapter === state.chapter && n.verse === state.selectedVerse
      );
      const now = new Date().toISOString();
      if (idx >= 0) {
        state.notes[idx].body = body;
        state.notes[idx].updated_at = now;
      } else {
        state.notes.unshift({
          id: `note-${Date.now()}`,
          translation_id: state.translationId,
          book_id: state.bookId,
          book_name: book.name,
          chapter: state.chapter,
          verse: state.selectedVerse,
          text: vObj ? vObj.text : '',
          body,
          created_at: now,
          updated_at: now
        });
      }
      saveState();
      closeNoteModal();
      renderVersesList();
      showToast('Study note saved 📝');
    });

    document.getElementById('deleteNoteBtn')?.addEventListener('click', () => {
      const idx = state.notes.findIndex(
        (n) => n.book_id === state.bookId && n.chapter === state.chapter && n.verse === state.selectedVerse
      );
      if (idx >= 0) {
        state.notes.splice(idx, 1);
        saveState();
        renderVersesList();
        showToast('Note deleted');
      }
      closeNoteModal();
    });

    // Audio Dock Controls
    document.getElementById('toggleAudioBarBtn')?.addEventListener('click', () => {
      const dock = document.getElementById('audioPlayerDock');
      if (dock && dock.classList.contains('hidden')) {
        startChapterAudio();
      } else if (dock) {
        stopAllAudio();
        dock.classList.add('hidden');
      }
    });
    document.getElementById('audioPlayPauseBtn')?.addEventListener('click', toggleAudioPlayPause);
    document.getElementById('audioSkipBackBtn')?.addEventListener('click', () => {
      if (audioEl && audioEl.src) audioEl.currentTime = Math.max(0, audioEl.currentTime - 10);
    });
    document.getElementById('audioSkipFwdBtn')?.addEventListener('click', () => {
      if (audioEl && audioEl.src) audioEl.currentTime = Math.min(audioEl.duration || 0, audioEl.currentTime + 10);
    });
    document.getElementById('audioSeekRange')?.addEventListener('input', (e) => {
      if (audioEl && isFinite(audioEl.duration) && audioEl.duration > 0) {
        audioEl.currentTime = (parseFloat(e.target.value) / 100) * audioEl.duration;
      }
    });
    document.getElementById('audioSpeedSelect')?.addEventListener('change', (e) => {
      state.audioSpeed = parseFloat(e.target.value) || 1.0;
      if (audioEl) audioEl.playbackRate = state.audioSpeed;
      saveState();
    });
    document.getElementById('audioCloseDockBtn')?.addEventListener('click', () => {
      stopAllAudio();
      document.getElementById('audioPlayerDock')?.classList.add('hidden');
    });

    // Library subtabs
    document.querySelectorAll('[data-libtab]').forEach((btn) => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('[data-libtab]').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.library-panel').forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        document.getElementById('lib-' + btn.dataset.libtab)?.classList.add('active');
      });
    });
    document.getElementById('clearHistoryBtn')?.addEventListener('click', () => {
      state.history = [];
      saveState();
      renderLibrary();
      showToast('Reading history cleared');
    });

    // Settings controls
    document.querySelectorAll('[data-set-theme]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.theme = btn.dataset.setTheme;
        saveState();
        applyThemeAndTypography();
      });
    });
    document.getElementById('fontFamilySelect')?.addEventListener('change', (e) => {
      state.fontFamily = e.target.value;
      saveState();
      applyThemeAndTypography();
    });
    document.getElementById('fontSizeRange')?.addEventListener('input', (e) => {
      state.fontSize = parseInt(e.target.value, 10);
      saveState();
      applyThemeAndTypography();
    });
    document.getElementById('lineHeightRange')?.addEventListener('input', (e) => {
      state.lineHeight = parseFloat(e.target.value);
      saveState();
      applyThemeAndTypography();
    });
    document.getElementById('showVerseNumsToggle')?.addEventListener('change', (e) => {
      state.showVerseNumbers = e.target.checked;
      saveState();
      applyThemeAndTypography();
    });
    document.getElementById('narrationSourceSelect')?.addEventListener('change', (e) => {
      state.narrationSource = e.target.value;
      saveState();
    });
    document.getElementById('audioAutoNextToggle')?.addEventListener('change', (e) => {
      state.audioAutoNext = e.target.checked;
      saveState();
    });

    // Sync & Backup
    document.getElementById('copySyncIdBtn')?.addEventListener('click', () => {
      const val = document.getElementById('syncUserIdInput')?.value || state.userId;
      navigator.clipboard.writeText(val);
      showToast('Copied Sync ID');
    });
    document.getElementById('pushSyncBtn')?.addEventListener('click', pushCloudSync);
    document.getElementById('pullSyncBtn')?.addEventListener('click', pullCloudSync);
    document.getElementById('exportJsonBtn')?.addEventListener('click', () => {
      const blob = new Blob([JSON.stringify(buildSyncPayload(), null, 2)], { type: 'application/json' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `bibleai-study-backup-${new Date().toISOString().slice(0, 10)}.json`;
      a.click();
      URL.revokeObjectURL(url);
    });
    document.getElementById('importJsonInput')?.addEventListener('change', (e) => {
      const file = e.target.files?.[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = () => {
        try {
          const data = JSON.parse(String(reader.result));
          if (Array.isArray(data.bookmarks)) state.bookmarks = data.bookmarks;
          if (Array.isArray(data.notes)) state.notes = data.notes;
          saveState();
          renderDashboard();
          renderLibrary();
          showToast('Imported backup successfully ✓');
        } catch (err) {
          showToast('Invalid JSON backup file');
        }
      };
      reader.readAsText(file);
    });
  }

  // Initial Bootstrap
  async function initApp() {
    loadState();
    applyThemeAndTypography();
    bindEvents();

    // Load catalog and perspectives from server
    try {
      const [catRes, perspRes] = await Promise.all([
        fetch('/api/catalog'),
        fetch('/api/perspectives')
      ]);
      if (catRes.ok) {
        const catData = await catRes.json();
        if (Array.isArray(catData.translations) && catData.translations.length) {
          state.catalog = catData.translations;
          const sel = document.getElementById('headerTranslationSelect');
          if (sel) {
            sel.innerHTML = state.catalog.map((t) =>
              `<option value="${escapeHtml(t.id)}" ${t.id === state.translationId ? 'selected' : ''}>${escapeHtml(t.abbreviation || t.id.toUpperCase())} — ${escapeHtml(t.name)}</option>`
            ).join('');
          }
        }
      }
      if (perspRes.ok) {
        const perspData = await perspRes.json();
        if (Array.isArray(perspData.perspectives) && perspData.perspectives.length) {
          state.perspectives = perspData.perspectives;
        }
      }
    } catch (_) {
      // Offline fallback works with defaults
    }

    const defPerspSel = document.getElementById('defaultPerspectiveSelect');
    if (defPerspSel) {
      defPerspSel.innerHTML = state.perspectives.map((p) =>
        `<option value="${escapeHtml(p.id)}" ${p.id === state.defaultPerspective ? 'selected' : ''}>${escapeHtml(p.label)}</option>`
      ).join('');
      defPerspSel.onchange = (e) => {
        state.defaultPerspective = e.target.value;
        saveState();
      };
    }

    renderDashboard();
    await Promise.all([
      loadChapterScripture(),
      loadChapterInterpretations(),
      refreshServerDiagnostics()
    ]);

    if ('serviceWorker' in navigator) {
      navigator.serviceWorker.register('/sw.js').catch(() => {});
    }
  }

  document.addEventListener('DOMContentLoaded', initApp);
})();
