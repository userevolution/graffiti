<template>
  <div class="field has-addons">
    <div class="control">
      <input class="input" type="text" placeholder="xDai" v-model="amountInput">
    <p v-if="amountInput && amountInvalid" class="help is-danger">Invalid deposit amount</p>
    </div>
    <div class="control">
      <a
        class="button is-dark"
        v-bind:class="{'is-loading': waitingForTx}"
        v-bind:disabled="amountInvalid"
        v-on:click="deposit"
      >
        Deposit
      </a>
    </div>
  </div>
</template>

<script>
import { ethers } from 'ethers'

export default {
  name: "DepositField",
  props: [
    "account",
  ],

  data() {
    return {
      amountInput: null,
      waitingForTx: false,
    }
  },

  computed: {
    amount() {
      try {
        return ethers.utils.parseEther(this.amountInput)
      } catch(err) {
        return null
      }
    },
    amountInvalid() {
      return this.amount === null || this.amount.lte(0) || this.amount.mod(1e9) != 0
    },
  },

  methods: {
    async deposit() {
      this.waitingForTx = true
      try {
        let signer = this.$provider.getSigner(this.account)
        let contract = this.$contract.connect(signer)
        await contract.deposit({value: this.amount})
        this.amountInput = ""
      } catch(err) {
        this.$emit('error', 'Failed to send deposit transaction: ' + err.message)
      }
      this.waitingForTx = false
    },
  },
}
</script>