# Step 0001 - Customer, Order and Payment

Status: Integration CI passed on Ruby 3.3 and 3.4 with Rails 8.1; browser checks pending.

## Demo application
- Organization owns Customers.
- Customer has_many Orders, Order belongs_to Customer.
- Order has_many Payments, Payment belongs_to Order.
- Two organizations with isolated seed records, plus demo-only HTTP Basic authentication.

## Rekorra gem
- Resource registry and explicit fields DSL.
- Index, Show, New, Create, Edit, Update and Destroy in server-rendered HTML.
- Search, sort and pagination with allowlists.
- Scoped records, related records, and foreign-key selection.
- Batched belongs_to lookups to avoid N+1 on index.
- Configurable Ruby renderer per field.

## Security
- Every resource action uses authorization adapters.
- All record queries use scope adapters.
- Associations and user-selectable belongs_to targets are scoped.
- The demo never installs authentication or policies into the host application.

## Verification checklist
- [x] Rails 8 boot and migration
- [x] CRUD without JavaScript
- [x] Customer/Order/Payment links
- [x] Tenant isolation and unauthorized association
- [x] SQL query budget
- [x] Propshaft CSS loaded
- [ ] Responsive viewport screenshots
- [x] Renderer override test

## Known limitations
- Association selector is limited to 100 records.
- Basic record fields only; no attachment upload, enums, polymorphic relations or auditing yet.
- The demo policy scope is a reference only; production apps must implement their own.

Verified in [GitHub Actions run 40583138105](https://github.com/sergii/rekorra/actions/runs/40583138105): Ruby 3.3/3.4, 15 tests, 58 assertions, 0 failures. Browser screenshot and compatibility gates remain pending.
