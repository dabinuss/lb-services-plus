import { useEffect, useRef, useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import Sheet from './Sheet.jsx'
import { useI18n } from '../lib/i18n.jsx'
import { requestTypeNoteMode, requestTypePassengerMode } from '../lib/database.js'
import FormField from './FormField.jsx'

// Create a request (plan §11-14): only asks for what the chosen request type
// actually needs. Location is automatic - never a field here (plan §14).
export default function RequestSheet({ company, onClose }) {
  const { t } = useI18n()
  const [types, setTypes] = useState(null)
  const [type, setType] = useState(null)
  const [passengerCount, setPassengerCount] = useState('')
  const [description, setDescription] = useState('')
  const [state, setState] = useState('form') // form | sending | sent | queued | failed
  const [loadError, setLoadError] = useState(false)
  const submittingRef = useRef(false)
  const passengerMode = requestTypePassengerMode(type)
  const noteMode = requestTypeNoteMode(type)
  const countLabel = type?.count_label || t('Passenger count')

  const loadTypes = async () => {
    setTypes(null)
    setLoadError(false)
    try {
      const result = await fetchNui('getRequestTypes', { categoryId: company.categoryId })
      if (!Array.isArray(result)) throw new Error('request_types_unavailable')
      const list = result
      setTypes(list)
      if (list.length === 1) setType(list[0])
    } catch {
      setTypes([])
      setLoadError(true)
    }
  }

  useEffect(() => {
    loadTypes()
    // The selected company is the only input that changes the available types.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [company])

  const submit = async () => {
    if (submittingRef.current || !type) return
    if (passengerMode === 'required' && !passengerCount) return
    if (noteMode === 'required' && !description.trim()) return
    submittingRef.current = true
    setState('sending')
    let result = false
    try {
      result = await fetchNui('createRequest', {
        companyId: company.id,
        requestTypeId: type.id,
        passengerCount: passengerCount ? Number(passengerCount) : undefined,
        description: description || undefined,
      })
    } catch {
      result = false
    }

    if (!result) {
      submittingRef.current = false
      setState('failed')
      return
    }

    // The request is created and stays open either way (plan review round
    // 3 §7 - it's still findable later in the company's Requests tab) -
    // `reached` only says whether anyone was live-notified just now, it's
    // not a success/failure flag. `if (!result)` alone used to treat a
    // real { reached: false } object as truthy and always claim "sent!",
    // so nobody ever saw the "nobody available" case at all.
    setState(result.reached ? 'sent' : 'queued')
    setTimeout(onClose, 1100)
  }

  return (
    <Sheet title={t('Request · {company}', { company: company.name })} onClose={onClose}>
      {types === null && <div className="empty-state">{t('Loading request options…')}</div>}

      {loadError && (
        <div className="request-recovery">
          <div className="empty-state">{t('Could not load request options.')}</div>
          <button className="sheet-option" onClick={loadTypes}>{t('Try again')}</button>
        </div>
      )}

      {types !== null && !loadError && !type && (
        <>
          {types.length === 0 && <div className="empty-state">{t('No request types available.')}</div>}
          {types.map((item) => (
            <button key={item.id} className="sheet-option" onClick={() => setType(item)}>
              {t(item.name)}
            </button>
          ))}
        </>
      )}

      {type && state === 'form' && (
        <div className="request-form">
          <div className="request-form-title">{t(type.name)}</div>
          {type.description && <div className="request-form-description">{t(type.description)}</div>}

          {passengerMode !== 'disabled' && (
            <FormField label={`${countLabel} (${t(passengerMode === 'optional' ? 'optional' : 'required')})`}>
              <input className="search-input" type="number" min="1" value={passengerCount} onChange={(e) => setPassengerCount(e.target.value)} required={passengerMode === 'required'} />
            </FormField>
          )}

          {noteMode !== 'disabled' && (
            <FormField label={`${t('Additional note')} (${t(noteMode === 'required' ? 'required' : 'optional')})`}>
              <input className="search-input" value={description} onChange={(e) => setDescription(e.target.value)} required={noteMode === 'required'} />
            </FormField>
          )}

          <button
            className="login-button"
            disabled={(passengerMode === 'required' && !passengerCount) || (noteMode === 'required' && !description.trim())}
            onClick={submit}
            aria-busy={state === 'sending'}
          >
            {t('Send request')}
          </button>
          {types.length > 1 && (
            <button className="sheet-option" onClick={() => setType(null)}>{t('Choose another request type')}</button>
          )}
        </div>
      )}

      {state === 'sending' && <div className="empty-state">{t('Sending…')}</div>}
      {state === 'sent' && <div className="empty-state">{t('Request sent!')}</div>}
      {state === 'queued' && <div className="empty-state">{t('Nobody available right now - request queued, check Activity later.')}</div>}
      {state === 'failed' && (
        <div className="request-recovery">
          <div className="empty-state">{t('Could not send this request.')}</div>
          <button className="sheet-option" onClick={() => setState('form')}>{t('Try again')}</button>
          {types.length > 1 && (
            <button className="sheet-option" onClick={() => { setType(null); setState('form') }}>{t('Choose another request type')}</button>
          )}
        </div>
      )}
    </Sheet>
  )
}
