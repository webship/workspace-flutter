Feature: A long list, its rows' buttons, and the favourites page
  The testing sample: a list of a hundred rows, each with a button that adds the row to the favourites and
  back, a message after each tap, and a page of the favourites at its own address. The rows' buttons have
  no name of their own: a step reaches each one through its row. Built with `bash cmd-flutter-project.sh
  fllist --source https://github.com/flutter/samples.git --path testing_app --install`, at the address of
  the app.

  Background:
    Given I am on the homepage
    And the app's accessibility tree is on

  @critical
  Scenario: A row further down is made a favourite, and removed on the favourites page
    When I scroll the app until I see "Item 30"
    And I tap the button in the "Item 30" row
    Then the app should announce "Added to favorites."
    When I tap "Favorites"
    Then the app should be on "/favorites_page"
    And the app should show "Item 30"
    When I tap the button in the "Item 30" row
    Then the app should announce "Removed from favorites."
    And the app should not show "Item 30"

  Scenario: The browser's back button leaves the favourites page
    When I tap "Favorites"
    Then the app should be on "/favorites_page"
    When I go back
    Then the app should be on "/"
    And the app should show "Item 0"
