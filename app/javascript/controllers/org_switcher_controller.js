import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "select" ]

  change(event) {
    const organizationId = event.target.value
    if (organizationId) {
      Turbo.visit(`/organizations/${organizationId}/accounts`)
    }
  }
}