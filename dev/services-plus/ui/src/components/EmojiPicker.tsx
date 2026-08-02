export const MESSAGE_EMOJIS = ["👍", "❤️", "😂", "😮", "😢", "🚗", "💵", "🚨", "🔧", "🍔"] as const;

interface Props { onSelect: (emoji: string) => void; label: string; }

export function EmojiPicker({ onSelect, label }: Props) {
  return <div className="emoji-picker" role="group" aria-label={label}>{MESSAGE_EMOJIS.map((emoji) => <button type="button" key={emoji} onClick={() => onSelect(emoji)} aria-label={`${label}: ${emoji}`}>{emoji}</button>)}</div>;
}
