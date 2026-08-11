import './Frame.css'

// Dev-only chrome so `npm run dev` roughly resembles being inside the
// in-game phone. Never rendered when devMode is false.
export default function Frame({ children }) {
  return (
    <div className="dev-wrapper">
      <div className="frame-notch" />
      {children}
    </div>
  )
}
