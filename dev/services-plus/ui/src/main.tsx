import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import App from "./App";
import "./styles.css";

// The page is hidden by default (see styles.css) so it never appears on top of the
// game before LB Phone shows it. Outside LB Phone (browser preview) nothing will
// ever make it visible, so reveal it here immediately.
if (!window.fetchNui) document.body.style.visibility = "visible";

createRoot(document.getElementById("root")!).render(<StrictMode><App /></StrictMode>);
