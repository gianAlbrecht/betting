import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"

// Grab the CSRF token injected by Phoenix into the page <head> and pass it
// to LiveSocket so every WebSocket message is authenticated server-side.
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken }
})

liveSocket.connect()
window.liveSocket = liveSocket

// localStorage key used to persist the sidebar collapsed/expanded state across
// page loads and sessions. Only the desktop state is persisted — on mobile the
// drawer always starts closed.
const SIDEBAR_KEY = "bet-sidebar"

// Called on initial page load and after every LiveView navigation. Restores
// the sidebar's collapsed state from localStorage (desktop only) and marks the
// link whose pathname matches the current URL as active so the user always
// knows where they are.
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

// Desktop: toggles the sidebar between full-width (15rem) and icon-only (3.5rem)
// and saves the new state to localStorage. On mobile this is a no-op — use
// sidebarOpen() instead, which opens the overlay drawer.
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

// Mobile: slides the sidebar drawer in from the left and shows the backdrop.
// Body scroll is locked while the drawer is open so content underneath stays still.
window.sidebarOpen = function () {
  const sidebar = document.getElementById("sidebar")
  const backdrop = document.getElementById("sidebar-backdrop")
  if (!sidebar || !backdrop) return
  sidebar.classList.add("mobile-open")
  backdrop.classList.remove("hidden")
  document.body.style.overflow = "hidden"
}

// Mobile: slides the drawer back off-screen and removes the backdrop.
// Tapping the backdrop also calls this (onclick on the backdrop element).
window.sidebarClose = function () {
  const sidebar = document.getElementById("sidebar")
  const backdrop = document.getElementById("sidebar-backdrop")
  if (!sidebar || !backdrop) return
  sidebar.classList.remove("mobile-open")
  backdrop.classList.add("hidden")
  document.body.style.overflow = ""
}

// Run on hard page load and after every LiveView soft-navigation so the active
// link highlight and collapsed state are always correct.
document.addEventListener("DOMContentLoaded", initSidebar)
document.addEventListener("phx:page-loading-stop", initSidebar)
