Feature: A form that checks what is typed, and the dialog it opens
  The validation page of the forms sample: two text fields and a checkbox, checked when the form is sent,
  and a dialog with the story the words make. Built with `bash cmd-flutter-project.sh flform --source
  https://github.com/flutter/samples.git --path form_app --install`, at the address of the app.

  Background:
    Given I am on the homepage
    And the app's accessibility tree is on
    When I tap "Validation"

  @critical
  Scenario: A form sent empty shows what is missing, then a filled one tells the story
    Then the app should be on "/validation"
    When I tap "Submit"
    Then the app's "Enter an adjective" field should be shown as invalid
    And the app's "Enter a noun" field should show the message "Please enter a noun."
    When I enter "quick" in the app's "Enter an adjective" field
    And I type "time" in the app's "Enter a noun" field
    And I check the "I agree to the terms of service." checkbox
    And I tap "Submit"
    Then the app should show the "Your story" dialog
    And the app's "Your story" dialog should show "The quick developer saw a time"
    When I tap "Done" in the "Your story" dialog
    Then the app should show no dialog

  Scenario: A word that is not a noun is refused, and Escape dismisses the story
    When I enter "quick" in the app's "Enter an adjective" field
    And I enter "fox" in the app's "Enter a noun" field
    And I tap "Submit"
    Then the app's "Enter a noun" field should show the message "Not a valid noun."
    When I clear the app's "Enter a noun" field
    And I enter "time" in the app's "Enter a noun" field
    And I check the "I agree to the terms of service." checkbox
    And I tap "Submit"
    Then the app should show the "Your story" dialog
    When I dismiss the "Your story" dialog
    Then the app should not show the "Your story" dialog
    When I tap the "Back" button
    Then the app should be on "/"
