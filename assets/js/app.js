import css from "../css/app.scss"

import "phoenix_html"

import { Socket } from "phoenix"
import LiveSocket from "phoenix_live_view"
import NProgress from "nprogress"
import 'alpinejs'

const Hooks = {}
Hooks.BeforeUnload = {
  mounted() {
    var el = this.el
    this.beforeUnload = function (e) {
      if (el.dataset.changed === 'true') {
        e.preventDefault()
        e.returnValue = ''
      }
    }
    window.addEventListener('beforeunload', this.beforeUnload, true)
  },
  destroyed() {
    window.removeEventListener('beforeunload', this.beforeUnload, true)
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  dom: {
    onBeforeElUpdated(from, to) {
      if (from.__x) {
        window.Alpine.clone(from.__x, to);
      }
    },
  },
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});
liveSocket.connect()

window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())
