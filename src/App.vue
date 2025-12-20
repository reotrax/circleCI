<template>
  <div id="app">
    <h1>{{ message }}</h1>
    <p>Count: {{ count }}</p>
    <button @click="increment">Increment</button>
  </div>
</template>

<script>
import { ref } from '@vue/composition-api'

export default {
  name: 'App',
  setup() {
    const message = ref('Welcome to Vue 2.6 + Composition API')
    const count = ref(0)

    const increment = () => {
      count.value++
    }

    return {
      message,
      count,
      increment
    }
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
}

button:hover {
  background-color: #35a372;
}
</style>
