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
          <div class="flex items-center gap-3 text-lg text-slate-300">
            <span>{{ loading ? '加载中' : `${filteredModels.length} / ${models.length} 个模型` }}</span>
            <button
              type="button"
              class="rounded-full border border-white/15 px-3 py-1 text-sm text-slate-300 transition-colors hover:border-cyan-400/60 hover:text-white disabled:opacity-60"
              :disabled="loading"
              @click="loadModels"
            >
              刷新
            </button>
          </div>
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

      <section v-if="loading" class="py-20 text-center text-slate-300">
        正在加载
      </section>

      <section v-else-if="errorMessage" class="py-20 text-center">
        <p class="mb-4 text-slate-300">{{ errorMessage }}</p>
        <button
          type="button"
          class="rounded-full border border-cyan-400/60 px-4 py-2 text-sm text-white"
          @click="loadModels"
        >
          重试
        </button>
      </section>

      <section v-else class="grid gap-5 lg:grid-cols-3">
        <article
          v-for="(model, index) in filteredModels"
          :key="modelKey(model, index)"
          class="rounded border border-white/15 bg-black/20 p-6 shadow-[0_12px_40px_rgba(0,0,0,0.16)]"
        >
          <div class="mb-5 flex items-center gap-4">
            <div class="flex h-7 w-7 items-center justify-center text-xl text-orange-400">
              {{ providerSymbol(getModelPlatform(model)) }}
            </div>
            <h2 class="text-xl font-medium text-white">{{ getModelName(model) }}</h2>
          </div>

          <div class="mb-5 text-sm text-slate-300">
            {{ getModelPlatform(model) }}
            <template v-if="model.category">
              <span class="mx-2 text-slate-500">/</span> {{ model.category }}
            </template>
          </div>

          <p v-if="model.description || model.note" class="mb-5 min-h-[72px] text-base leading-7 text-slate-200">
            {{ model.description || model.note }}
          </p>

          <div class="space-y-2">
            <div
              v-for="(field, priceIndex) in getModelPrices(model)"
              :key="`${modelKey(model, index)}:${field.label}:${priceIndex}`"
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
              v-for="(group, groupIndex) in getModelGroups(model)"
              :key="`${modelKey(model, index)}:${getGroupLabel(group)}:${groupIndex}`"
              :title="getGroupNote(group)"
              class="inline-flex max-w-full items-center gap-2 rounded-full border border-white/15 px-3 py-1 text-sm text-slate-300"
            >
              <span class="truncate">{{ getGroupLabel(group) }}</span>
              <span v-if="group.multiplier" class="font-mono text-cyan-300">{{ group.multiplier }}</span>
              <span v-if="getGroupNote(group)" class="truncate text-slate-400">{{ getGroupNote(group) }}</span>
            </span>
          </div>
        </article>
      </section>
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import { useAuthStore, useAppStore } from '@/stores'
import {
  getGroupLabel,
  getGroupNote,
  getModelGroups,
  getModelName,
  getModelPlatform,
  getModelPriceFeed,
  getModelPrices,
  type ModelPriceEntry,
} from '@/api/modelPriceFeed'

const appStore = useAppStore()
const authStore = useAuthStore()

const selectedProvider = ref('all')
const models = ref<ModelPriceEntry[]>([])
const loading = ref(false)
const errorMessage = ref('')

const siteName = computed(() => appStore.cachedPublicSettings?.site_name || appStore.siteName || 'G-AISC')
const brandInitial = computed(() => siteName.value.trim().charAt(0).toUpperCase() || 'G')
const isAuthenticated = computed(() => authStore.isAuthenticated)
const dashboardPath = computed(() => authStore.isAdmin ? '/admin/dashboard' : '/dashboard')

const providerTabs = computed(() => {
  const providers = Array.from(new Set(models.value.map((model) => getModelPlatform(model)).filter(Boolean)))
  return [
    { provider: 'all', label: '全部', count: models.value.length },
    ...providers.map((provider) => ({
      provider,
      label: provider,
      count: models.value.filter((model) => getModelPlatform(model) === provider).length,
    })),
  ]
})

const filteredModels = computed(() => {
  if (selectedProvider.value === 'all') return models.value
  return models.value.filter((model) => getModelPlatform(model) === selectedProvider.value)
})

function providerSymbol(provider: string): string {
  const normalized = provider.toLowerCase()
  if (normalized === 'openai') return 'O'
  if (normalized === 'gemini') return 'G'
  if (normalized === 'anthropic') return 'A'
  return provider.charAt(0).toUpperCase()
}

function modelKey(model: ModelPriceEntry, index: number): string {
  return `${index}:${getModelPlatform(model)}:${getModelName(model)}`
}

async function loadModels() {
  loading.value = true
  errorMessage.value = ''
  try {
    const feed = await getModelPriceFeed()
    models.value = Array.isArray(feed.models) ? feed.models : []
  } catch (error) {
    console.error('Failed to load model price feed:', error)
    errorMessage.value = '价格数据加载失败'
  } finally {
    loading.value = false
  }
}

onMounted(loadModels)
</script>
