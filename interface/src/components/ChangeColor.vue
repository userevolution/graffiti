<template>
  <div class="field is-grouped is-grouped-centered">
    <div class="control is-expanded">
      <div class="columns is-centered">
        <div class="column is-narrow">
          <v-swatches 
            v-model="colorHex" 
            :swatches="swatches"
            show-border
            popover-y="top"
          ></v-swatches>
        </div>
      </div>
    </div>
    <div class="control">
      <a
        class="button is-dark"
        v-bind:class="{'is-loading': waitingForTx}"
        v-on:click="changeColor"
        v-bind:disabled="!colorChanged"
      >
        Change Color
      </a>
    </div>
  </div>
</template>

<script>
import VSwatches from 'vue-swatches'
import { colorHexIndices, colorsHex } from '../utils'

export default {
  name: "ChangeColorField",
  components: {
    VSwatches,
  },

  props: [
    "account",
    "pixelID",
    "currentColor",
  ],

  data() {
    return {
      waitingForTx: false,
      colorHex: '#ffffff',
      swatches: colorsHex,
    }
  },

  watch: {
    currentColor: {
      handler() {
        this.colorHex = this.swatches[this.currentColor]
      },
      immediate: true,
    },
  },

  computed: {
    colorChanged() {
      return colorHexIndices[this.colorHex] != this.currentColor
    },
  },

  methods: {
    async changeColor() {
      this.waitingForTx = true
      try {
        let signer = this.$provider.getSigner(this.account)
        let contract = this.$contract.connect(signer)
        await contract.setColor(this.pixelID, colorHexIndices[this.colorHex])
      } catch(err) {
        this.$emit('error', 'Failed to send change color transaction: ' + err.message)
      }
      this.waitingForTx = false
    },
  },
}
</script>