import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'
import { useI18n } from '../../lib/i18n.jsx'
import FormField from '../../components/FormField.jsx'

export default function ServiceSettingsTab() {
  const { t } = useI18n()
  const [graceMinutes, setGraceMinutes] = useState('5')
  const [loading, setLoading] = useState(true)
  const [notice, setNotice] = useState('')
  const [saving, setSaving] = useState(false)
  const savingLock = useRef(false)

  useEffect(() => {
    fetchNui('admin:getServiceSettings').then((result) => {
      if (result) setGraceMinutes(String(result.activeRequestDisconnectGraceMinutes))
      setLoading(false)
    })
  }, [])

  const save = async () => {
    if (savingLock.current) return
    const value = Number(graceMinutes)
    if (!Number.isInteger(value) || value < 1 || value > 60) {
      setNotice(t('Enter a whole number between 1 and 60 minutes.'))
      return
    }

    savingLock.current = true
    setSaving(true)
    try {
      const ok = await fetchNui('admin:updateServiceSettings', {
        activeRequestDisconnectGraceMinutes: value,
      })
      setNotice(t(ok ? 'Settings saved.' : 'Could not save settings.'))
    } catch {
      setNotice(t('Could not save settings.'))
    } finally {
      savingLock.current = false
      setSaving(false)
    }
  }

  return (
    <div className="tab-panel">
      <div className="settings-section">
        <div className="section-title">{t('Active request disconnect grace period')}</div>
        <div className="hint">
          {t('If an assigned employee does not reconnect within this time, their active request is cancelled automatically.')}
        </div>
        <FormField label={t('Grace period in minutes')}>
          <input className="search-input" type="number" min="1" max="60" step="1" value={graceMinutes} disabled={loading || saving} onChange={(event) => setGraceMinutes(event.target.value)} />
        </FormField>
        <button className="login-button" disabled={loading || saving} aria-busy={saving} onClick={save}>{t('Save settings')}</button>
        {notice && <div className="notice">{notice}</div>}
      </div>
    </div>
  )
}
