import { apiClient } from './client'

export interface ModelPriceLine {
  label: string
  price: string
}

export interface ModelPriceGroup {
  name?: string
  label?: string
  multiplier?: string
  note?: string
  description?: string
}

export interface ModelPriceEntry {
  model?: string
  id?: string
  platform?: string
  provider?: string
  category?: string
  family?: string
  description?: string
  prices?: ModelPriceLine[]
  priceFields?: ModelPriceLine[]
  groups?: ModelPriceGroup[]
  badges?: ModelPriceGroup[]
  note?: string
  featured?: boolean
}

export interface ModelPriceFeed {
  version?: number
  updated_at?: string
  models: ModelPriceEntry[]
}

export async function getModelPriceFeed(): Promise<ModelPriceFeed> {
  const { data } = await apiClient.get<ModelPriceFeed | ModelPriceEntry[]>('/settings/model-price-feed', {
    headers: {
      'Cache-Control': 'no-cache',
      Pragma: 'no-cache',
    },
    params: {
      _: Date.now(),
    },
  })
  if (Array.isArray(data)) {
    return { models: data }
  }
  return {
    ...data,
    models: Array.isArray(data?.models) ? data.models : [],
  }
}

export function getModelName(model: ModelPriceEntry): string {
  return model.model || model.id || ''
}

export function getModelPlatform(model: ModelPriceEntry): string {
  return model.platform || model.provider || ''
}

export function getModelPrices(model: ModelPriceEntry): ModelPriceLine[] {
  return model.prices || model.priceFields || []
}

export function getModelGroups(model: ModelPriceEntry): ModelPriceGroup[] {
  return model.groups || model.badges || []
}

export function getGroupLabel(group: ModelPriceGroup): string {
  return group.name || group.label || ''
}

export function getGroupNote(group: ModelPriceGroup): string {
  return group.note || group.description || ''
}
