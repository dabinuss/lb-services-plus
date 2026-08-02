import type { AppMessage } from "../types";

export function subscribeToNui(handler: (message: AppMessage) => void) {
  const listener = (event: MessageEvent<unknown>) => {
    if (!event.data || typeof event.data !== "object") return;
    const message = event.data as Partial<AppMessage>;
    if (typeof message.type !== "string" || !("payload" in message)) return;
    handler(message as AppMessage);
  };
  window.addEventListener("message", listener);
  return () => window.removeEventListener("message", listener);
}
