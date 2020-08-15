window.userTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;

export default {
  mounted() {
    const phoenix = this;
    const target = this.el.getAttribute('phx-target');
    const els = phoenix.el.querySelectorAll("input")
    for (let el of els) { el.value = window.userTimezone; }
    phoenix.pushEventTo(target, "timezone", window.userTimezone)
  }
}
