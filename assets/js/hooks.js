import UserTimeZone from "./hooks/user-timezone";
let hooks = {}
hooks.UserTimeZone = UserTimeZone

hooks.Highlight = {
  mounted() {
    window.highlightAll(this.el)
  }
}

hooks.Editor = {
  mounted() {
    const el = this.el.querySelector("[data-mount]")

    import(/* webpackChunkName: "editor" */ "./editor").then(({default: loader}) => {
      let { editor } = loader(this, el);

      this.handleEvent("new-content", ({ new_content: newContent }) => {
        editor.setContent(newContent, true)
      })
    });
  }
};

export default hooks
