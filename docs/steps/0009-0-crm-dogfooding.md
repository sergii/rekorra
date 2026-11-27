# Step 0009.0 - CRM dogfooding and navigation foundation

## Intent

Use a real Rails CRM domain to develop Rekorra by using Rekorra itself. Keep the existing test/dummy host and legacy commerce fixtures: worker, outbox, access-audit and existing tests rely on them. CRM is the new product-facing demo, not a replacement for regression coverage.

## First slice

- Crm::Lead and Crm::Onboarding ActiveRecord models, migrations and explicit read-only resources.
- Synthetic leads with a sales lifecycle and follow-up dates; onboarding records with independent stage and health, time in stage, assignment label and finding text.
- Seeded Acme scenario: started healthy, two dispatched exceptions (one unknown outcome and one explicit rejection), one overdue confirmation after eight days, one confirmed. A separate Globex lead tests isolation.
- Opt-in navigation_strategy :namespace or :alphabetical; per-resource group/position/hidden metadata, nested native details and current link. Grouping does not grant permissions. No JS needed. Sidebar disclosure collapses content, not yet a full icon rail/focus mode.
- Existing host's demo HTTP Basic identity is organization-level, not individual staff. Assigned-to strings are synthetic labels, not identity or permission mappings. Read-only CRM resources avoid inventing write policies before staff identities and domain services exist.
- New integration tests specify navigation, filtering, cross-tenant read rejection and denied editing.

## Dogfood loop

1. Implement a small CRM business capability (lead qualification, follow-up, customer onboarding, interaction history, support case or simulated external confirmation) in host Rails models/services.
2. Observe and operate it using generic Rekorra resources, not CRM-specific engine code.
3. When a limitation appears, record the case, generalize a gem feature, implement and test it, then wire the CRM example to that feature.
4. Keep real Chrome checks and negative security tests; use synthetic data only.

## Next CRM slices

Organizations/companies, contacts and interactions; lead qualification and ownership; follow-up tasks; onboarding pipeline with simulator for missing response/webhook; customer support queue; staff accounts and roles. Use explicit host service transitions and test fake providers locally. No real email or external customer messages.

## Try

From test/dummy after bundle install:

    bundle exec rails db:prepare db:seed
    REKORRA_DEMO_PASSWORD=local-test-password bundle exec rails server

Use acme or globex as username and the configured password. Visit /backoffice/resources/crm_leads and /backoffice/resources/crm_onboardings. Existing /backoffice is still the resource catalog.

Run from repository root:

    RAILS_ENV=test bundle exec ruby test/dummy/bin/rails db:prepare
    bundle exec ruby -Itest test/crm_dogfood_navigation_test.rb
    bundle exec rake test

Validation status: implementation and test cases proposed in this slice; execution/CI pending. No Kanban renderer, Inspector, standalone assets, Rails 7 support, staff authentication or MFA implemented in this step.
