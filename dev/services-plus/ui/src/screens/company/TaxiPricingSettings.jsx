import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import { showToast } from '../../lib/toast.js'
import { useI18n } from '../../lib/i18n.jsx'
import FormField from '../../components/FormField.jsx'

const BILLING_MODE_OPTIONS = [
  { key: 'per_minute', label: 'Per minute' },
  { key: 'per_100m', label: 'Per 100m' },
]

// The Taxameter section of the company settings screen - the settings-side
// half of the taxi request type's Taxameter feature, whose server module
// and dispatch card live under request-types/taxi/ (see
// request-types/taxi/server.lua). Kept as its own component, not moved
// physically next to that folder, since ui/src is its own Vite workspace
// with its own build/import root - see SettingsTab.jsx for how it's used.
//
// Renders nothing when this company's category has no request type with the
// taxi_pricing feature turned on by an admin - empty for every business
// type except taxi companies.
export default function TaxiPricingSettings({ disabled = false }) {
  const { t } = useI18n()
  const [taxiPricing, setTaxiPricing] = useState([])
  const [saving, setSaving] = useState(false)
  const saveLock = useRef(false)
  const committedPricing = useRef([])

  useEffect(() => {
    fetchNui('getTaxiPricingSettings').then((result) => {
      if (!result) return
      committedPricing.current = result
      setTaxiPricing(result)
    })
  }, [])

  if (taxiPricing.length === 0) return null

  // Same optimistic-with-revert pattern as SettingsTab's own save(), scoped
  // to one request type's row since each has its own independent billing
  // config.
  const saveTaxiPricing = async (requestTypeId, patch) => {
    if (disabled || saveLock.current) return
    if (String(patch.rate).trim() === '' || !Number.isFinite(Number(patch.rate)) || Number(patch.rate) < 0) {
      showToast(t('Enter a valid non-negative rate.'), 'error')
      return
    }
    saveLock.current = true
    setSaving(true)
    const previous = committedPricing.current
    const normalized = { ...patch, rate: Number(patch.rate) }
    setTaxiPricing((prev) => prev.map((row) => (row.requestTypeId === requestTypeId ? { ...row, ...normalized } : row)))
    try {
      if (await fetchNui('updateTaxiPricingSettings', { requestTypeId, settings: normalized })) {
        committedPricing.current = previous.map((row) => (row.requestTypeId === requestTypeId ? { ...row, ...normalized } : row))
        return
      }
      setTaxiPricing(previous)
      showToast(t('Could not save that change. Try again.'), 'error')
    } catch {
      setTaxiPricing(previous)
      showToast(t('Could not save that change. Try again.'), 'error')
    } finally {
      saveLock.current = false
      setSaving(false)
    }
  }

  return (
    <>
      <div className="section-title compact-title">{t('Taxameter')}</div>
      {taxiPricing.map((pricing) => (
        <div key={pricing.requestTypeId} className="routing-row">
          <div className="routing-label">{t(pricing.requestTypeName)}</div>
          <div className="category-row subtab-row routing-options">
            {BILLING_MODE_OPTIONS.map((o) => (
              <button
                key={o.key}
                className={`category-chip${pricing.billingMode === o.key ? ' active' : ''}`}
                disabled={disabled || saving}
                onMouseDown={(event) => event.preventDefault()}
                onClick={() => saveTaxiPricing(pricing.requestTypeId, { billingMode: o.key, rate: pricing.rate })}
              >
                {t(o.label)}
              </button>
            ))}
          </div>
          <FormField label={t('Rate')} className="taxi-rate-field">
            <input
              className="search-input"
              type="number"
              min="0"
              step="0.1"
              value={pricing.rate}
              disabled={disabled || saving}
              onChange={(e) =>
                setTaxiPricing((prev) =>
                  prev.map((p) => (p.requestTypeId === pricing.requestTypeId ? { ...p, rate: e.target.value } : p)),
                )
              }
              onBlur={(e) => saveTaxiPricing(pricing.requestTypeId, { billingMode: pricing.billingMode, rate: Number(e.target.value) })}
            />
          </FormField>
        </div>
      ))}
    </>
  )
}
