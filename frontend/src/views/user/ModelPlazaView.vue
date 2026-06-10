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
            placeholder="搜索模型、平台或渠道..."
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
        实际扣费等于官网价格乘以 API Key 所属分组倍率；如果配置了用户专属倍率，则优先使用用户专属倍率。
      </div>

      <div class="min-h-0 flex-1 overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm dark:border-dark-700 dark:bg-dark-800">
        <div class="h-full overflow-auto">
          <table class="w-full min-w-[1120px] table-fixed border-collapse text-sm">
            <thead class="sticky top-0 z-10 bg-gray-50/95 backdrop-blur dark:bg-dark-800/95">
              <tr class="border-b border-gray-200 text-left text-sm text-gray-600 dark:border-dark-700 dark:text-dark-300">
                <th class="w-[300px] px-5 py-4">语言模型</th>
                <th class="w-[180px] px-5 py-4">平台</th>
                <th class="w-[320px] px-5 py-4">官网价格</th>
                <th class="px-5 py-4">实际扣费</th>
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
                :key="`${row.platform}:${row.name}`"
                class="transition-colors hover:bg-gray-50/70 dark:hover:bg-dark-700/35"
              >
                <td class="px-5 py-5 align-top">
                  <div class="text-gray-900 dark:text-white">{{ row.name }}</div>
                  <div class="mt-1 text-xs text-gray-500 dark:text-dark-400">
                    {{ row.channelNames.join(' / ') }}
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
                      v-for="line in row.pricingLines"
                      :key="line.label"
                      class="grid grid-cols-[72px_1fr] gap-3 text-sm"
                    >
                      <span class="text-gray-500 dark:text-dark-400">{{ line.label }}</span>
                      <span class="font-mono text-gray-900 dark:text-white">{{ line.value }}</span>
                    </div>
                  </div>
                  <span v-else class="text-sm text-gray-400">暂无价格</span>
                </td>

                <td class="px-5 py-5 align-top">
                  <div class="text-gray-900 dark:text-white">
                    {{ row.rateSummary }}
                  </div>
                  <div class="mt-1 text-xs text-gray-500 dark:text-dark-400">
                    最终以请求使用的 API Key 分组为准
                  </div>
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
import userChannelsAPI, {
  type UserAvailableChannel,
  type UserSupportedModel,
  type UserSupportedModelPricing,
} from '@/api/channels'
import userGroupsAPI from '@/api/groups'
import { useAppStore } from '@/stores/app'
import { extractApiErrorMessage } from '@/utils/apiError'
import { platformBadgeClass } from '@/utils/platformColors'
import { formatScaled } from '@/utils/pricing'
import {
  BILLING_MODE_IMAGE,
  BILLING_MODE_PER_REQUEST,
  BILLING_MODE_TOKEN,
} from '@/constants/channel'
import type { GroupPlatform } from '@/types'

interface PriceLine {
  label: string
  value: string
}

interface ModelPlazaRow {
  name: string
  platform: string
  channelNames: string[]
  pricingLines: PriceLine[]
  rateSummary: string
}

const appStore = useAppStore()

const channels = ref<UserAvailableChannel[]>([])
const userGroupRates = ref<Record<number, number>>({})
const loading = ref(false)
const searchQuery = ref('')

const rows = computed<ModelPlazaRow[]>(() => {
  const byModel = new Map<string, {
    name: string
    platform: string
    channelNames: Set<string>
    pricing: UserSupportedModelPricing | null
    rates: Set<number>
  }>()

  for (const channel of channels.value) {
    for (const section of channel.platforms) {
      const sectionRates = section.groups.map((group) => userGroupRates.value[group.id] ?? group.rate_multiplier)
      for (const model of section.supported_models) {
        const key = `${section.platform}:${model.name}`
        const existing = byModel.get(key)
        if (existing) {
          existing.channelNames.add(channel.name)
          for (const rate of sectionRates) existing.rates.add(rate)
          if (!existing.pricing && model.pricing) existing.pricing = model.pricing
          continue
        }

        byModel.set(key, {
          name: model.name,
          platform: section.platform,
          channelNames: new Set([channel.name]),
          pricing: model.pricing,
          rates: new Set(sectionRates),
        })
      }
    }
  }

  return Array.from(byModel.values())
    .map((item) => ({
      name: item.name,
      platform: item.platform,
      channelNames: Array.from(item.channelNames).sort((a, b) => a.localeCompare(b)),
      pricingLines: buildPricingLines({ name: item.name, platform: item.platform, pricing: item.pricing }),
      rateSummary: buildRateSummary(item.rates),
    }))
    .sort((a, b) => a.name.localeCompare(b.name))
})

const filteredRows = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return rows.value
  return rows.value.filter((row) =>
    row.name.toLowerCase().includes(q) ||
    row.platform.toLowerCase().includes(q) ||
    row.channelNames.some((name) => name.toLowerCase().includes(q))
  )
})

function buildPricingLines(model: UserSupportedModel): PriceLine[] {
  const pricing = model.pricing
  if (!pricing) return []

  if (pricing.billing_mode === BILLING_MODE_TOKEN) {
    return [
      { label: '输入', value: `${formatScaled(pricing.input_price, 1_000_000)} / 1M token` },
      { label: '输出', value: `${formatScaled(pricing.output_price, 1_000_000)} / 1M token` },
      { label: '缓存读取', value: `${formatScaled(pricing.cache_read_price, 1_000_000)} / 1M token` },
    ]
  }

  if (pricing.billing_mode === BILLING_MODE_IMAGE) {
    const lines: PriceLine[] = []
    if (pricing.intervals.length > 0) {
      for (const interval of pricing.intervals) {
        lines.push({
          label: interval.tier_label || formatTokenRange(interval.min_tokens, interval.max_tokens),
          value: `${formatScaled(interval.per_request_price ?? pricing.image_output_price, 1)} / 张`,
        })
      }
      return lines
    }
    return [{ label: '图片', value: `${formatScaled(pricing.image_output_price, 1)} / 张` }]
  }

  if (pricing.billing_mode === BILLING_MODE_PER_REQUEST) {
    return [{ label: '请求', value: `${formatScaled(pricing.per_request_price, 1)} / 次` }]
  }

  return []
}

function formatTokenRange(min: number, max: number | null): string {
  if (max == null) return `${min}+`
  return String(max)
}

function buildRateSummary(rates: Set<number>): string {
  void rates
  return '官网价格 x key的分组倍率'
}

async function loadModelPlaza() {
  loading.value = true
  try {
    const [list, rates] = await Promise.all([
      userChannelsAPI.getAvailable(),
      userGroupsAPI.getUserGroupRates().catch((err: unknown) => {
        console.error('Failed to load user group rates:', err)
        return {} as Record<number, number>
      }),
    ])
    channels.value = list
    userGroupRates.value = rates
  } catch (err: unknown) {
    appStore.showError(extractApiErrorMessage(err, '加载模型广场失败'))
  } finally {
    loading.value = false
  }
}

onMounted(loadModelPlaza)
</script>
