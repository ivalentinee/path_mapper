// KeyboardNav: thin key forwarder for keyboard navigation.
// Captures keydown, suppresses when in text inputs (except Escape),
// pushes raw key to server. All scope logic lives in Elixir.
//
// Uses a global singleton pattern: the listener is added once and
// references the latest hook instance. This survives LiveView DOM
// patches that might destroy/recreate the hook element.

let activeHook = null;

function globalKeyHandler(e) {
  if (!activeHook) return;
  const tag = document.activeElement?.tagName;
  if (tag === "INPUT" || tag === "TEXTAREA" || tag === "SELECT") {
    if (e.key !== "Escape") return;
  }
  if (["+", "-", "=", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight"].includes(e.key)) {
    e.preventDefault();
  }
  activeHook.pushEvent("keydown", { key: e.key });
}

// Register once globally
if (!window._keyboardNavRegistered) {
  window.addEventListener("keydown", globalKeyHandler);
  window._keyboardNavRegistered = true;
}

export const KeyboardNav = {
  mounted() {
    activeHook = this;
  },
  updated() {
    activeHook = this;
  },
  destroyed() {
    activeHook = null;
  }
};
