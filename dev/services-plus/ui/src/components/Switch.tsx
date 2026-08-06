interface Props {
  checked: boolean;
  onChange: (checked: boolean) => void;
  disabled?: boolean;
  label?: string;
}

// Matches LB Phone's own native toggle switch exactly (pulled from its compiled
// Switch component: 3rem x 1.75rem pill, 1.5rem knob, same colors/timing) instead of
// a plain browser checkbox - every other LB Phone app uses this control for on/off
// settings, so ours should read the same rather than standing out as third-party.
export function Switch({ checked, onChange, disabled, label }: Props) {
  return <label className="switch" aria-label={label}>
    <input type="checkbox" checked={checked} disabled={disabled} onChange={(event) => onChange(event.target.checked)} />
    <span className="slider" />
  </label>;
}
