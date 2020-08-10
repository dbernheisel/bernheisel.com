import { Socket } from "phoenix";
import LiveSocket from "phoenix_live_view";
import "phoenix_html";
import hooks from "./hooks";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

window.liveSocket = new LiveSocket("/live", Socket, {
  hooks,
  params: {
    _csrf_token: csrfToken
  },
  dom: {
    onBeforeElUpdated(from, to) {
      if(from.__x) window.Alpine.clone(from.__x, to)
    }
  }
});

window.liveSocket.connect();

