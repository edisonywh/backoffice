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
Hooks.Notification = {
  mounted() {
    let notification = document.querySelector("#bo-notification")
    this.handleEvent("bo-notification", ({ level, title, subtitle, redirect }) => {
      var event = new CustomEvent('bo-notification', {
        detail: {
          level: level,
          title: title,
          subtitle: subtitle,
        }
      });

      // FIXME: This is a workaround because `push_event` does not work with `push_redirect`,
      // so we implement a callback to allow client-side to initiate the redirect.
      if (redirect != null) {
        this.pushEvent("redirect", redirect)
      }

      notification.dispatchEvent(event);
    })
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

window.liveSocket = liveSocket;

window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())
