import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { url: String }

  connect() {
    this.timeout = null
  }

  check(event) {
    clearTimeout(this.timeout)
    const subdomain = event.target.value.trim()

    if (subdomain.length === 0) {
      this.messageTarget.innerHTML = ""
      return
    }

    this.timeout = setTimeout(() => {
      this.checkAvailability(subdomain)
    }, 300)
  }

  async checkAvailability(subdomain) {
    try {
      const response = await fetch(`${this.urlValue}?subdomain=${encodeURIComponent(subdomain)}`)
      const data = await response.json()

      if (data.available) {
        this.messageTarget.innerHTML = `<p class="text-sm text-green-600">✓ ${data.message}</p>`
      } else {
        this.messageTarget.innerHTML = `<p class="text-sm text-red-600">✗ ${data.message}</p>`
      }
    } catch (error) {
      this.messageTarget.innerHTML = `<p class="text-sm text-gray-500">Could not check availability</p>`
    }
  }
}
