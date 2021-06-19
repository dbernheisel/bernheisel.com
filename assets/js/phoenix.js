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
      if(from.nodeType === 1 && from._x_dataStack) {
        window.Alpine.clone(from, to)
      }
    }
  }
});

window.liveSocket.connect();

