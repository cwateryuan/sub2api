<template>
  <AppLayout>
    <div class="flex h-[calc(100vh-64px-4rem)] flex-col gap-6">
      <div class="flex flex-col justify-between gap-4 lg:flex-row lg:items-center">
        <div class="relative w-full sm:w-80">
          <Icon
            name="search"
            size="md"
            class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 dark:text-gray-500"
          />
          <input
            v-model="searchQuery"
            type="text"
            placeholder="搜索模型、平台或分组..."
            class="input pl-10"
          />
        </div>

        <button
          @click="loadModelPlaza"
          :disabled="loading"
          class="btn btn-secondary"
          title="刷新"
        >
          <Icon name="refresh" size="md" :class="loading ? 'animate-spin' : ''" />
        </button>
      </div>

      <div class="rounded-lg border border-amber-300/50 bg-amber-50 px-4 py-3 text-sm font-medium text-amber-800 dark:border-amber-500/40 dark:bg-amber-500/10 dark:text-amber-200">
        实际扣费以官网价格和请求使用的 API Key 分组倍率为准。
      </div>

      <div class="min-h-0 flex-1 overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-dark-700 dark:bg-dark-800">
        <div class="h-full overflow-auto">
          <table class="w-full min-w-[1120px] table-fixed border-collapse text-sm">
            <thead class="sticky top-0 z-10 bg-gray-50/95 backdrop-blur dark:bg-dark-800/95">
              <tr class="border-b border-gray-200 text-left text-sm text-gray-600 dark:border-dark-700 dark:text-dark-300">
                <th class="w-[300px] px-5 py-4">模型</th>
                <th class="w-[180px] px-5 py-4">平台</th>
                <th class="w-[320px] px-5 py-4">官网价格</th>
                <th class="px-5 py-4">分组倍率与备注</th>
              </tr>
            </thead>

            <tbody v-if="loading">
              <tr>
                <td colspan="4" class="py-16 text-center">
                  <Icon name="refresh" size="lg" class="inline-block animate-spin text-gray-400" />
                </td>
              </tr>
            </tbody>

            <tbody v-else-if="filteredRows.length === 0">
              <tr>
                <td colspan="4" class="py-16 text-center">
                  <Icon name="inbox" size="xl" class="mx-auto mb-3 text-gray-400" />
                  <p class="text-sm text-gray-500 dark:text-gray-400">暂无可展示模型</p>
                </td>
              </tr>
            </tbody>

            <tbody v-else class="divide-y divide-gray-100 dark:divide-dark-700/70">
              <tr
                v-for="row in filteredRows"
                :key="row.key"
                class="transition-colors hover:bg-gray-50/70 dark:hover:bg-dark-700/35"
              >
                <td class="px-5 py-5 align-top">
                  <div class="text-gray-900 dark:text-white">{{ row.name }}</div>
                  <div v-if="row.note" class="mt-1 text-xs text-gray-500 dark:text-dark-400">
                    {{ row.note }}
                  </div>
                </td>

                <td class="px-5 py-5 align-top">
                  <span
                    :class="[
                      'inline-flex items-center gap-1 rounded-md border px-2.5 py-1 text-xs uppercase',
                      platformBadgeClass(row.platform),
                    ]"
                  >
                    <PlatformIcon :platform="row.platform as GroupPlatform" size="xs" />
                    {{ row.platform }}
                  </span>
                </td>

                <td class="px-5 py-5 align-top">
                  <div v-if="row.pricingLines.length > 0" class="space-y-1.5">
                    <div
                      v-for="(line, lineIndex) in row.pricingLines"
                      :key="`${row.key}:${line.label}:${lineIndex}`"
                      class="grid grid-cols-[72px_1fr] gap-3 text-sm"
                    >
                      <span class="text-gray-500 dark:text-dark-400">{{ line.label }}</span>
                      <span class="font-mono text-gray-900 dark:text-white">{{ line.value }}</span>
                    </div>
                  </div>
                  <span v-else class="text-sm text-gray-400">暂无价格</span>
                </td>

                <td class="px-5 py-5 align-top">
                  <div v-if="row.groups.length > 0" class="space-y-2">
                    <div
                      v-for="(group, groupIndex) in row.groups"
                      :key="`${row.key}:${group.label}:${groupIndex}`"
                      class="rounded-md border border-gray-200 px-3 py-2 dark:border-dark-700"
                    >
                      <div class="flex flex-wrap items-center gap-2 text-sm text-gray-900 dark:text-white">
                        <span>{{ group.label }}</span>
                        <span v-if="group.multiplier" class="font-mono text-primary-600 dark:text-primary-400">
                          {{ group.multiplier }}
                        </span>
                      </div>
                      <div v-if="group.note" class="mt-1 text-xs text-gray-500 dark:text-dark-400">
                        {{ group.note }}
                      </div>
                    </div>
                  </div>
                  <span v-else class="text-sm text-gray-400">暂无分组</span>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </AppLayout>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import AppLayout from '@/components/layout/AppLayout.vue'
import Icon from '@/components/icons/Icon.vue'
import PlatformIcon from '@/components/common/PlatformIcon.vue'
import { useAppStore } from '@/stores/app'
import { extractApiErrorMessage } from '@/utils/apiError'
import { platformBadgeClass } from '@/utils/platformColors'
import type { GroupPlatform } from '@/types'
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

interface PriceLine {
  label: string
  value: string
}

interface GroupLine {
  label: string
  multiplier: string
  note: string
}

interface ModelPlazaRow {
  key: string
  name: string
  platform: string
  note: string
  pricingLines: PriceLine[]
  groups: GroupLine[]
}

const appStore = useAppStore()

const models = ref<ModelPriceEntry[]>([])
const loading = ref(false)
const searchQuery = ref('')

const rows = computed<ModelPlazaRow[]>(() => {
  return models.value.map((model, index) => {
    const name = getModelName(model)
    const platform = getModelPlatform(model).toLowerCase()
    return {
      key: `${index}:${platform}:${name}`,
      name,
      platform,
      note: model.note || model.description || '',
      pricingLines: getModelPrices(model).map((line) => ({
        label: line.label,
        value: line.price,
      })),
      groups: getModelGroups(model).map((group) => ({
        label: getGroupLabel(group),
        multiplier: group.multiplier || '',
        note: getGroupNote(group),
      })),
    }
  })
})

const filteredRows = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return rows.value
  return rows.value.filter((row) =>
    row.name.toLowerCase().includes(q) ||
    row.platform.toLowerCase().includes(q) ||
    row.note.toLowerCase().includes(q) ||
    row.groups.some((group) =>
      group.label.toLowerCase().includes(q) ||
      group.multiplier.toLowerCase().includes(q) ||
      group.note.toLowerCase().includes(q)
    )
  )
})

async function loadModelPlaza() {
  loading.value = true
  try {
    const feed = await getModelPriceFeed()
    models.value = Array.isArray(feed.models) ? feed.models : []
  } catch (err: unknown) {
    appStore.showError(extractApiErrorMessage(err, '加载模型广场失败'))
  } finally {
    loading.value = false
  }
}

onMounted(loadModelPlaza)
</script>
