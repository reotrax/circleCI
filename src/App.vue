<template>
  <div id="app">
    <h1>{{ msg }}</h1>
    <p>Count: {{ cnt }}</p>
    <p v-if="cnt > 0" class="status">{{ getStatus }}</p>
    <button @click="inc">Increment</button>
    <button @click="res">Reset</button>
  </div>
</template>

<script>
import { ref, computed } from '@vue/composition-api'

export default {
  name: 'App',
  setup() {
    const msg = ref('Welcome to Vue 2.6 + Composition API')
    const cnt = ref(0)

    const getStatus = computed(() => {
      const val = cnt.value
      if (val === 0) return ''
      if (val >= 10) return 'Maximum reached!'
      if (val >= 5) return 'Halfway there!'
      return 'Keep going!'
    })

    function inc() {
      if (cnt.value < 10) cnt.value++
    }

    function res() {
      if (cnt.value > 0) cnt.value = 0
    }

    return { msg, cnt, getStatus, inc, res }
  }
}
</script>

<style>
#app {
  font-family: Avenir, Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 60px;
}

button {
  padding: 10px 20px;
  font-size: 16px;
  cursor: pointer;
  background-color: #42b983;
  color: white;
  border: none;
  border-radius: 4px;
  margin: 0 5px;
}

button:hover:not(:disabled) {
  background-color: #35a372;
}

button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.status {
  font-weight: bold;
  color: #42b983;
  margin: 10px 0;
}
</style>
