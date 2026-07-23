/*
Copyright (C) 2023-2026 QuantumNous

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program. If not, see <https://www.gnu.org/licenses/>.

For commercial licensing, please contact support@quantumnous.com
*/
import { useState, useMemo, useCallback } from 'react'
import { useTranslation } from 'react-i18next'
import { cn } from '@/lib/utils'
import { formatBillingCurrencyFromUSD } from '@/lib/currency'
import { QUOTA_TYPE_VALUES } from '../constants'
import type { PricingModel, TokenUnit } from '../types'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface CalculatorResult {
  model: PricingModel
  inputCost: number
  outputCost: number
  cacheCost: number
  totalCost: number
}

interface PriceCalculatorProps {
  models: PricingModel[]
  priceRate: number
  usdExchangeRate: number
  tokenUnit: TokenUnit
  className?: string
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

interface TokenPreset {
  label: string
  inputTokens: number
  outputTokens: number
}

const PRESETS: TokenPreset[] = [
  { label: '1K / 500', inputTokens: 1000, outputTokens: 500 },
  { label: '10K / 5K', inputTokens: 10000, outputTokens: 5000 },
  { label: '100K / 50K', inputTokens: 100000, outputTokens: 50000 },
  { label: '1M / 500K', inputTokens: 1000000, outputTokens: 500000 },
  { label: '10M / 5M', inputTokens: 10000000, outputTokens: 5000000 },
]

// Matches the backend pricing formula in lib/price.ts (calculateTokenPrice).
// Keep in sync: base = model_ratio * 2 * groupRatio
// input = base, output = base * completion_ratio
function calcModelPrice(
  model: PricingModel,
  type: 'input' | 'output' | 'cache'
): number | null {
  if (model.quota_type === QUOTA_TYPE_VALUES.REQUEST) return null

  const enableGroups = Array.isArray(model.enable_groups)
    ? model.enable_groups
    : []
  const groupRatio = model.group_ratio || {}

  let minRatio = 1
  if (enableGroups.length > 0) {
    let min = Number.POSITIVE_INFINITY
    for (const g of enableGroups) {
      const r = groupRatio[g]
      if (r !== undefined && r < min) min = r
    }
    if (Number.isFinite(min)) minRatio = min
  }

  const base = model.model_ratio * 2 * minRatio

  switch (type) {
    case 'input':
      return base
    case 'output':
      return base * model.completion_ratio
    case 'cache':
      return model.cache_ratio != null ? base * model.cache_ratio : null
  }
}

// ---------------------------------------------------------------------------
// Component
// ---------------------------------------------------------------------------

export function PriceCalculator(props: PriceCalculatorProps) {
  const { t } = useTranslation()
  const [inputTokens, setInputTokens] = useState(100000)
  const [outputTokens, setOutputTokens] = useState(50000)
  const [expanded, setExpanded] = useState(false)
  const [sortBy, setSortBy] = useState<'total' | 'name' | 'vendor'>('total')
  const [filterText, setFilterText] = useState('')

  const applyRate = useCallback(
    (price: number): number => {
      const rate = props.priceRate || 1
      const exchange = props.usdExchangeRate || 1
      return (price * rate) / exchange
    },
    [props.priceRate, props.usdExchangeRate]
  )

  const results = useMemo<CalculatorResult[]>(() => {
    return props.models
      .filter((m) => m.quota_type === QUOTA_TYPE_VALUES.TOKEN)
      .map((model) => {
        const inputUnitPrice = calcModelPrice(model, 'input')
        const outputUnitPrice = calcModelPrice(model, 'output')
        const cacheUnitPrice = calcModelPrice(model, 'cache')

        const inputCost =
          inputUnitPrice != null
            ? (inputTokens * inputUnitPrice) / 1_000_000
            : 0
        const outputCost =
          outputUnitPrice != null
            ? (outputTokens * outputUnitPrice) / 1_000_000
            : 0
        const cacheCost =
          cacheUnitPrice != null
            ? (inputTokens * cacheUnitPrice) / 1_000_000
            : 0

        return {
          model,
          inputCost: applyRate(inputCost),
          outputCost: applyRate(outputCost),
          cacheCost: applyRate(cacheCost),
          totalCost: applyRate(inputCost + outputCost),
        }
      })
      .filter((r) => r.totalCost > 0 || r.inputCost > 0)
  }, [props.models, inputTokens, outputTokens, applyRate])

  const filteredResults = useMemo(() => {
    if (!filterText.trim()) return results

    const q = filterText.toLowerCase()
    return results.filter(
      (r) =>
        r.model.model_name.toLowerCase().includes(q) ||
        (r.model.vendor_name || '').toLowerCase().includes(q)
    )
  }, [results, filterText])

  const sortedResults = useMemo(() => {
    const sorted = [...filteredResults]
    switch (sortBy) {
      case 'total':
        sorted.sort((a, b) => a.totalCost - b.totalCost)
        break
      case 'name':
        sorted.sort((a, b) =>
          a.model.model_name.localeCompare(b.model.model_name)
        )
        break
      case 'vendor':
        sorted.sort((a, b) =>
          (a.model.vendor_name || '').localeCompare(
            b.model.vendor_name || ''
          )
        )
        break
    }
    return sorted
  }, [filteredResults, sortBy])

  const cheapest = sortedResults[0]

  return (
    <div
      className={cn(
        'rounded-xl border transition-all',
        props.className
      )}
      style={{
        borderColor: 'var(--m3-outline-variant)',
        background: 'var(--m3-surface)',
      }}
    >
      {/* Header — click to toggle */}
      <button
        type='button'
        onClick={() => setExpanded(!expanded)}
        className='flex w-full items-center justify-between px-4 py-3 sm:px-5 sm:py-4'
      >
        <div className='flex items-center gap-3'>
          <span
            className='flex h-9 w-9 items-center justify-center rounded-lg text-lg'
            style={{
              background: 'var(--m3-primary-container)',
              color: 'var(--m3-primary)',
            }}
          >
            🧮
          </span>
          <div className='text-left'>
            <h3 className='text-base font-semibold sm:text-lg'>
              {t('Cost Calculator')}
            </h3>
            <p className='text-muted-foreground text-xs sm:text-sm'>
              {t(
                'Estimate and compare costs across models for your usage'
              )}
            </p>
          </div>
        </div>
        <span
          className={cn(
            'text-muted-foreground text-lg transition-transform',
            expanded && 'rotate-180'
          )}
        >
          ▾
        </span>
      </button>

      {expanded && (
        <div className='border-t px-4 pb-4 sm:px-5 sm:pb-5'>
          {/* Input fields */}
          <div className='mt-4 grid gap-3 sm:grid-cols-2'>
            {/* Input tokens */}
            <div>
              <label className='mb-1.5 block text-xs font-medium'>
                {t('Input Tokens')}
              </label>
              <input
                type='number'
                min={0}
                value={inputTokens}
                onChange={(e) =>
                  setInputTokens(Math.max(0, Number(e.target.value)))
                }
                className='w-full rounded-lg border px-3 py-2 text-sm outline-none transition-colors focus:border-[var(--m3-primary)] focus:ring-1 focus:ring-[var(--m3-primary)]'
                style={{
                  borderColor: 'var(--m3-outline-variant)',
                  background: 'var(--m3-surface-1)',
                  color: 'var(--m3-on-surface)',
                }}
              />
            </div>

            {/* Output tokens */}
            <div>
              <label className='mb-1.5 block text-xs font-medium'>
                {t('Output Tokens')}
              </label>
              <input
                type='number'
                min={0}
                value={outputTokens}
                onChange={(e) =>
                  setOutputTokens(Math.max(0, Number(e.target.value)))
                }
                className='w-full rounded-lg border px-3 py-2 text-sm outline-none transition-colors focus:border-[var(--m3-primary)] focus:ring-1 focus:ring-[var(--m3-primary)]'
                style={{
                  borderColor: 'var(--m3-outline-variant)',
                  background: 'var(--m3-surface-1)',
                  color: 'var(--m3-on-surface)',
                }}
              />
            </div>
          </div>

          {/* Presets */}
          <div className='mt-3 flex flex-wrap gap-1.5'>
            {PRESETS.map((preset) => (
              <button
                key={preset.label}
                type='button'
                onClick={() => {
                  setInputTokens(preset.inputTokens)
                  setOutputTokens(preset.outputTokens)
                }}
                className={cn(
                  'rounded-md border px-2.5 py-1 text-xs font-medium transition-colors',
                  inputTokens === preset.inputTokens &&
                    outputTokens === preset.outputTokens
                    ? 'border-[var(--m3-primary)] text-[var(--m3-primary)]'
                    : 'text-muted-foreground hover:text-foreground'
                )}
                style={{
                  borderColor:
                    inputTokens === preset.inputTokens &&
                    outputTokens === preset.outputTokens
                      ? 'var(--m3-primary)'
                      : 'var(--m3-outline-variant)',
                  color:
                    inputTokens === preset.inputTokens &&
                    outputTokens === preset.outputTokens
                      ? 'var(--m3-primary)'
                      : undefined,
                }}
              >
                {preset.label}
              </button>
            ))}
          </div>

          {/* Results header */}
          <div className='mt-5 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between'>
            <div className='flex items-center gap-2'>
              <h4 className='text-sm font-medium'>
                {t('Comparison Results')}
              </h4>
              <span
                className='rounded-full px-2 py-0.5 text-xs'
                style={{
                  background: 'var(--m3-secondary-container)',
                  color: 'var(--m3-on-secondary-container)',
                }}
              >
                {sortedResults.length}
              </span>
            </div>

            <div className='flex items-center gap-2'>
              {/* Search filter */}
              <input
                type='text'
                placeholder={t('Filter models...')}
                value={filterText}
                onChange={(e) => setFilterText(e.target.value)}
                className='w-36 rounded-md border px-2.5 py-1 text-xs outline-none transition-colors focus:border-[var(--m3-primary)] sm:w-44'
                style={{
                  borderColor: 'var(--m3-outline-variant)',
                  background: 'var(--m3-surface-1)',
                  color: 'var(--m3-on-surface)',
                }}
              />

              {/* Sort selector */}
              <select
                value={sortBy}
                onChange={(e) =>
                  setSortBy(e.target.value as typeof sortBy)
                }
                className='rounded-md border px-2 py-1 text-xs outline-none'
                style={{
                  borderColor: 'var(--m3-outline-variant)',
                  background: 'var(--m3-surface-1)',
                  color: 'var(--m3-on-surface)',
                }}
              >
                <option value='total'>{t('Sort by Cost')}</option>
                <option value='name'>{t('Sort by Name')}</option>
                <option value='vendor'>{t('Sort by Vendor')}</option>
              </select>
            </div>
          </div>

          {/* Cheapest model highlight */}
          {cheapest && (
            <div
              className='mt-3 rounded-lg border px-3 py-2.5 sm:px-4'
              style={{
                borderColor: 'var(--m3-primary)',
                background:
                  'color-mix(in srgb, var(--m3-primary-container) 30%, transparent)',
              }}
            >
              <div className='flex items-center justify-between'>
                <div>
                  <span
                    className='text-xs font-medium'
                    style={{ color: 'var(--m3-primary)' }}
                  >
                    {t('Most Affordable')}
                  </span>
                  <span className='ml-2 text-sm font-semibold'>
                    {cheapest.model.model_name}
                  </span>
                  {cheapest.model.vendor_name && (
                    <span className='text-muted-foreground ml-1.5 text-xs'>
                      {cheapest.model.vendor_name}
                    </span>
                  )}
                </div>
                <span
                  className='text-base font-bold sm:text-lg'
                  style={{ color: 'var(--m3-primary)' }}
                >
                  {formatBillingCurrencyFromUSD(cheapest.totalCost, {
                    digitsLarge: 4,
                    digitsSmall: 6,
                    abbreviate: false,
                  })}
                </span>
              </div>
            </div>
          )}

          {/* Comparison table */}
          <div className='mt-3 overflow-x-auto'>
            <table className='w-full text-sm'>
              <thead>
                <tr
                  className='text-muted-foreground border-b text-left text-xs'
                  style={{
                    borderColor: 'var(--m3-outline-variant)',
                  }}
                >
                  <th className='pb-2 pr-3 font-medium'>
                    {t('Model')}
                  </th>
                  <th className='pb-2 pr-3 font-medium'>
                    {t('Provider')}
                  </th>
                  <th className='pb-2 pr-3 text-right font-medium'>
                    {t('Input Cost')}
                  </th>
                  <th className='pb-2 pr-3 text-right font-medium'>
                    {t('Output Cost')}
                  </th>
                  <th className='pb-2 pr-3 text-right font-medium'>
                    {t('Cache')}
                  </th>
                  <th className='pb-2 text-right font-medium'>
                    {t('Total')}
                  </th>
                </tr>
              </thead>
              <tbody>
                {sortedResults.slice(0, 50).map((r) => (
                  <tr
                    key={r.model.id || r.model.model_name}
                    className='border-b transition-colors hover:bg-[var(--m3-surface-1)]'
                    style={{
                      borderColor: 'var(--m3-outline-variant)',
                    }}
                  >
                    <td className='max-w-[160px] truncate py-2 pr-3 font-medium'>
                      {r.model.model_name}
                    </td>
                    <td className='text-muted-foreground py-2 pr-3 text-xs'>
                      {r.model.vendor_name || '-'}
                    </td>
                    <td className='py-2 pr-3 text-right tabular-nums'>
                      {formatBillingCurrencyFromUSD(r.inputCost, {
                        digitsLarge: 4,
                        digitsSmall: 6,
                        abbreviate: false,
                      })}
                    </td>
                    <td className='py-2 pr-3 text-right tabular-nums'>
                      {formatBillingCurrencyFromUSD(r.outputCost, {
                        digitsLarge: 4,
                        digitsSmall: 6,
                        abbreviate: false,
                      })}
                    </td>
                    <td className='py-2 pr-3 text-right tabular-nums'>
                      {r.cacheCost > 0
                        ? formatBillingCurrencyFromUSD(r.cacheCost, {
                            digitsLarge: 4,
                            digitsSmall: 6,
                            abbreviate: false,
                          })
                        : '-'}
                    </td>
                    <td className='py-2 text-right font-semibold tabular-nums'>
                      {formatBillingCurrencyFromUSD(r.totalCost, {
                        digitsLarge: 4,
                        digitsSmall: 6,
                        abbreviate: false,
                      })}
                    </td>
                  </tr>
                ))}

                {sortedResults.length === 0 && (
                  <tr>
                    <td
                      colSpan={6}
                      className='text-muted-foreground py-8 text-center text-sm'
                    >
                      {filterText.trim()
                        ? t('No models match your filter')
                        : t('No token-based models available')}
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Footer note */}
          {sortedResults.length > 50 && (
            <p className='text-muted-foreground mt-2 text-center text-xs'>
              {t(
                'Showing top 50 of {{total}} results. Use filter to narrow down.',
                { total: sortedResults.length }
              )}
            </p>
          )}

          <p
            className='mt-3 text-center text-xs'
            style={{ color: 'var(--m3-on-surface-variant)' }}
          >
            {t(
              'Prices are estimates based on current model pricing. Actual costs may vary.'
            )}
          </p>
        </div>
      )}
    </div>
  )
}
