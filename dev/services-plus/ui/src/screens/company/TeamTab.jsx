import { useEffect, useState } from 'react'
import { fetchNui } from '../../lib/nui.js'

// Team overview (plan §24): everyone currently on duty, their status and
// which hotlines they've taken.
export default function TeamTab() {
  const [team, setTeam] = useState(null)

  useEffect(() => {
    fetchNui('getTeam').then((r) => r && setTeam(r))
  }, [])

  return (
    <div className="tab-panel">
      {team === null && <div className="empty-state">Loading…</div>}
      {team !== null && team.length === 0 && <div className="empty-state">Nobody on duty.</div>}

      <div className="team-list">
        {team?.map((member, i) => (
          <div key={i} className="team-row">
            <div className="team-info">
              <div className="team-name">{member.name}</div>
              <div className="team-grade">{member.gradeLabel}</div>
            </div>
            <div className="team-meta">
              <span className={`status-pill ${member.status} static`}>{member.status}</span>
              <div className="team-hotlines">{member.hotlines.join(', ') || '—'}</div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
