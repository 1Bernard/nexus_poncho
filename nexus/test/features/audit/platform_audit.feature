Feature: Platform Audit Log
  As a compliance officer
  I want every significant action across all domains recorded in a single audit log
  So that I can answer "show me everything user X did across the entire platform"

  @audit
  Scenario: UserRegistered is captured in the platform audit log
    Given a user registers with email "audit_test@nexus.com"
    Then a platform audit log entry exists with:
      | field      | value           |
      | domain     | identity        |
      | event_type | user_registered |
    And the audit log entry records the user as the actor

  @audit
  Scenario: UserActivated is captured after activation
    Given a user registers with email "activate_audit@nexus.com"
    When the user is activated
    Then a platform audit log entry exists with:
      | field      | value          |
      | domain     | identity       |
      | event_type | user_activated |

  @audit
  Scenario: Replaying the same event does not create duplicate audit entries
    Given a user registers with email "idempotent_audit@nexus.com"
    Then exactly 1 platform audit log entry exists for that user with event_type "user_registered"
