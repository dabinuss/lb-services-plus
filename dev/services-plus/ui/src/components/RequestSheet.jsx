import { useEffect, useState } from 'react'
import { fetchNui } from '../lib/nui.js'
import Sheet from './Sheet.jsx'

// Create a request (plan §11-14): only asks for what the chosen request type
// actually needs. Location is automatic - never a field here (plan §14).
export default function RequestSheet({ company, onClose }) {
  const [types, setTypes] = useState(null)
  const [type, setType] = useState(null)
  const [passengerCount, setPassengerCount] = useState('')
  const [description, setDescription] = useState('')
  const [state, setState] = useState('form') // form | sending | sent | queued | failed
  const passengerMode = type?.passenger_mode || (type?.passenger_count === 1 ? 'required' : 'disabled')
  const noteMode = type?.note_mode || (type?.description_enabled === 1 ? 'optional' : 'disabled')
  const countLabel = type?.count_label || 'Passenger count'

  useEffect(() => {
    fetchNui('getRequestTypes', { categoryId: company.categoryId }).then((result) => {
      const list = result || []
      setTypes(list)
      if (list.length === 1) setType(list[0])
    })
  }, [company])

  const submit = async () => {
    if (passengerMode === 'required' && !passengerCount) return
    if (noteMode === 'required' && !description.trim()) return
    setState('sending')
    const result = await fetchNui('createRequest', {
      companyId: company.id,
      requestTypeId: type.id,
      passengerCount: passengerCount ? Number(passengerCount) : undefined,
      description: description || undefined,
    })

    if (!result) {
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
    <Sheet title={`Request · ${company.name}`} onClose={onClose}>
      {types === null && <div className="empty-state">Loading…</div>}

      {types !== null && !type && (
        <>
          {types.length === 0 && <div className="empty-state">No request types available.</div>}
          {types.map((t) => (
            <button key={t.id} className="sheet-option" onClick={() => setType(t)}>
              {t.name}
            </button>
          ))}
        </>
      )}

      {type && state === 'form' && (
        <div className="request-form">
          <div className="request-form-title">{type.name}</div>
          {type.description && <div className="request-form-description">{type.description}</div>}

          {passengerMode !== 'disabled' && (
            <input
              className="search-input"
              type="number"
              min="1"
              placeholder={`${countLabel}${passengerMode === 'optional' ? ' (optional)' : ' (required)'}`}
              value={passengerCount}
              onChange={(e) => setPassengerCount(e.target.value)}
              required={passengerMode === 'required'}
            />
          )}

          {noteMode !== 'disabled' && (
            <input
              className="search-input"
              placeholder={`Additional note${noteMode === 'required' ? ' (required)' : ' (optional)'}`}
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              required={noteMode === 'required'}
            />
          )}

          <button
            className="login-button"
            disabled={(passengerMode === 'required' && !passengerCount) || (noteMode === 'required' && !description.trim())}
            onClick={submit}
          >
            Send request
          </button>
        </div>
      )}

      {state === 'sending' && <div className="empty-state">Sending…</div>}
      {state === 'sent' && <div className="empty-state">Request sent!</div>}
      {state === 'queued' && <div className="empty-state">Nobody available right now - request queued, check Activity later.</div>}
      {state === 'failed' && <div className="empty-state">Could not send this request.</div>}
    </Sheet>
  )
}
