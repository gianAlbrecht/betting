import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
})

liveSocket.connect()
window.liveSocket = liveSocket

const SIDEBAR_KEY = "bet-sidebar"

function initSidebar() {
  const sidebar = document.getElementById("sidebar")
  if (!sidebar) return

  if (window.matchMedia("(min-width: 1024px)").matches) {
    if (localStorage.getItem(SIDEBAR_KEY) === "collapsed") {
      sidebar.classList.add("collapsed")
    }
  }

  const path = window.location.pathname
  document.querySelectorAll("nav a[href]").forEach(link => {
    const linkPath = new URL(link.href, window.location.origin).pathname
    if (linkPath === path) {
      link.classList.add("nav-active")
    } else {
      link.classList.remove("nav-active")
    }
  })
}

window.sidebarToggle = function () {
  const sidebar = document.getElementById("sidebar")
  if (!sidebar) return

  if (window.matchMedia("(min-width: 1024px)").matches) {
    sidebar.classList.toggle("collapsed")
    localStorage.setItem(
      SIDEBAR_KEY,
      sidebar.classList.contains("collapsed") ? "collapsed" : "expanded"
    )
  } else {
    window.sidebarOpen()
  }
}

window.sidebarOpen = function () {
  const sidebar = document.getElementById("sidebar")
  const backdrop = document.getElementById("sidebar-backdrop")
  if (!sidebar || !backdrop) return
  sidebar.classList.add("mobile-open")
  backdrop.classList.remove("hidden")
  document.body.style.overflow = "hidden"
}

window.sidebarClose = function () {
  const sidebar = document.getElementById("sidebar")
  const backdrop = document.getElementById("sidebar-backdrop")
  if (!sidebar || !backdrop) return
  sidebar.classList.remove("mobile-open")
  backdrop.classList.add("hidden")
  document.body.style.overflow = ""
}

document.addEventListener("DOMContentLoaded", initSidebar)
document.addEventListener("phx:page-loading-stop", initSidebar)
