import { t, type Locale } from "../lib/i18n";

interface Props { message: string; locale: Locale; busy?: boolean; onConfirm: () => void; onCancel: () => void; }

// window.confirm() opens a native OS-level dialog outside the game/NUI frame - it can
// steal focus from the game and render behind everything. This renders inside the app
// instead, same as every other overlay here.
export function ConfirmDialog({ message, locale, busy, onConfirm, onCancel }: Props) {
  return <div className="editor-overlay" role="alertdialog" aria-modal="true"><section className="confirm-dialog">
    <p>{message}</p>
    <div><button type="button" onClick={onCancel} disabled={busy}>{t(locale, "cancel")}</button><button type="button" className="danger" onClick={onConfirm} disabled={busy}>{t(locale, "confirm")}</button></div>
  </section></div>;
}
