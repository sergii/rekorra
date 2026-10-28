# Step 0006.4 — Native Typed Form Controls

Status: Ruby 3.3/3.4 and Chrome CI green; human device QA pending.

## Delivered

- Real host ActiveRecord column types drive native Rails form controls: checkbox (boolean), integer/decimal number, date, datetime-local, textarea and text.
- Existing Rails enum selects, scoped belongs_to choices and field-level security remain unchanged.
- Syntactic validation of boolean, numeric, date and datetime submissions occurs before attribute assignment, avoiding silent malformed-value coercion.
- The demonstration CaseRecord gains flagged, due_on, estimated_hours, reviewed_at and notes fields, each declared through ordinary form field syntax.
- No runtime gem dependency, JavaScript framework or separate type schema.

## Verification

- [x] Native controls on New/Edit pages.
- [x] Ruby 3.3 and 3.4 tests with real Rails CRUD and CSRF.
- [x] Checkbox false, nullable values and valid decimal/date/time submission.
- [x] Forged invalid typed inputs rejected without partial changes.
- [x] Cross-tenant association assignment rejected.
- [x] Chrome 390 px mobile form rendering without horizontal overflow.
- [ ] Human mobile Safari, VoiceOver and locale/timezone review.

CI evidence: [GitHub Actions run 40650265053](https://github.com/sergii/rekorra/actions/runs/40650265053): Ruby 3.3/3.4 each 142 tests, 850 assertions, zero failures/errors; Chrome 8 tests, 58 assertions, zero failures/errors.

## Boundaries

Datetime-local omits an explicit timezone; the host Rails timezone determines interpretation. Model validation retains responsibility for domain limits, decimal precision and required fields. Text/date inputs are not generic file, polymorphic or rich-text widgets. Structured validation is not a substitute for authorization or domain validation.

See ADR 0020 for the dependency and safety boundary.