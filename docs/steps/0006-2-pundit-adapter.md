# Step 0006.2 — Optional Pundit Bridge

Status: Ruby 3.3/3.4 integration CI green.

Rekorra::Authorization::Adapters::Pundit implements authorize_with(actor, subject, action) via Pundit.policy, denying absent predicates. Rekorra::Authorization::Adapters::PunditScope implements scope_with(actor, model) via Pundit.policy_scope and **requires a relation for the requested ActiveRecord model**. Missing scopes fail closed, never falling back to Model.all.

Pundit 2.5.x is installed in the test-host Gemfile only; rekorra.gemspec has no Pundit dependency. Tests use real OrderPolicy and Scope with cross-tenant Orders.

Example host configuration:

```ruby
config.authorize_with = ->(actor, subject, action) {
  if subject.nil? && action == :access?
    actor.respond_to?(:admin?) && actor.admin?
  else
    Rekorra::Authorization::Adapters::Pundit.new.call(actor, subject, action)
  end
}
config.scope_with = Rekorra::Authorization::Adapters::PunditScope.new
```

The host must implement global access?, resource predicates, SQL scopes and authentication; Pundit policy checks do not replace SQL tenant-scoping. [CI evidence](https://github.com/sergii/rekorra/actions/runs/40612793162).
