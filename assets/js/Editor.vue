<template>
  <div class="block w-full form-input editor">
    <editor-menu-bar :editor="editor" v-slot="{ commands, getMarkAttrs, isActive }">
      <div class="editor__menubar">
        <button
          :title="`Bold (${mod}+b)`"
          class="menubar__button"
          :class="{ 'is-active': isActive.bold() }"
          @click="commands.bold"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <path fill="none" stroke-width="2" stroke="currentColor" d="M5,4H9.5A2.5,2.5,0,0,1,12,6.5v0A2.5,2.5,0,0,1,9.5,9H5A0,0,0,0,1,5,9V4A0,0,0,0,1,5,4Z"></path>
            <path fill="none" stroke-width="2" stroke="currentColor" d="M5,9h5.5A2.5,2.5,0,0,1,13,11.5v0A2.5,2.5,0,0,1,10.5,14H5a0,0,0,0,1,0,0V9A0,0,0,0,1,5,9Z"></path>
          </svg>
        </button>

        <button
          :title="`Italic (${mod}+i)`"
          class="menubar__button"
          :class="{ 'is-active': isActive.italic() }"
          @click="commands.italic"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <line class="ql-stroke" x1="7" x2="13" y1="4" y2="4"></line>
            <line class="ql-stroke" x1="5" x2="11" y1="14" y2="14"></line>
            <line class="ql-stroke" x1="8" x2="10" y1="14" y2="4"></line>
          </svg>
        </button>

        <button
          :title="`Strikethrough (${mod}+d)`"
          class="menubar__button"
          :class="{ 'is-active': isActive.strike() }"
          @click="commands.strike"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <line class="ql-stroke ql-thin" x1="15.5" x2="2.5" y1="8.5" y2="9.5"></line>
            <path class="ql-fill" d="M9.007,8C6.542,7.791,6,7.519,6,6.5,6,5.792,7.283,5,9,5c1.571,0,2.765.679,2.969,1.309a1,1,0,0,0,1.9-.617C13.356,4.106,11.354,3,9,3,6.2,3,4,4.538,4,6.5a3.2,3.2,0,0,0,.5,1.843Z"></path>
            <path class="ql-fill" d="M8.984,10C11.457,10.208,12,10.479,12,11.5c0,0.708-1.283,1.5-3,1.5-1.571,0-2.765-.679-2.969-1.309a1,1,0,1,0-1.9.617C4.644,13.894,6.646,15,9,15c2.8,0,5-1.538,5-3.5a3.2,3.2,0,0,0-.5-1.843Z"></path>
          </svg>
        </button>

        <button
          :title="`Underline (${mod}+u)`"
          class="pr-2 border-r-2 border-gray-100 menubar__button"
          :class="{ 'is-active': isActive.underline() }"
          @click="commands.underline"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <path class="ql-stroke" d="M5,3V9a4.012,4.012,0,0,0,4,4H9a4.012,4.012,0,0,0,4-4V3"></path>
            <rect class="ql-fill" height="1" rx="0.5" ry="0.5" width="12" x="3" y="15"></rect>
          </svg>
        </button>

        <button
          title="Heading 1 (ctrl+shift+1)"
          class="menubar__button"
          :class="{ 'is-active': isActive.heading({ level: 1 }) }"
          @click="commands.heading({ level: 1 })"
          type="button"
        >
          <svg class="w-4 h-4" viewBox="0 0 18 18">
            <path class="ql-fill" d="M10,4V14a1,1,0,0,1-2,0V10H3v4a1,1,0,0,1-2,0V4A1,1,0,0,1,3,4V8H8V4a1,1,0,0,1,2,0Zm6.06787,9.209H14.98975V7.59863a.54085.54085,0,0,0-.605-.60547h-.62744a1.01119,1.01119,0,0,0-.748.29688L11.645,8.56641a.5435.5435,0,0,0-.022.8584l.28613.30762a.53861.53861,0,0,0,.84717.0332l.09912-.08789a1.2137,1.2137,0,0,0,.2417-.35254h.02246s-.01123.30859-.01123.60547V13.209H12.041a.54085.54085,0,0,0-.605.60547v.43945a.54085.54085,0,0,0,.605.60547h4.02686a.54085.54085,0,0,0,.605-.60547v-.43945A.54085.54085,0,0,0,16.06787,13.209Z"/>
          </svg>
        </button>

        <button
          title="Heading 2 (ctrl+shift+2)"
          class="menubar__button"
          :class="{ 'is-active': isActive.heading({ level: 2 }) }"
          @click="commands.heading({ level: 2 })"
          type="button"
        >
          <svg class="w-4 h-4" viewBox="0 0 18 18">
            <path class="ql-fill" d="M16.73975,13.81445v.43945a.54085.54085,0,0,1-.605.60547H11.855a.58392.58392,0,0,1-.64893-.60547V14.0127c0-2.90527,3.39941-3.42187,3.39941-4.55469a.77675.77675,0,0,0-.84717-.78125,1.17684,1.17684,0,0,0-.83594.38477c-.2749.26367-.561.374-.85791.13184l-.4292-.34082c-.30811-.24219-.38525-.51758-.1543-.81445a2.97155,2.97155,0,0,1,2.45361-1.17676,2.45393,2.45393,0,0,1,2.68408,2.40918c0,2.45312-3.1792,2.92676-3.27832,3.93848h2.79443A.54085.54085,0,0,1,16.73975,13.81445ZM9,3A.99974.99974,0,0,0,8,4V8H3V4A1,1,0,0,0,1,4V14a1,1,0,0,0,2,0V10H8v4a1,1,0,0,0,2,0V4A.99974.99974,0,0,0,9,3Z"/>
          </svg>
        </button>

        <button
          title="Heading 3 (ctrl+shift+3)"
          class="pr-2 border-r-2 border-gray-100 menubar__button"
          :class="{ 'is-active': isActive.heading({ level: 3 }) }"
          @click="commands.heading({ level: 3 })"
          type="button"
        >
          <svg class="w-4 h-4" viewBox="0 0 18 18">
            <path class="ql-fill" d="M16.65186,12.30664a2.6742,2.6742,0,0,1-2.915,2.68457,3.96592,3.96592,0,0,1-2.25537-.6709.56007.56007,0,0,1-.13232-.83594L11.64648,13c.209-.34082.48389-.36328.82471-.1543a2.32654,2.32654,0,0,0,1.12256.33008c.71484,0,1.12207-.35156,1.12207-.78125,0-.61523-.61621-.86816-1.46338-.86816H13.2085a.65159.65159,0,0,1-.68213-.41895l-.05518-.10937a.67114.67114,0,0,1,.14307-.78125l.71533-.86914a8.55289,8.55289,0,0,1,.68213-.7373V8.58887a3.93913,3.93913,0,0,1-.748.05469H11.9873a.54085.54085,0,0,1-.605-.60547V7.59863a.54085.54085,0,0,1,.605-.60547h3.75146a.53773.53773,0,0,1,.60547.59375v.17676a1.03723,1.03723,0,0,1-.27539.748L14.74854,10.0293A2.31132,2.31132,0,0,1,16.65186,12.30664ZM9,3A.99974.99974,0,0,0,8,4V8H3V4A1,1,0,0,0,1,4V14a1,1,0,0,0,2,0V10H8v4a1,1,0,0,0,2,0V4A.99974.99974,0,0,0,9,3Z"/>
          </svg>
        </button>

        <button
          title="Bullet List (ctrl+shift+8)"
          class="menubar__button"
          :class="{ 'is-active': isActive.bullet_list() }"
          @click="commands.bullet_list"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <line class="ql-stroke" x1="6" x2="15" y1="4" y2="4"></line>
            <line class="ql-stroke" x1="6" x2="15" y1="9" y2="9"></line>
            <line class="ql-stroke" x1="6" x2="15" y1="14" y2="14"></line>
            <line class="ql-stroke" x1="3" x2="3" y1="4" y2="4"></line>
            <line class="ql-stroke" x1="3" x2="3" y1="9" y2="9"></line>
            <line class="ql-stroke" x1="3" x2="3" y1="14" y2="14"></line>
          </svg>
        </button>

        <button
          title="Ordered List (ctrl+shift+9)"
          class="menubar__button"
          :class="{ 'is-active': isActive.ordered_list() }"
          @click="commands.ordered_list"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <line class="ql-stroke" x1="7" x2="15" y1="4" y2="4"></line>
            <line class="ql-stroke" x1="7" x2="15" y1="9" y2="9"></line>
            <line class="ql-stroke" x1="7" x2="15" y1="14" y2="14"></line>
            <line class="ql-stroke ql-thin" x1="2.5" x2="4.5" y1="5.5" y2="5.5"></line>
            <path class="ql-fill" d="M3.5,6A0.5,0.5,0,0,1,3,5.5V3.085l-0.276.138A0.5,0.5,0,0,1,2.053,3c-0.124-.247-0.023-0.324.224-0.447l1-.5A0.5,0.5,0,0,1,4,2.5v3A0.5,0.5,0,0,1,3.5,6Z"></path>
            <path class="ql-stroke ql-thin" d="M4.5,10.5h-2c0-.234,1.85-1.076,1.85-2.234A0.959,0.959,0,0,0,2.5,8.156"></path>
            <path class="ql-stroke ql-thin" d="M2.5,14.846a0.959,0.959,0,0,0,1.85-.109A0.7,0.7,0,0,0,3.75,14a0.688,0.688,0,0,0,.6-0.736,0.959,0.959,0,0,0-1.85-.109"></path>
          </svg>
        </button>

        <button
          :title="`Link (${mod}+k)`"
          class="menubar__button"
          :class="{ 'is-active': isActive.link() }"
          @click="openLinkMenu(getMarkAttrs('link'))"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <line class="ql-stroke" x1="7" x2="11" y1="7" y2="11"></line>
            <path class="ql-even ql-stroke" d="M8.9,4.577a3.476,3.476,0,0,1,.36,4.679A3.476,3.476,0,0,1,4.577,8.9C3.185,7.5,2.035,6.4,4.217,4.217S7.5,3.185,8.9,4.577Z"></path>
            <path class="ql-even ql-stroke" d="M13.423,9.1a3.476,3.476,0,0,0-4.679-.36,3.476,3.476,0,0,0,.36,4.679c1.392,1.392,2.5,2.542,4.679.36S14.815,10.5,13.423,9.1Z"></path>
          </svg>
        </button>

        <button
          title="Image"
          class="menubar__button"
          :class="{ 'is-active': isActive.image() }"
          @click="openImageMenu(isActive.image())"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <rect class="ql-stroke" height="10" width="12" x="3" y="4"></rect>
            <circle class="ql-fill" cx="6" cy="7" r="1"></circle>
            <polyline class="ql-even ql-fill" points="5 12 5 11 7 9 8 10 11 7 13 9 13 12 5 12"></polyline>
          </svg>
        </button>

        <button
          :title="`Blockquote (${mod}+>)`"
          class="menubar__button"
          :class="{ 'is-active': isActive.blockquote() }"
          @click="commands.blockquote"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <rect class="ql-fill ql-stroke" height="3" width="3" x="4" y="5"></rect>
            <rect class="ql-fill ql-stroke" height="3" width="3" x="11" y="5"></rect>
            <path class="ql-even ql-fill ql-stroke" d="M7,8c0,4.031-3,5-3,5"></path>
            <path class="ql-even ql-fill ql-stroke" d="M14,8c0,4.031-3,5-3,5"></path>
          </svg>
        </button>

        <button
          title="Code Block (Ctrl+Shift+\)"
          class="menubar__button"
          :class="{ 'is-active': isActive.code_block() }"
          @click="commands.code_block"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <polyline class="ql-even ql-stroke" points="5 7 3 9 5 11"></polyline>
            <polyline class="ql-even ql-stroke" points="13 7 15 9 13 11"></polyline>
            <line class="ql-stroke" x1="10" x2="8" y1="5" y2="13"></line>
          </svg>
        </button>

        <button
          title="Horizontal Rule"
          class="pr-2 border-r-2 border-gray-100 menubar__button"
          @click="commands.horizontal_rule"
          type="button"
        >
          <svg class="w-4 h-4" viewBox="0 0 18 18">
            <path class="ql-fill" d="M15,12v2a.99942.99942,0,0,1-1,1H4a.99942.99942,0,0,1-1-1V12a1,1,0,0,1,2,0v1h8V12a1,1,0,0,1,2,0ZM14,3H4A.99942.99942,0,0,0,3,4V6A1,1,0,0,0,5,6V5h8V6a1,1,0,0,0,2,0V4A.99942.99942,0,0,0,14,3Z"/>
            <path class="ql-fill" d="M15,10H3A1,1,0,0,1,3,8H15a1,1,0,0,1,0,2Z"/>
          </svg>
        </button>

        <button
          :title="`Undo (${mod}-z)`"
          class="menubar__button"
          @click="commands.undo"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <polygon class="ql-fill ql-stroke" points="6 10 4 12 2 10 6 10"></polygon>
            <path class="ql-stroke" d="M8.09,13.91A4.6,4.6,0,0,0,9,14,5,5,0,1,0,4,9"></path>
          </svg>
        </button>

        <button
          :title="`Redo (${mod}-y or ${mod}-shift-z)`"
          class="menubar__button"
          @click="commands.redo"
          type="button"
        >
          <svg class="w-4 h-4" viewbox="0 0 18 18">
            <polygon class="ql-fill ql-stroke" points="12 10 14 12 16 10 12 10"></polygon>
            <path class="ql-stroke" d="M9.91,13.91A4.6,4.6,0,0,1,9,14a5,5,0,1,1,5-5"></path>
          </svg>
        </button>

        <div v-if="showLinkMenu" class="flex mt-1">
          <input class="px-2 py-1 text-sm form-input" type="text" placeholder="https://"
            ref="linkInput"
            v-model="linkUrl"
            @keydown.enter.prevent="setLinkUrl(commands.link, linkUrl)"
            @keydown.esc="hideLinkMenu"/>
          <button type="button" title="Remove Link" class="inline-flex justify-center w-8 h-8 mx-2 text-white bg-red-500 rounded menubar__button"
            @click="setLinkUrl(commands.link, null)">
            <svg fill="currentColor" viewBox="0 0 20 20" class="w-4 h-4"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"></path></svg>
          </button>

          <button type="button" title="Ok" class="inline-flex justify-center w-8 h-8 text-white bg-green-500 rounded menubar__button"
            @click="setLinkUrl(commands.link, linkUrl)">
            <svg fill="currentColor" viewBox="0 0 20 20" class="w-4 h-4"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>
          </button>
        </div>

        <div v-if="showImageMenu" class="flex mt-1">
          <input class="px-2 py-1 text-sm form-input" type="text" placeholder="https://"
            ref="imageInput"
            v-model="imageUrl"
            @keydown.enter.prevent="setImageUrl(commands.image, imageUrl)"
            @keydown.esc="hideImageMenu"/>
          <button type="button" title="Remove Image" class="inline-flex justify-center w-8 h-8 mx-2 text-white bg-red-500 rounded menubar__button"
            @click="setImageUrl(commands.image, null)">
            <svg fill="currentColor" viewBox="0 0 20 20" class="w-4 h-4"><path fill-rule="evenodd" d="M9 2a1 1 0 00-.894.553L7.382 4H4a1 1 0 000 2v10a2 2 0 002 2h8a2 2 0 002-2V6a1 1 0 100-2h-3.382l-.724-1.447A1 1 0 0011 2H9zM7 8a1 1 0 012 0v6a1 1 0 11-2 0V8zm5-1a1 1 0 00-1 1v6a1 1 0 102 0V8a1 1 0 00-1-1z" clip-rule="evenodd"></path></svg>
          </button>

          <button type="button" title="Ok" class="inline-flex justify-center w-8 h-8 text-white bg-green-500 rounded menubar__button"
            @click="setImageUrl(commands.image, imageUrl)">
            <svg fill="currentColor" viewBox="0 0 20 20" class="w-4 h-4"><path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path></svg>
          </button>
        </div>
      </div>
    </editor-menu-bar>


    <editor-content class="prose xl:prose-xl lg:prose" :editor="editor" />
  </div>
</template>

<script>
import { EditorContent, EditorMenuBar } from 'tiptap'

let mod = ""
const isMac = navigator.platform.match(/mac/i)
if(isMac) { mod = "cmd" } else { mod = "ctrl" }

export default {
  components: {
    EditorContent,
    EditorMenuBar,
  },
  props: ['editor'],
  methods: {
    hideLinkMenu() {
      this.linkUrl = null;
      this.showLinkMenu = false;
    },

    openLinkMenu(attrs) {
      if (this.showLinkMenu == true) {
        this.showLinkMenu = false
      } else {
        this.linkUrl = attrs.href
        this.showLinkMenu = true;
        this.$nextTick(() => this.$refs.linkInput.focus())
      }
    },

    setLinkUrl(command, url) {
      command({href: url})
      this.hideLinkMenu()
    },
  },
  data() {
    return {
      linkUrl: null,
      imageUrl: null,
      mod: mod,
      showLinkMenu: false,
      showImageMenu: false
    }
  },
  beforeDestroy() {
    if(this.editor) {
      this.editor.destroy()
    }
  },
}
</script>

<style scoped>
.ql-stroke {
  fill: none;
  stroke: currentColor;
  stroke-linecap: round;
  stroke-linejoin: round;
  stroke-width: 2
}

.ql-fill {
  fill: currentColor;
}

.ql-thin {
  stroke-width: 1
}

.ql-even {
  fill-rule: evenodd;
}
</style>

<style>
.editor p.is-editor-empty:first-child::before {
  content: attr(data-empty-text);
  float: left;
  color: #aaa;
  pointer-events: none;
  height: 0;
  font-style: italic;
}
</style>
