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
    expect(wrapper.vm.cnt.value).toBe(0)
  })

  test('increments count when button is clicked', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)

    await incrementButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(1)

    await incrementButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(2)
  })

  test('shows status message "Keep going!" when count is 1-4', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)

    // カウント1
    await incrementButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.getStatus.value).toBe('Keep going!')
  })

  test('shows status message "Halfway there!" when count is 5-9', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)

    // カウントを5まで増やす
    for (let i = 0; i < 5; i++) {
      await incrementButton.trigger('click')
      await wrapper.vm.$nextTick()
    }

    expect(wrapper.vm.getStatus.value).toBe('Halfway there!')
  })

  test('shows status message "Maximum reached!" when count is 10', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)

    // カウントを10まで増やす
    for (let i = 0; i < 10; i++) {
      await incrementButton.trigger('click')
      await wrapper.vm.$nextTick()
    }

    expect(wrapper.vm.getStatus.value).toBe('Maximum reached!')
  })

  test('does not increment beyond 10 when clicking', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)

    // カウントを10まで増やす
    for (let i = 0; i < 10; i++) {
      await incrementButton.trigger('click')
      await wrapper.vm.$nextTick()
    }

    expect(wrapper.vm.cnt.value).toBe(10)

    // さらにクリックしても増えない
    await incrementButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(10)
  })

  test('does not increment beyond 10 directly', async () => {
    const wrapper = mount(App, { localVue })

    // カウントを直接10に設定
    wrapper.vm.cnt.value = 10
    await wrapper.vm.$nextTick()

    // incを呼び出してもカウントは増えない
    wrapper.vm.inc()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(10)

    // さらに呼び出してもカウントは増えない
    wrapper.vm.inc()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(10)
  })

  test('increments successfully when below 10', async () => {
    const wrapper = mount(App, { localVue })

    // カウントを9に設定
    wrapper.vm.cnt.value = 9
    await wrapper.vm.$nextTick()

    // incを呼び出すとカウントが10になる
    wrapper.vm.inc()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(10)
  })

  test('resets count to 0 when reset button is clicked', async () => {
    const wrapper = mount(App, { localVue })
    const incrementButton = wrapper.findAll('button').at(0)
    const resetButton = wrapper.findAll('button').at(1)

    // カウントを増やす
    await incrementButton.trigger('click')
    await incrementButton.trigger('click')
    await incrementButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(3)

    // リセット
    await resetButton.trigger('click')
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(0)
    expect(wrapper.vm.getStatus.value).toBe('')
  })

  test('does not reset when count is already 0', async () => {
    const wrapper = mount(App, { localVue })

    expect(wrapper.vm.cnt.value).toBe(0)

    // カウント0でresを呼び出してもカウントは変わらない
    wrapper.vm.res()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(0)

    // さらに呼び出してもカウントは変わらない
    wrapper.vm.res()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(0)
  })

  test('resets successfully when count is greater than 0', async () => {
    const wrapper = mount(App, { localVue })

    // カウントを5に設定
    wrapper.vm.cnt.value = 5
    await wrapper.vm.$nextTick()

    // resを呼び出すとカウントが0になる
    wrapper.vm.res()
    await wrapper.vm.$nextTick()
    expect(wrapper.vm.cnt.value).toBe(0)
  })

  test('shows no status message when count is 0', () => {
    const wrapper = mount(App, { localVue })
    expect(wrapper.vm.getStatus.value).toBe('')
  })

  test('has both increment and reset buttons', () => {
    const wrapper = mount(App, { localVue })
    const buttons = wrapper.findAll('button')
    expect(buttons.length).toBe(2)
    expect(buttons.at(0).text()).toBe('Increment')
    expect(buttons.at(1).text()).toBe('Reset')
  })
})
