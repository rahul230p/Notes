(function () {
  const notes = Array.isArray(window.NOTES_DATA) ? window.NOTES_DATA : [];
  const els = {
    activeTitle: document.getElementById("activeTitle"),
    emptyState: document.getElementById("emptyState"),
    listViewButton: document.getElementById("listViewButton"),
    noteCount: document.getElementById("noteCount"),
    noteList: document.getElementById("noteList"),
    noteListPanel: document.getElementById("noteListPanel"),
    reader: document.getElementById("reader"),
    readViewButton: document.getElementById("readViewButton"),
    resultCount: document.getElementById("resultCount"),
    searchInput: document.getElementById("searchInput"),
    sortSelect: document.getElementById("sortSelect"),
    themeToggle: document.getElementById("themeToggle"),
    topicCount: document.getElementById("topicCount"),
    topicList: document.getElementById("topicList")
  };

  const state = {
    category: "All",
    noteId: notes[0] ? notes[0].id : "",
    query: "",
    sort: "title",
    view: "list"
  };

  const collator = new Intl.Collator(undefined, { sensitivity: "base", numeric: true });

  function escapeHtml(value) {
    return String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");
  }

  function slug(value) {
    return String(value).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/(^-|-$)/g, "");
  }

  function hashRoute() {
    const params = new URLSearchParams(location.hash.replace(/^#\/?/, ""));
    state.category = params.get("topic") || "All";
    state.noteId = params.get("note") || state.noteId;
    state.query = params.get("q") || "";
    state.view = params.get("view") || state.view;
    if (els.searchInput.value !== state.query) {
      els.searchInput.value = state.query;
    }
  }

  function setRoute() {
    const params = new URLSearchParams();
    if (state.category !== "All") params.set("topic", state.category);
    if (state.noteId) params.set("note", state.noteId);
    if (state.query) params.set("q", state.query);
    if (state.view !== "list") params.set("view", state.view);
    history.replaceState(null, "", "#/" + params.toString());
  }

  function categories() {
    const counts = new Map();
    notes.forEach((note) => counts.set(note.category, (counts.get(note.category) || 0) + 1));
    return [["All", notes.length], ...Array.from(counts.entries()).sort((a, b) => collator.compare(a[0], b[0]))];
  }

  function filteredNotes() {
    const query = state.query.trim().toLowerCase();
    let items = notes.filter((note) => state.category === "All" || note.category === state.category);
    if (query) {
      const tokens = query.split(/\s+/).filter(Boolean);
      items = items.filter((note) => {
        const haystack = `${note.title} ${note.category} ${note.path} ${note.summary} ${note.content}`.toLowerCase();
        return tokens.every((token) => haystack.includes(token));
      });
    }
    return items.sort((a, b) => {
      if (state.sort === "words") return b.words - a.words || collator.compare(a.title, b.title);
      if (state.sort === "category") return collator.compare(a.category, b.category) || collator.compare(a.title, b.title);
      return collator.compare(a.title, b.title);
    });
  }

  function renderTopics() {
    els.noteCount.textContent = notes.length.toLocaleString();
    els.topicCount.textContent = Math.max(0, categories().length - 1).toLocaleString();
    els.topicList.innerHTML = categories()
      .map(([name, count]) => `
        <button class="topic-button ${name === state.category ? "is-active" : ""}" type="button" data-topic="${escapeHtml(name)}">
          <span>${escapeHtml(name)}</span>
          <span>${count}</span>
        </button>
      `)
      .join("");
  }

  function renderList(items) {
    els.resultCount.textContent = `${items.length.toLocaleString()} result${items.length === 1 ? "" : "s"}`;
    els.noteList.innerHTML = items.map((note) => `
      <button class="note-card ${note.id === state.noteId ? "is-active" : ""}" type="button" data-note="${escapeHtml(note.id)}">
        <h3>${escapeHtml(note.title)}</h3>
        <div class="note-meta">
          <span>${escapeHtml(note.category)}</span>
          <span>${note.words.toLocaleString()} words</span>
          <span>${escapeHtml(note.type.toUpperCase())}</span>
        </div>
        <p>${escapeHtml(note.summary || note.path)}</p>
      </button>
    `).join("");
  }

  function renderMarkdown(text, type) {
    if (["sql", "scala"].includes(type)) {
      return `<pre><code>${escapeHtml(text)}</code></pre>`;
    }

    const lines = String(text || "").replace(/\r\n?/g, "\n").split("\n");
    const html = [];
    let inCode = false;
    let code = [];
    let list = null;
    let paragraph = [];

    function flushParagraph() {
      if (!paragraph.length) return;
      html.push(`<p>${inline(paragraph.join(" "))}</p>`);
      paragraph = [];
    }

    function flushList() {
      if (!list) return;
      html.push(`</${list}>`);
      list = null;
    }

    function openList(tag) {
      if (list !== tag) {
        flushList();
        html.push(`<${tag}>`);
        list = tag;
      }
    }

    for (const raw of lines) {
      const line = raw.replace(/\s+$/g, "");
      if (line.startsWith("```")) {
        if (inCode) {
          html.push(`<pre><code>${escapeHtml(code.join("\n"))}</code></pre>`);
          code = [];
          inCode = false;
        } else {
          flushParagraph();
          flushList();
          inCode = true;
        }
        continue;
      }
      if (inCode) {
        code.push(raw);
        continue;
      }
      if (!line.trim()) {
        flushParagraph();
        flushList();
        continue;
      }

      const heading = /^(#{1,4})\s+(.+)$/.exec(line);
      if (heading) {
        flushParagraph();
        flushList();
        const level = heading[1].length + 1;
        const textValue = heading[2].trim();
        html.push(`<h${level} id="${slug(textValue)}">${inline(textValue)}</h${level}>`);
        continue;
      }

      if (/^\s*[-*]\s+/.test(line)) {
        flushParagraph();
        openList("ul");
        html.push(`<li>${inline(line.replace(/^\s*[-*]\s+/, ""))}</li>`);
        continue;
      }

      if (/^\s*\d+[.)]\s+/.test(line)) {
        flushParagraph();
        openList("ol");
        html.push(`<li>${inline(line.replace(/^\s*\d+[.)]\s+/, ""))}</li>`);
        continue;
      }

      if (/^>\s?/.test(line)) {
        flushParagraph();
        flushList();
        html.push(`<blockquote>${inline(line.replace(/^>\s?/, ""))}</blockquote>`);
        continue;
      }

      paragraph.push(line);
    }

    if (inCode) html.push(`<pre><code>${escapeHtml(code.join("\n"))}</code></pre>`);
    flushParagraph();
    flushList();
    return html.join("\n");
  }

  function inline(value) {
    return escapeHtml(value)
      .replace(/`([^`]+)`/g, "<code>$1</code>")
      .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
      .replace(/\*([^*]+)\*/g, "<em>$1</em>")
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noreferrer">$1</a>');
  }

  function renderReader() {
    const note = notes.find((item) => item.id === state.noteId);
    if (!note) {
      els.reader.innerHTML = els.emptyState.outerHTML;
      return;
    }

    els.reader.innerHTML = `
      <header class="reader-header">
        <div>
          <p class="eyebrow">${escapeHtml(note.category)}</p>
          <h1>${escapeHtml(note.title)}</h1>
          <div class="path-line">${escapeHtml(note.path)} · ${note.words.toLocaleString()} words</div>
        </div>
      </header>
      <div class="reader-content">${renderMarkdown(note.content, note.type)}</div>
    `;
  }

  function updateViewButtons() {
    els.listViewButton.classList.toggle("is-active", state.view === "list");
    els.readViewButton.classList.toggle("is-active", state.view === "read");
    els.noteListPanel.classList.toggle("is-hidden", state.view === "read" && matchMedia("(max-width: 980px)").matches);
  }

  function render() {
    const items = filteredNotes();
    if (!items.some((item) => item.id === state.noteId) && items[0]) {
      state.noteId = items[0].id;
    }
    els.activeTitle.textContent = state.category === "All" ? "All notes" : state.category;
    renderTopics();
    renderList(items);
    renderReader();
    updateViewButtons();
    setRoute();
  }

  els.topicList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-topic]");
    if (!button) return;
    state.category = button.dataset.topic;
    state.view = "list";
    render();
  });

  els.noteList.addEventListener("click", (event) => {
    const button = event.target.closest("[data-note]");
    if (!button) return;
    state.noteId = button.dataset.note;
    state.view = "read";
    render();
    els.reader.focus({ preventScroll: true });
    els.reader.scrollIntoView({ behavior: "smooth", block: "start" });
  });

  els.searchInput.addEventListener("input", (event) => {
    state.query = event.target.value;
    render();
  });

  els.sortSelect.addEventListener("change", (event) => {
    state.sort = event.target.value;
    render();
  });

  els.listViewButton.addEventListener("click", () => {
    state.view = "list";
    render();
  });

  els.readViewButton.addEventListener("click", () => {
    state.view = "read";
    render();
  });

  els.themeToggle.addEventListener("click", () => {
    const dark = document.documentElement.dataset.theme !== "dark";
    document.documentElement.dataset.theme = dark ? "dark" : "light";
    localStorage.setItem("notes-theme", dark ? "dark" : "light");
  });

  addEventListener("hashchange", () => {
    hashRoute();
    render();
  });

  addEventListener("resize", updateViewButtons);

  document.documentElement.dataset.theme = localStorage.getItem("notes-theme") || "light";
  hashRoute();
  render();
}());
