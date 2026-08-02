import { describe, expect, it } from "vitest";
import { t } from "./i18n";

describe("translations", () => {
  it("switches core navigation and status labels", () => {
    expect(t("en", "activity")).toBe("My activity");
    expect(t("de", "activity")).toBe("Meine Aktivitäten");
    expect(t("de", "onBreak")).toBe("Pause");
  });
});
