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
  const [state, setState] = useState('form') // form | sending | sent | failed

  useEffect(() => {
    fetchNui('getRequestTypes', { categoryId: company.categoryId }).then((result) => {
      const list = result || []
      setTypes(list)
      if (list.length === 1) setType(list[0])
    })
  }, [company])

  const submit = async () => {
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

    setState('sent')
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

          {type.passenger_count === 1 && (
            <input
              className="search-input"
              type="number"
              min="1"
              placeholder="Passenger count"
              value={passengerCount}
              onChange={(e) => setPassengerCount(e.target.value)}
            />
          )}

          {type.description_enabled === 1 && (
            <input
              className="search-input"
              placeholder="Note (optional)"
              value={description}
              onChange={(e) => setDescription(e.target.value)}
            />
          )}

          <button className="login-button" onClick={submit}>
            Send request
          </button>
        </div>
      )}

      {state === 'sending' && <div className="empty-state">Sending…</div>}
      {state === 'sent' && <div className="empty-state">Request sent!</div>}
      {state === 'failed' && <div className="empty-state">Nobody available right now.</div>}
    </Sheet>
  )
}
