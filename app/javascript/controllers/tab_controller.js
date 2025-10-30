import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content"]
  static values = { default: String }

  connect() {
    this.showTab(this.defaultValueValue || this.buttonTargets[0]?.dataset.tag)
  }

  switch(event) {
    const tag = event.currentTarget.dataset.tag
    this.showTab(tag)
  }

  showTab(tag) {
    // Update button states
    this.buttonTargets.forEach(button => {
      if (button.dataset.tag === tag) {
        button.setAttribute("data-active", "true")
        button.setAttribute("aria-selected", "true")
      } else {
        button.removeAttribute("data-active")
        button.setAttribute("aria-selected", "false")
      }
    })

    // Update content visibility
    this.contentTargets.forEach(content => {
      if (content.dataset.tag === tag) {
        content.classList.remove("hidden")
        content.classList.add("tab-panel__content")
        
        // Handle lazy loading if needed
        if (content.dataset.lazy === "true" && !content.dataset.loaded) {
          this.loadLazyContent(content)
        }
      } else {
        content.classList.add("hidden")
        content.classList.remove("tab-panel__content")
      }
    })
  }

  loadLazyContent(content) {
    // Mark as loaded to prevent duplicate requests
    content.dataset.loaded = "true"
    
    // Dispatch event for lazy loading
    this.dispatch("lazy-load", { 
      detail: { tag: content.dataset.tag, content } 
    })
  }
}