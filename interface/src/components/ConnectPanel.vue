<template>
  <article v-if="!account" class="panel is-outlined" style="pointer-events: auto;">
    <p class="panel-heading">
      Wallet Connection
    </p>
    <div class="panel-block">
      <button class="button is-fullwidth is-dark" v-bind:class="{'is-loading': waitingForAccount}" v-on:click="connect">
        Connect
      </button>
    </div>

  </article>
</template>

<script>
import { ethers } from 'ethers'

export default {
  name: 'ConnectPanel',
  data() {
    return {
      waitingForAccount: false,
    }
  },
  props: [
    "account"
  ],

  created() {
    window.ethereum.on('accountsChanged', this.onAccountsChanged)
    this.$provider.listAccounts().then((accounts) => {
      if (accounts.length > 0) {
        this.$emit("accountChanged", accounts[0])
      }
    })
  },

  methods: {
    async connect() {
      this.waitingForAccount = true
      let accounts
      try {
        accounts = await window.ethereum.request({method: 'eth_requestAccounts'})
      } catch(err) {
        this.$emit('error', 'Failed to requests accounts: ' + err.message)
      }
      this.$emit("accountChanged", ethers.utils.getAddress(accounts[0]))
      this.waitingForAccount = false
    },

    onAccountsChanged(accounts) {
      if (accounts.length >= 0) {
        this.$emit("accountChanged", ethers.utils.getAddress(accounts[0]))
      } else {
        this.$emit('error', 'No connected account.')
      }
    }
  },
}
</script>