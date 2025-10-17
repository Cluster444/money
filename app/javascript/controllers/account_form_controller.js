import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "kindSelect", "creditCardFields" ]
  static values = { 
    creditCardKind: { type: String, default: "credit_card" }
  }

  connect() {
    this.toggleCreditCardFields()
  }

  // Called when the account kind select changes
  kindChanged() {
    this.toggleCreditCardFields()
  }

  // Private methods

  toggleCreditCardFields() {
    if (this.isCreditCardSelected()) {
      this.showCreditCardFields()
    } else {
      this.hideCreditCardFields()
    }
  }

  isCreditCardSelected() {
    return this.kindSelectTarget.value === this.creditCardKindValue
  }

  showCreditCardFields() {
    this.creditCardFieldsTarget.style.display = "block"
  }

  hideCreditCardFields() {
    this.creditCardFieldsTarget.style.display = "none"
  }
}