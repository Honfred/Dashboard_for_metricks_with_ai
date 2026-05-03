import { Controller } from "@hotwired/stimulus"

// Wraps any element and fires a "lazy-chart:visible" event when
// it scrolls into view (10% threshold). Other controllers or plain JS
// can listen for this event to defer expensive chart initialization.
//
// Usage:
//   <div data-controller="lazy-chart" data-action="lazy-chart:visible@window->my-chart#load">
//     <canvas data-my-chart-target="canvas"></canvas>
//   </div>
export default class extends Controller {
  connect() {
    this.observer = new IntersectionObserver(this.#onIntersect.bind(this), {
      threshold: 0.1
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #onIntersect(entries) {
    if (!entries[0].isIntersecting) return
    this.observer.disconnect()
    this.dispatch("visible", { bubbles: true, cancelable: false })
  }
}
