import Vue from "vue";
import { Editor } from 'tiptap'
import {
  Blockquote,
  CodeBlock,
  HardBreak,
  Heading,
  HorizontalRule,
  OrderedList,
  BulletList,
  ListItem,
  Bold,
  Image,
  Italic,
  Link,
  Strike,
  Underline,
  History,
  Collaboration
} from 'tiptap-extensions'
const EditorVue = () => import(/* webpackChunkName: "editorVue" */ "./Editor.vue");

export default function(phx, el) {
  const editor = new Editor({
    extensions: [
      new Blockquote(),
      new BulletList(),
      new CodeBlock(),
      new HardBreak(),
      new Heading({ levels: [1, 2, 3] }),
      new HorizontalRule(),
      new ListItem(),
      new OrderedList(),
      new Link({ openOnClick: false }),
      new Bold(),
      new Italic(),
      new Image(),
      new Strike(),
      new Underline(),
      new History(),
      new Collaboration({
        debounce: 250,
        version: el.dataset.initialVersion || 1,
        onSendable: ({ sendable }) => {
          phx.pushEvent("editor-update", sendable)
        }
      })
    ],
    content: el.dataset.initialValue || "",
  })

  const vueEditor = new Vue({
    el: el,
    render: createElement =>
      createElement(EditorVue, {
        props: { editor }
      })
  });

  return {editor, vueEditor}
}
