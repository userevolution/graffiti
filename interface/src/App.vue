<template>
  <div id="app">
    <Canvas
      v-on:pixelSelected="onPixelSelected"
      v-on:cursorPixelChanged="onCursorPixelChanged"
      v-bind:wrongNetwork="wrongNetwork"
    />
    <Panels
      v-bind:selectedPixel="selectedPixel"
      v-bind:cursorPixel="cursorPixel"
      v-bind:wrongNetwork="wrongNetwork"
    />
  </div>
</template>

<script>
import Canvas from './components/Canvas.vue'
import Panels from './components/Panels.vue'

export default {
  name: 'App',
  components: {
    Canvas,
    Panels,
  },

  data() {
    return {
      selectedPixel: null,
      cursorPixel: null,
      network: null
    }
  },

  mounted() { 
      this.$provider.getNetwork().then((network) => {
        this.network = network
      })
  },

  computed: {
    wrongNetwork() {
      if (!this.network) {
        return null
      }
      return this.network.chainId != 100
    }
  },

  methods: {
    onPixelSelected(coords) {
      this.selectedPixel = coords
    },
    onCursorPixelChanged(coords) {
      this.cursorPixel = coords
    }
  },
}
</script>