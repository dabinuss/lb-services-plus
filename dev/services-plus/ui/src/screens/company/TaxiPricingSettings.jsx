import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import { showToast } from '../../lib/toast.js'

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
export default function TaxiPricingSettings() {
  const [taxiPricing, setTaxiPricing] = useState([])

  useEffect(() => {
    fetchNui('getTaxiPricingSettings').then((r) => r && setTaxiPricing(r))
  }, [])

  if (taxiPricing.length === 0) return null

  // Same optimistic-with-revert pattern as SettingsTab's own save(), scoped
  // to one request type's row since each has its own independent billing
  // config.
  const saveTaxiPricing = async (requestTypeId, patch) => {
    const previous = taxiPricing
    setTaxiPricing((prev) => prev.map((t) => (t.requestTypeId === requestTypeId ? { ...t, ...patch } : t)))
    if (!(await fetchNui('updateTaxiPricingSettings', { requestTypeId, settings: patch }))) {
      setTaxiPricing(previous)
      showToast('Could not save that change. Try again.', 'error')
    }
  }

  return (
    <>
      <div className="section-title compact-title">Taxameter</div>
      {taxiPricing.map((t) => (
        <div key={t.requestTypeId} className="routing-row">
          <div className="routing-label">{t.requestTypeName}</div>
          <div className="category-row subtab-row routing-options">
            {BILLING_MODE_OPTIONS.map((o) => (
              <button
                key={o.key}
                className={`category-chip${t.billingMode === o.key ? ' active' : ''}`}
                onClick={() => saveTaxiPricing(t.requestTypeId, { billingMode: o.key, rate: t.rate })}
              >
                {o.label}
              </button>
            ))}
          </div>
          <input
            className="search-input"
            type="number"
            min="0"
            step="0.1"
            value={t.rate}
            onChange={(e) =>
              setTaxiPricing((prev) =>
                prev.map((p) => (p.requestTypeId === t.requestTypeId ? { ...p, rate: e.target.value } : p)),
              )
            }
            onBlur={(e) => saveTaxiPricing(t.requestTypeId, { billingMode: t.billingMode, rate: Number(e.target.value) })}
          />
        </div>
      ))}
    </>
  )
}
