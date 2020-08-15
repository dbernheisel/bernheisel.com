import UserTimeZone from "./hooks/user-timezone";
let hooks = {}
hooks.UserTimeZone = UserTimeZone
hooks.Highlight = {
  mounted() {
    window.highlightAll()
  }
}

export default hooks
