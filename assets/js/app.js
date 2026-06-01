// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
import "../css/app.css";
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";
import topbar from "../vendor/topbar";
import {Hooks} from './custom_hooks';

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let browserLocale = (navigator.language || "en").split("-")[0];
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken, locale: browserLocale},
  hooks: Hooks,
  metadata: {
    click: (e, el) => ({
      altKey: e.altKey,
	  ctrlKey: e.ctrlKey,
    })
  },
});

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"});
window.addEventListener("phx:page-loading-start", _info => topbar.show(300));
window.addEventListener("phx:page-loading-stop", _info => topbar.hide());

// Set locale cookie when language is changed
window.addEventListener("phx:set_locale", (e) => {
  const locale = e.detail.locale;
  document.cookie = `locale=${locale}; path=/; max-age=${365 * 24 * 60 * 60}`;
  window.location.reload();
});

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;

function dragstartHandler(event) {
  event.dataTransfer.effectAllowed = "move";
}
