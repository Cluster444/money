import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["message", "countdown"];
  static values = { timeout: { type: Number, default: 5000 } };

  connect() {
    this.hideAfterTimeout();
    this.startCountdown();
  }

  dismiss() {
    this.element.style.transition = "opacity 0.3s ease-out";
    this.element.style.opacity = "0";
    setTimeout(() => {
      this.element.remove();
    }, 300);
  }

  hideAfterTimeout() {
    setTimeout(() => {
      this.dismiss();
    }, this.timeoutValue);
  }

  startCountdown() {
    const duration = this.timeoutValue / 1000; // Convert to seconds
    let remaining = duration;
    
    const updateCountdown = () => {
      if (this.hasCountdownTarget) {
        this.countdownTarget.textContent = remaining;
      }
      remaining--;
      
      if (remaining >= 0) {
        setTimeout(updateCountdown, 1000);
      }
    };
    
    updateCountdown();
  }
}