Feature: KYB Document Review
  As a platform administrator
  I want to review uploaded KYB documents and complete the review
  So that entity admin accounts can be fully activated

  Background:
    Given an entity admin "Jane Thornton" has completed the onboarding wizard
    And user "user-jane-001" has status "pending_kyb"
    And org "org-acme-001" has uploaded 2 KYB documents

  Scenario: Admin views KYB documents in the access request drawer
    Given I am logged in as a super_admin
    When I open the access request drawer for "Jane Thornton"
    Then I see a "KYB Documents" section
    And I see 2 uploaded documents listed with their types and upload dates
    And I see a "Complete KYB Review" action button

  Scenario: Admin completes KYB review and user is activated
    Given I am logged in as a super_admin
    When I open the access request drawer for "Jane Thornton"
    And I click "Complete KYB Review"
    Then the KYBReviewCompleted event is recorded for org "org-acme-001"
    And the OnboardingProcessManager activates user "user-jane-001"
    And the user "user-jane-001" has status "active"
    And a welcome email is dispatched for "user-jane-001"

  Scenario: Admin cannot complete KYB review without all required documents
    Given org "org-acme-001" is missing required document "certificate_of_incorporation"
    When I click "Complete KYB Review"
    Then I see an error "Required documents are missing: certificate_of_incorporation"
    And no KYBReviewCompleted event is recorded

  Scenario: KYB review completion is idempotent
    Given the KYBReviewCompleted event has already been recorded for org "org-acme-001"
    When the CompleteKYBReview command is dispatched again for org "org-acme-001"
    Then the aggregate returns an error "kyb_already_completed"
    And no duplicate event is emitted
