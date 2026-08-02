# Agent Instructions

Before making changes, always read and follow these project documents first:

1. `FiveM_LB-Phone_Development_Guidelines.md`
2. `ServicesPlus_Complete_Development_Plan.md`

The guidelines define the mandatory technical standards for LB Phone and FiveM development.

The Services+ development plan defines the product scope, architecture, phases, compatibility requirements, testing requirements and release criteria.

All implementation, review, documentation and testing work must stay consistent with both documents.

If the two documents appear to conflict, prefer the stricter requirement and document the decision before implementation.

Core rules:

- Keep code and technical documentation in English.
- Use official LB Phone exports and supported FiveM APIs.
- Keep Services+ as a separate resource.
- Do not modify or monkey-patch `lb-phone` or unrelated third-party resources.
- Validate every important decision server-side.
- Never trust client-provided data.
- Avoid polling when event-driven updates are possible.
- Minimize network payloads and database traffic.
- Preserve compatibility with LB Phone, common frameworks and common server resources.
- Ensure restart safety for Services+, LB Phone and relevant integrations.
- Every NUI callback must always return a response.
- Every write or expensive action must be validated and rate-limited.
- Test and review continuously, not only at release time.
