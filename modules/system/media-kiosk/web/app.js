const els = {
  clock: document.getElementById("clock"),
  date: document.getElementById("date"),
  desktopPill: document.getElementById("desktop-pill"),
  desktopDot: document.getElementById("desktop-dot"),
  desktopLabel: document.getElementById("desktop-label"),
  homeView: document.getElementById("home-view"),
  appView: document.getElementById("app-view"),
  appTitle: document.getElementById("app-title"),
  jellyfinCard: document.getElementById("jellyfin-card"),
  jellyfinPreview: document.getElementById("jellyfin-preview"),
  jellyfinKicker: document.getElementById("jellyfin-kicker"),
  jellyfinTitle: document.getElementById("jellyfin-title"),
  jellyfinSubtitle: document.getElementById("jellyfin-subtitle"),
  jellyfinProgress: document.getElementById("jellyfin-progress"),
  immichCard: document.getElementById("immich-card"),
  immichPreview: document.getElementById("immich-preview"),
  immichTitle: document.getElementById("immich-title"),
  immichSubtitle: document.getElementById("immich-subtitle"),
  cinejoyCard: document.getElementById("cinejoy-card"),
  moonlightCard: document.getElementById("moonlight-card"),
  moonlightSubtitle: document.getElementById("moonlight-subtitle"),
  moonlightUiCard: document.getElementById("moonlight-ui-card"),
  homeButton: document.getElementById("home-button"),
  openWindowButton: document.getElementById("open-window-button"),
  frameJellyfin: document.getElementById("frame-jellyfin"),
  frameImmich: document.getElementById("frame-immich"),
  frameLoading: document.getElementById("frame-loading"),
  audioOutputs: document.getElementById("audio-outputs"),
  closeAppsButton: document.getElementById("close-apps-button"),
  exitButton: document.getElementById("exit-button"),
  actionDialog: document.getElementById("action-dialog"),
  actionKicker: document.getElementById("action-kicker"),
  actionTitle: document.getElementById("action-title"),
  actionStatus: document.getElementById("action-status"),
  actionCancel: document.getElementById("action-cancel"),
  confirmDialog: document.getElementById("confirm-dialog"),
  confirmExit: document.getElementById("confirm-exit"),
  toast: document.getElementById("toast"),
};

const AUDIO_LABELS = {
  flip6: "JBL Flip 6",
  xgo: "XGO",
  xm4: "WH-1000XM4",
  hdmi: "Projector",
};

const state = {
  config: null,
  highlights: null,
  audio: null,
  audioBusy: false,
  desktop: null,
  app: null,
  action: null,
  lastCard: null,
  lastFocus: null,
  toastTimer: null,
  padLast: 0,
  padA: false,
  padB: false,
};

async function api(path, options = {}) {
  const init = {
    method: options.method || "GET",
    cache: "no-store",
    headers: { "X-Kiosk-Request": "1" },
  };
  if (options.body !== undefined) {
    init.headers["Content-Type"] = "application/json";
    init.body = JSON.stringify(options.body);
  }
  const response = await fetch(path, init);
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(data.error || `Request failed (${response.status})`);
  }
  return data;
}

/* Immich authenticates its web UI with host cookies. The API logs in with the
 * sops credentials and answers with the same Set-Cookie values a manual login
 * sets; cookies ignore ports, so the kiosk origin sets them for the Immich
 * origin on 127.0.0.1. The panel must not load before they exist, or Immich
 * renders a login form and never retries. */
let immichSession = null;

function primeImmichSession() {
  if (!immichSession) {
    immichSession = api("/api/session/immich", { method: "POST" }).catch((error) => {
      immichSession = null;
      throw error;
    });
  }
  return immichSession;
}

function toast(message, isError = false) {
  els.toast.textContent = message;
  els.toast.classList.toggle("is-error", isError);
  els.toast.hidden = false;
  clearTimeout(state.toastTimer);
  state.toastTimer = setTimeout(() => {
    els.toast.hidden = true;
  }, 4200);
}

function isVisible(element) {
  return Boolean(
    element &&
      !element.disabled &&
      element.getClientRects().length &&
      element.offsetParent !== null,
  );
}

/* Clock */

function updateClock() {
  const now = new Date();
  els.clock.textContent = new Intl.DateTimeFormat(undefined, {
    hour: "2-digit",
    minute: "2-digit",
  }).format(now);
  els.date.textContent = new Intl.DateTimeFormat(undefined, {
    weekday: "long",
    day: "numeric",
    month: "long",
  }).format(now);
}

/* Data loaders */

async function loadConfig() {
  try {
    state.config = await api("/api/config");
    loadHighlights();
    loadAudio();
    loadDesktop();
  } catch (error) {
    toast("Kiosk API unavailable; retrying…", true);
    setTimeout(loadConfig, 5000);
  }
}

function applyJellyfin(meta) {
  if (!meta) {
    els.jellyfinCard.classList.add("is-broken");
    els.jellyfinKicker.textContent = "Jellyfin";
    els.jellyfinTitle.textContent = "Jellyfin";
    els.jellyfinSubtitle.textContent = "Movies & shows";
    els.jellyfinProgress.style.width = "0%";
    return;
  }

  els.jellyfinKicker.textContent = meta.online ? "Continue watching" : "Jellyfin offline";
  els.jellyfinTitle.textContent = meta.title || "Jellyfin";
  els.jellyfinSubtitle.textContent = meta.subtitle || "Movies & shows";
  const progress = Math.max(0, Math.min(100, Number(meta.progress) || 0));
  els.jellyfinProgress.style.width = `${progress}%`;

  const source = `/api/preview/jellyfin?v=${meta.updated || Date.now()}`;
  if (els.jellyfinPreview.dataset.src !== source) {
    els.jellyfinPreview.dataset.src = source;
    els.jellyfinPreview.src = source;
  }
}

function applyImmich(meta) {
  if (!meta) {
    els.immichCard.classList.add("is-broken");
    els.immichTitle.textContent = "Immich";
    els.immichSubtitle.textContent = "Photo library";
    return;
  }

  els.immichTitle.textContent = meta.title || "Immich";
  els.immichSubtitle.textContent = meta.online
    ? meta.subtitle || "Recent photo"
    : "Immich offline";
  const source = `/api/preview/immich?v=${meta.updated || Date.now()}`;
  if (els.immichPreview.dataset.src !== source) {
    els.immichPreview.dataset.src = source;
    els.immichPreview.src = source;
  }
}

async function loadHighlights() {
  try {
    state.highlights = await api("/api/highlights");
    applyJellyfin(state.highlights.jellyfin);
    applyImmich(state.highlights.immich);
  } catch {
    // Keep the last known previews; the API/logs tell the operator why.
  }
}

function renderAudio() {
  const data = state.audio;
  els.audioOutputs.replaceChildren();

  if (!data || !data.available) {
    const hint = document.createElement("span");
    hint.className = "audio-hint";
    hint.textContent = "Audio hub offline";
    els.audioOutputs.append(hint);
    return;
  }

  const status = data.status || {};
  let outputs = status.outputs || [];
  if (!Array.isArray(outputs)) {
    outputs = Object.entries(outputs).map(([id, value]) =>
      typeof value === "object" ? { id, ...value } : { id, label: value },
    );
  }
  outputs = outputs.map((output) =>
    typeof output === "string" ? { id: output } : output,
  );
  if (!outputs.length) {
    outputs = Object.keys(AUDIO_LABELS).map((id) => ({ id, label: AUDIO_LABELS[id] }));
  }

  const current = status.current || status.default || status.output || null;

  for (const output of outputs) {
    const id = output.id || output.name;
    if (!id) continue;
    const button = document.createElement("button");
    button.className = "audio-output";
    button.type = "button";
    button.dataset.output = id;
    button.disabled = state.audioBusy;
    if (id === current) {
      button.classList.add("is-current");
      button.setAttribute("aria-pressed", "true");
    } else {
      button.setAttribute("aria-pressed", "false");
    }

    const dot = document.createElement("span");
    dot.className = "dot";
    const label = document.createElement("span");
    label.textContent = output.label || output.name || AUDIO_LABELS[id] || id;

    button.append(dot, label);
    button.addEventListener("click", () => setAudio(id));
    els.audioOutputs.append(button);
  }
}

async function loadAudio() {
  try {
    state.audio = await api("/api/audio");
  } catch {
    state.audio = { available: false };
  }
  renderAudio();
}

async function setAudio(id) {
  if (state.audioBusy) return;
  state.audioBusy = true;
  renderAudio();
  try {
    await api(`/api/audio/output/${encodeURIComponent(id)}`, {
      method: "POST",
      body: {},
    });
    toast(`Audio: ${AUDIO_LABELS[id] || id}`);
  } catch (error) {
    toast(error.message, true);
  } finally {
    state.audioBusy = false;
    await loadAudio();
  }
}

async function loadDesktop() {
  try {
    state.desktop = await api("/api/desktop");
  } catch {
    state.desktop = { up: false };
  }
  const up = Boolean(state.desktop.up);
  els.desktopDot.className = `dot ${up ? "dot-on" : "dot-off"}`;
  els.desktopLabel.textContent = up ? "Desktop online" : "Desktop offline";
  els.moonlightSubtitle.textContent = up
    ? "Desktop online · stream now"
    : "Wake desktop & stream";
}

/* Views */

function showApp(name, resume = false) {
  if (!state.config) {
    toast("Kiosk API is still starting…", true);
    return;
  }

  state.app = name;
  els.homeView.hidden = true;
  els.appView.hidden = false;
  els.appTitle.textContent = name === "jellyfin" ? "Jellyfin" : "Immich";

  const frame = name === "jellyfin" ? els.frameJellyfin : els.frameImmich;
  els.frameJellyfin.hidden = name !== "jellyfin";
  els.frameImmich.hidden = name !== "immich";

  let source =
    name === "jellyfin" ? state.config.jellyfin.webUrl : state.config.immich.webUrl;
  if (name === "jellyfin" && resume) {
    const itemId = state.highlights?.jellyfin?.itemId;
    if (itemId) {
      source += `index.html#!/details?id=${encodeURIComponent(itemId)}`;
    }
  }

  const load = () => {
    if (frame.dataset.src !== source) {
      frame.dataset.src = source;
      els.frameLoading.hidden = false;
      frame.src = source;
    } else {
      els.frameLoading.hidden = true;
    }
  };

  if (name === "immich") {
    primeImmichSession().then(load, (error) => {
      toast(error.message, true);
      load();
    });
  } else {
    load();
  }

  setTimeout(() => frame.focus(), 60);
}

function goHome() {
  if (!state.app) return;
  state.app = null;
  els.appView.hidden = true;
  els.homeView.hidden = false;
  const target =
    state.lastCard && isVisible(state.lastCard) ? state.lastCard : els.jellyfinCard;
  target.focus();
}

async function openApp(name) {
  state.lastCard = els[name === "jellyfin" ? "jellyfinCard" : name === "immich" ? "immichCard" : "cinejoyCard"];

  if (name === "jellyfin" || name === "immich") {
    showApp(name, name === "jellyfin");
    return;
  }

  try {
    await api("/api/open", { method: "POST", body: { target: name } });
    toast("Opening Cinejoy…");
  } catch (error) {
    toast(error.message, true);
  }
}

async function openWindow() {
  if (!state.app) return;
  try {
    await api("/api/open", { method: "POST", body: { target: state.app } });
    toast("Opening in a window…");
  } catch (error) {
    toast(error.message, true);
  }
}

async function closeApps() {
  try {
    const result = await api("/api/close-apps", { method: "POST", body: {} });
    if (result.closed) {
      toast(`Closed ${result.closed} app window${result.closed === 1 ? "" : "s"}`);
    } else {
      toast("No app window was open");
    }
  } catch (error) {
    toast(error.message, true);
  }
}

/* Moonlight actions */

const ACTION_TITLES = {
  starting: "Preparing the desktop…",
  waking: "Waking the desktop…",
  waiting: "Waiting for Moonlight…",
  launching: "Starting Moonlight…",
  streaming: "Streaming",
  cancelling: "Cancelling…",
  cancelled: "Cancelled",
  done: "Stream ended",
  error: "Could not start the stream",
};

async function startAction(kind) {
  if (state.action) {
    toast("An action is already running");
    return;
  }

  try {
    const result = await api(`/api/moonlight/${kind}`, {
      method: "POST",
      body: {},
    });
    state.action = { id: result.id };
    els.actionKicker.textContent = kind === "steam" ? "Steam stream" : "Moonlight library";
    els.actionTitle.textContent = ACTION_TITLES.starting;
    els.actionStatus.textContent = "This can take a minute after the desktop was powered off.";
    els.actionCancel.textContent = "Cancel";
    if (!els.actionDialog.open) els.actionDialog.showModal();
    pollAction();
  } catch (error) {
    toast(error.message, true);
  }
}

function updateActionDialog(data) {
  els.actionTitle.textContent = ACTION_TITLES[data.state] || "Moonlight";
  els.actionStatus.textContent = data.error
    ? `${data.message}\n\n${data.error}`
    : data.message;
  if (["done", "error", "cancelled"].includes(data.state)) {
    els.actionCancel.textContent = "Close";
  }
}

async function pollAction() {
  const action = state.action;
  if (!action) return;

  try {
    const data = await api(`/api/action/${action.id}`);
    if (state.action !== action) return;
    updateActionDialog(data);

    if (["done", "error", "cancelled"].includes(data.state)) {
      state.action = null;
      if (!els.actionDialog.open) {
        toast(
          data.state === "error" ? data.message : data.state === "done" ? "Stream ended" : "Cancelled",
          data.state === "error",
        );
      }
      return;
    }
  } catch (error) {
    els.actionStatus.textContent = error.message;
  }

  if (state.action === action) {
    setTimeout(pollAction, 1000);
  }
}

async function cancelAction() {
  const action = state.action;
  if (!action) return;
  state.action = null;
  try {
    await api(`/api/action/${action.id}/cancel`, { method: "POST", body: {} });
    toast("Action cancelled");
  } catch (error) {
    toast(error.message, true);
  }
}

async function exitKiosk() {
  try {
    await api("/api/exit", { method: "POST", body: {} });
    toast("Closing kiosk…");
  } catch (error) {
    toast(error.message, true);
  }
}

/* Focus navigation */

function moveFocus(dx, dy) {
  const controls = [...document.querySelectorAll("button:not([disabled])")].filter(isVisible);
  if (!controls.length) return;

  const active = document.activeElement;
  if (!controls.includes(active)) {
    controls[0].focus();
    return;
  }

  const origin = active.getBoundingClientRect();
  const originX = origin.left + origin.width / 2;
  const originY = origin.top + origin.height / 2;

  let best = null;
  let bestScore = Infinity;

  for (const control of controls) {
    if (control === active) continue;
    const rect = control.getBoundingClientRect();
    const x = rect.left + rect.width / 2;
    const y = rect.top + rect.height / 2;
    const deltaX = x - originX;
    const deltaY = y - originY;
    const primary = dx ? deltaX * dx : deltaY * dy;
    const secondary = dx ? Math.abs(deltaY) : Math.abs(deltaX);

    if (primary <= 8) continue;
    const score = primary + secondary * 1.7;
    if (score < bestScore) {
      bestScore = score;
      best = control;
    }
  }

  if (best) best.focus();
}

function handleKeydown(event) {
  if (event.altKey || event.ctrlKey || event.metaKey) return;
  if (document.querySelector("dialog[open]")) return;

  const directions = {
    ArrowLeft: [-1, 0],
    ArrowRight: [1, 0],
    ArrowUp: [0, -1],
    ArrowDown: [0, 1],
  };

  const direction = directions[event.key];
  if (direction) {
    event.preventDefault();
    moveFocus(...direction);
    return;
  }

  if (event.key === "Escape" && state.app) {
    event.preventDefault();
    goHome();
  }
}

/* Gamepad: the 2026 Steam Controller only appears here on a kernel that
 * exposes hid-steam (7.3+). On the m920q's ZFS-supported 6.18 line the
 * firmware's lizard mode delivers arrow/Enter/Escape and pointer events
 * instead, which the keyboard/mouse handlers above already cover. */
function pollGamepad() {
  const pads = navigator.getGamepads ? navigator.getGamepads() : [];
  const pad = [...pads].find((entry) => entry && entry.connected);
  if (!pad) return;

  const now = performance.now();
  const pressed = (index) => Boolean(pad.buttons[index]?.pressed);
  const dialogOpen = Boolean(document.querySelector("dialog[open]"));

  let dx = 0;
  let dy = 0;
  if (pressed(12) || pad.axes[1] < -0.6) dy = -1;
  if (pressed(13) || pad.axes[1] > 0.6) dy = 1;
  if (pressed(14) || pad.axes[0] < -0.6) dx = -1;
  if (pressed(15) || pad.axes[0] > 0.6) dx = 1;

  if (!dialogOpen && (dx || dy) && now - state.padLast > 150) {
    state.padLast = now;
    moveFocus(dx, dy);
  }

  const a = pressed(0);
  if (!dialogOpen && a && !state.padA && document.activeElement instanceof HTMLElement) {
    document.activeElement.click();
  }
  state.padA = a;

  const b = pressed(1);
  if (b && !state.padB) {
    if (els.actionDialog.open) {
      els.actionCancel.click();
    } else if (els.confirmDialog.open) {
      els.confirmDialog.close("cancel");
    } else if (state.app) {
      goHome();
    }
  }
  state.padB = b;
}

/* Wiring */

function wire() {
  els.jellyfinCard.addEventListener("click", () => openApp("jellyfin"));
  els.immichCard.addEventListener("click", () => openApp("immich"));
  els.cinejoyCard.addEventListener("click", () => openApp("cinejoy"));
  els.moonlightCard.addEventListener("click", () => startAction("steam"));
  els.moonlightUiCard.addEventListener("click", () => startAction("ui"));

  els.homeButton.addEventListener("click", goHome);
  els.openWindowButton.addEventListener("click", openWindow);
  els.closeAppsButton.addEventListener("click", closeApps);
  els.exitButton.addEventListener("click", () => {
    els.confirmDialog.returnValue = "";
    els.confirmDialog.showModal();
  });

  els.actionCancel.addEventListener("click", () => {
    if (state.action) cancelAction();
  });
  els.actionDialog.addEventListener("cancel", (event) => {
    event.preventDefault();
    if (state.action) cancelAction();
    els.actionDialog.close();
  });

  els.confirmExit.addEventListener("click", (event) => {
    event.preventDefault();
    els.confirmDialog.close("exit");
  });
  els.confirmDialog.addEventListener("close", () => {
    if (els.confirmDialog.returnValue === "exit") exitKiosk();
  });

  els.jellyfinPreview.addEventListener("load", () => {
    els.jellyfinCard.classList.remove("is-broken");
  });
  els.jellyfinPreview.addEventListener("error", () => {
    els.jellyfinCard.classList.add("is-broken");
  });
  els.immichPreview.addEventListener("load", () => {
    els.immichCard.classList.remove("is-broken");
  });
  els.immichPreview.addEventListener("error", () => {
    els.immichCard.classList.add("is-broken");
  });

  const frameLoaded = (name) => {
    if (state.app === name) {
      els.frameLoading.hidden = true;
      (name === "jellyfin" ? els.frameJellyfin : els.frameImmich).focus();
    }
  };
  els.frameJellyfin.addEventListener("load", () => frameLoaded("jellyfin"));
  els.frameImmich.addEventListener("load", () => frameLoaded("immich"));

  document.addEventListener("keydown", handleKeydown);

  document.addEventListener("focusin", (event) => {
    if (event.target instanceof HTMLElement) {
      state.lastFocus = event.target;
    }
  });

  window.addEventListener("focus", () => {
    if (document.querySelector("dialog[open]")) return;
    if (state.app) {
      els.homeButton.focus();
      return;
    }
    const target =
      state.lastFocus && isVisible(state.lastFocus) ? state.lastFocus : els.jellyfinCard;
    target.focus();
  });

  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState !== "visible") return;
    loadHighlights();
    loadAudio();
    loadDesktop();
  });
}

function boot() {
  updateClock();
  setInterval(updateClock, 1000);
  wire();

  loadConfig();
  loadHighlights();
  loadAudio();
  loadDesktop();
  primeImmichSession().catch(() => {});

  setInterval(loadHighlights, 20000);
  setInterval(loadAudio, 20000);
  setInterval(loadDesktop, 30000);
  setInterval(pollGamepad, 60);

  els.jellyfinCard.focus();
}

boot();
