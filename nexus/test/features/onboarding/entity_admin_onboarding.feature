Feature: Entity Admin Onboarding
  As an approved entity administrator
  I want to complete the full KYB onboarding wizard
  So that my organisation can access the Equinox treasury platform

  Background:
    Given an access request has been approved for "Jane Thornton" at "Acme Holdings Ltd"
    And a provisioned user exists with id "user-jane-001" email "jane@acme.com" role "org_admin" org_id "org-acme-001"
    And a valid biometric invitation token exists for user "user-jane-001"

  Scenario: Entity admin completes the full onboarding wizard
    Given Jane opens the invitation link with a valid token
    Then she sees the welcome introduction step
    When she proceeds past the welcome screen
    Then she sees the entity details form
    When she submits valid entity details:
      | field               | value                  |
      | legal_name          | Acme Holdings Ltd      |
      | country             | GB                     |
      | registration_number | 12345678               |
      | registered_address  | 1 Finance St London    |
      | tax_id              | GB123456789            |
      | industry            | financial_services     |
    Then the EntityProfileSubmitted event is recorded for org "org-acme-001"
    And she sees the beneficial ownership form
    When she declares a beneficial owner:
      | field               | value     |
      | name                | John Acme |
      | nationality         | GB        |
      | ownership_percent   | 60        |
    Then the UBOsDeclared event is recorded for org "org-acme-001"
    And she sees the document upload form
    When she uploads a document of type "certificate_of_incorporation"
    And she uploads a document of type "proof_of_address"
    Then the KYBDocumentUploaded event is recorded twice for org "org-acme-001"
    And she sees the terms and agreements step
    When she accepts the terms as "Jane Thornton" with title "Group Treasurer"
    Then the TermsAccepted event is recorded for user "user-jane-001"
    And she sees the biometric anchor step
    When she completes biometric enrollment
    Then she sees the pending KYB review holding page
    And the user "user-jane-001" has status "pending_kyb"

  Scenario: Entity admin cannot skip entity details
    Given Jane opens the invitation link with a valid token
    And she is on the entity details step
    When she submits entity details with a missing required field "legal_name"
    Then the entity details form shows a validation error on "legal_name"
    And no EntityProfileSubmitted event is recorded

  Scenario: Entity admin cannot accept terms without scrolling to the bottom
    Given Jane opens the invitation link with a valid token
    And she is on the terms step
    Then the accept terms button is disabled
    When she scrolls the terms document to the bottom
    Then the accept terms button is enabled

  Scenario: Entity admin cannot proceed to biometric without accepting terms
    Given Jane opens the invitation link with a valid token
    And she is on the biometric step without having accepted terms
    Then she is redirected back to the terms step

  Scenario: Invitation token is expired
    Given an expired biometric invitation token for user "user-jane-001"
    When Jane opens the invitation link with the expired token
    Then she is redirected to the home page

  Scenario: Entity profile already submitted by a colleague from the same org
    Given an entity profile already exists for org "org-acme-001"
    And a second user "Bob" from org "org-acme-001" opens a valid invitation link
    Then Bob skips the entity details step
    And Bob proceeds directly to the beneficial ownership step
