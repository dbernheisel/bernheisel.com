import UserTimeZone from "./hooks/user-timezone";
let hooks = {}
hooks.UserTimeZone = UserTimeZone

hooks.Highlight = {
  mounted() {
    window.highlightAll(this.el)
  }
}

hooks.CtrlEnterSubmit = {
  mounted() {
    const inputs = this.el.querySelectorAll("textarea,input")
    if (inputs.length) {
      inputs.forEach(ta => {
        ta.addEventListener("keydown", function(e) {
          if(e.keyCode == 13 && e.ctrlKey) {
            this.form.dispatchEvent(new Event("submit", { "bubbles": true }))
          }
        })
      })
    }
  }
}

export default hooks
