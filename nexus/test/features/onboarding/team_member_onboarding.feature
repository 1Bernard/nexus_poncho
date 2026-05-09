Feature: Team Member Onboarding
  As a team member invited by an entity administrator
  I want to complete the shortened onboarding flow
  So that I can access the Equinox treasury platform

  Background:
    Given "Acme Holdings Ltd" with org_id "org-acme-001" has completed entity KYB
    And the org admin has invited "Bob Smith" with email "bob@acme.com" role "treasury_analyst"
    And a provisioned user exists with id "user-bob-001" email "bob@acme.com" role "treasury_analyst" org_id "org-acme-001"
    And a valid biometric invitation token exists for user "user-bob-001"

  Scenario: Team member completes the shortened onboarding flow
    Given Bob opens the invitation link with a valid token
    Then he sees the welcome screen showing organisation "Acme Holdings Ltd"
    And he sees his role "treasury_analyst" displayed on the welcome screen
    When he proceeds from the welcome screen
    Then he sees the personal terms step
    When he accepts the personal terms as "Bob Smith"
    Then the TermsAccepted event is recorded for user "user-bob-001"
    And he sees the biometric anchor step
    When he completes biometric enrollment
    Then he is redirected to "/vaults" immediately
    And the user "user-bob-001" eventually reaches status "active"

  Scenario: Team member does NOT see entity details or document upload steps
    Given Bob opens the invitation link with a valid token
    Then the step sequence does not include "entity_details"
    And the step sequence does not include "beneficial_owners"
    And the step sequence does not include "document_upload"

  Scenario: Team member invitation token is expired
    Given an expired biometric invitation token for user "user-bob-001"
    When Bob opens the invitation link with the expired token
    Then he is redirected to the home page

  Scenario: Team member cannot proceed without accepting terms
    Given Bob opens the invitation link with a valid token
    And he is on the biometric step without having accepted terms
    Then he is redirected back to the terms step
