import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "button", "dropdown", "chevron", "option" ]

  connect() {
    // Close dropdown when clicking outside
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.handleClickOutside)
    
    // Close dropdown when pressing Escape
    this.handleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.handleEscape)
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutside)
    document.removeEventListener('keydown', this.handleEscape)
  }

  toggle() {
    const isOpen = this.dropdownTarget.classList.contains('org-switcher__dropdown--open')
    
    if (isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.dropdownTarget.classList.add('org-switcher__dropdown--open')
    this.buttonTarget.setAttribute('aria-expanded', 'true')
    this.chevronTarget.style.transform = 'rotate(180deg)'
  }

  close() {
    this.dropdownTarget.classList.remove('org-switcher__dropdown--open')
    this.buttonTarget.setAttribute('aria-expanded', 'false')
    this.chevronTarget.style.transform = 'rotate(0deg)'
  }

  select(event) {
    event.preventDefault()
    const organizationId = event.currentTarget.dataset.orgId
    if (organizationId) {
      Turbo.visit(`/organizations/${organizationId}/accounts`)
    }
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  handleEscape(event) {
    if (event.key === 'Escape') {
      this.close()
      this.buttonTarget.focus()
    }
  }
}