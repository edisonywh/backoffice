import css from "../css/app.scss"

import "phoenix_html"

import { Socket } from "phoenix"
import LiveSocket from "phoenix_live_view"
import NProgress from "nprogress"
import 'alpinejs'

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, { params: { _csrf_token: csrfToken } });
liveSocket.connect()

window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())
