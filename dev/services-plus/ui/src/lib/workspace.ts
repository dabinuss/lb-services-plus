import type { WorkspaceSection } from "../types";

export const appendUnique = <T extends { id: number }>(current: T[], incoming: T[]) => {
  const known = new Set(current.map((item) => item.id));
  return [...current, ...incoming.filter((item) => !known.has(item.id))];
};

type Token = { epoch: number; revision: number; section?: WorkspaceSection };

export class WorkspaceRequestGate {
  private epoch = 0;
  private revision = 0;
  private sectionRevisions: Partial<Record<WorkspaceSection, number>> = {};

  begin(section?: WorkspaceSection): Token {
    this.revision += 1;
    if (!section) {
      this.epoch += 1;
      this.sectionRevisions = {};
      return { epoch: this.epoch, revision: this.revision };
    }
    this.sectionRevisions[section] = this.revision;
    return { epoch: this.epoch, revision: this.revision, section };
  }

  isCurrent(token: Token) {
    if (token.epoch !== this.epoch) return false;
    return token.section ? this.sectionRevisions[token.section] === token.revision : this.revision === token.revision;
  }
}
