<template>
  <div class="min-h-screen bg-[#101f22] text-slate-100">
    <header class="border-b border-white/10 bg-[#101f22]/95 backdrop-blur">
      <div class="mx-auto flex max-w-7xl items-center justify-between px-6 py-4">
        <router-link to="/home" class="flex items-center gap-3">
          <div class="flex h-9 w-9 items-center justify-center rounded-lg bg-cyan-700 text-sm font-bold text-white">
            {{ brandInitial }}
          </div>
          <div>
            <div class="text-sm font-medium text-white">{{ siteName }}</div>
            <div class="text-xs text-slate-400">Model Plaza</div>
          </div>
        </router-link>

        <router-link
          :to="isAuthenticated ? dashboardPath : '/login'"
          class="rounded-full border border-white/15 px-4 py-2 text-sm text-slate-200 transition-colors hover:border-cyan-400/60 hover:text-white"
        >
          {{ isAuthenticated ? '进入控制台' : '登录控制台' }}
        </router-link>
      </div>
    </header>

    <main class="mx-auto max-w-7xl px-6 py-8">
      <section class="mb-10">
        <div class="mb-8 flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <div class="mb-8 text-sm uppercase tracking-wide text-slate-300">Available Models</div>
            <h1 class="text-4xl font-medium tracking-tight text-white md:text-5xl">全部模型</h1>
          </div>
          <div class="text-lg text-slate-300">{{ filteredModels.length }} / {{ models.length }} 个模型</div>
        </div>

        <div class="flex flex-wrap gap-3">
          <button
            v-for="tab in providerTabs"
            :key="tab.provider"
            type="button"
            class="rounded-full border px-4 py-2 text-sm transition-colors"
            :class="selectedProvider === tab.provider
              ? 'border-cyan-400/70 bg-cyan-500/15 text-white'
              : 'border-white/15 bg-black/10 text-slate-300 hover:border-white/30 hover:text-white'"
            @click="selectedProvider = tab.provider"
          >
            {{ tab.label }} <span class="ml-1 text-slate-400">{{ tab.count }}</span>
          </button>
        </div>
      </section>

      <section class="grid gap-5 lg:grid-cols-3">
        <article
          v-for="model in filteredModels"
          :key="model.id"
          class="rounded border border-white/15 bg-black/20 p-6 shadow-[0_12px_40px_rgba(0,0,0,0.16)]"
        >
          <div class="mb-5 flex items-center gap-4">
            <div class="flex h-7 w-7 items-center justify-center text-xl text-orange-400">
              {{ providerSymbol(model.provider) }}
            </div>
            <h2 class="text-xl font-medium text-white">{{ model.id }}</h2>
          </div>

          <div class="mb-5 text-sm text-slate-300">
            {{ model.provider }} <span class="mx-2 text-slate-500">/</span> {{ model.category }}
          </div>

          <p class="mb-5 min-h-[72px] text-base leading-7 text-slate-200">
            {{ model.description }}
          </p>

          <div class="space-y-2">
            <div
              v-for="field in model.priceFields"
              :key="`${model.id}:${field.label}`"
              class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-3 rounded bg-cyan-950/40 px-3 py-2 text-sm"
            >
              <div class="min-w-0 text-slate-200">{{ field.label }}</div>
              <div class="whitespace-nowrap text-right font-mono text-cyan-300">
                {{ field.price }}
              </div>
            </div>
          </div>

          <div class="mt-5 flex flex-wrap gap-2">
            <span
              v-for="badge in model.badges"
              :key="`${model.id}:${badge.label}`"
              :title="badge.description"
              class="inline-flex max-w-full items-center gap-2 rounded-full border border-white/15 px-3 py-1 text-sm text-slate-300"
            >
              <span class="truncate">{{ badge.label }}</span>
              <span v-if="badge.multiplier" class="font-mono text-cyan-300">{{ badge.multiplier }}</span>
            </span>
          </div>
        </article>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { useAuthStore, useAppStore } from '@/stores'
import plaza from '@/data/publicModelPlaza.json'

const appStore = useAppStore()
const authStore = useAuthStore()

const selectedProvider = ref('all')
const models = plaza.models

const siteName = computed(() => appStore.cachedPublicSettings?.site_name || appStore.siteName || 'G-AISC')
const brandInitial = computed(() => siteName.value.trim().charAt(0).toUpperCase() || 'G')
const isAuthenticated = computed(() => authStore.isAuthenticated)
const dashboardPath = computed(() => authStore.isAdmin ? '/admin/dashboard' : '/dashboard')

const providerTabs = computed(() => {
  const providers = Array.from(new Set(models.map((model) => model.provider)))
  return [
    { provider: 'all', label: '全部', count: models.length },
    ...providers.map((provider) => ({
      provider,
      label: provider,
      count: models.filter((model) => model.provider === provider).length,
    })),
  ]
})

const filteredModels = computed(() => {
  if (selectedProvider.value === 'all') return models
  return models.filter((model) => model.provider === selectedProvider.value)
})

function providerSymbol(provider: string): string {
  if (provider === 'OpenAI') return 'O'
  if (provider === 'Gemini') return 'G'
  if (provider === 'Anthropic') return 'A'
  return provider.charAt(0).toUpperCase()
}

</script>
