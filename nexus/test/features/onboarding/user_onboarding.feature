Feature: Sovereign Onboarding
  As an invited user
  I want to register an account and complete the onboarding wizard
  So that I can securely access the Equinox treasury platform

  Scenario: Entity admin registers, completes KYB wizard, and awaits review
    Given a new user is registered with email "admin@nexus.com" role "org_admin" and no biometric
    When the RegisterUser command is dispatched
    Then the OnboardingProcessManager intercepts the UserRegistered event
    And the Compliance engine initiates a PEP check
    When the external PEP screening returns a "clean" status
    And the user completes the KYB wizard (entity profile, UBOs, documents, terms, biometric)
    Then the user status becomes "pending_kyb"
    And the admin panel shows the user's KYB documents for review
    When the platform admin completes the KYB review
    Then the OnboardingProcessManager dispatches ActivateUser
    And the user status becomes "active"

  Scenario: Team member registers, completes short wizard, and is immediately activated
    Given a new user is registered with email "analyst@nexus.com" role "treasury_analyst" and no biometric
    When the RegisterUser command is dispatched
    Then the OnboardingProcessManager intercepts the UserRegistered event
    And the Compliance engine initiates a PEP check
    When the external PEP screening returns a "clean" status
    And the user completes the short wizard (terms, biometric)
    Then the OnboardingProcessManager dispatches ActivateUser
    And the user status becomes "active"

  Scenario: PEP flagged user is not activated regardless of wizard completion
    Given a new user is registered with email "flagged@nexus.com" role "org_admin" and no biometric
    When the RegisterUser command is dispatched
    And the external PEP screening returns a "flagged" status
    And the user completes the full KYB wizard
    Then the OnboardingProcessManager does NOT dispatch ActivateUser
    And the user status remains "invited"
