import { mount, createLocalVue } from '@vue/test-utils'
import VueCompositionAPI from '@vue/composition-api'
import App from '@/src/App.vue'

const localVue = createLocalVue()
localVue.use(VueCompositionAPI)

describe('App.vue', () => {
  test('renders welcome message', () => {
    const wrapper = mount(App, { localVue })
    expect(wrapper.find('h1').text()).toContain('Welcome to Vue 2.6 + Composition API')
  })

  test('displays initial count as 0', () => {
    const wrapper = mount(App, { localVue })
    expect(wrapper.find('p').text()).toContain('Count:')
  })

  test('increments count when button is clicked', async () => {
    const wrapper = mount(App, { localVue })
    const button = wrapper.find('button')

    await button.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.count.value).toBe(1)

    await button.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.count.value).toBe(2)
  })

  test('button has correct text', () => {
    const wrapper = mount(App, { localVue })
    expect(wrapper.find('button').text()).toBe('Increment')
  })
})
