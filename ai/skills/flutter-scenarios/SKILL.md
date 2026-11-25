---
name: flutter-scenarios
description: Write and fix webship-js scenarios for a Flutter web app with the Flutter step pack (`@webship-js/flutter-steps`) in the Webship Workspace — the pack's phrases for the app's tree, its controls, text and fields, dialogs and lists, how the steps name things (from the start of a name, a dialog by its title, an unnamed button through its row), the traps found on real apps, and three example features that pass. Use when writing a feature for a Flutter app, choosing the phrase for a tap, a field, a dialog or a long list, or reading why a Flutter scenario failed.
---

# flutter-scenarios

Scenarios for Flutter web apps in a Webship Workspace (`~/workspace`), a container-based workspace (DDEV
by default), with webship-js and [`@webship-js/flutter-steps`](https://github.com/webship/flutter-steps).
An app of the Flutter builder (`cmd-flutter-project.sh`) gets the pack with `bash cmd-tools-testing.sh
<app>`; the suite runs in the app's container (`bash cmd-tools-testing.sh <app> --run`).

The steps read the accessibility tree the app builds for screen readers. The first step of a scenario
that needs it turns the tree on, as assistive technology does (`Given the app's accessibility tree is
on`; every step of the pack does it by itself when it was not done). A widget the app leaves out of the
tree is out of reach, and the step says so as an accessibility finding about the app.

## The phrases

Check them against the installed pack before you use them
(`grep -hE "^(Given|When|Then)\(" node_modules/@webship-js/flutter-steps/tests/step-definitions/*.steps.js`).

**The app**

```gherkin
Given the app's accessibility tree is on
When I wait for the app to settle
Then the app should be on "/validation"
Then the app should run as WebAssembly
Then the app should announce "Added to favorites."
```

**Controls**: a tap by name (any control), by kind and name, through the named row, group or region a
control sits in, or by the identifier the app gives a widget; checkboxes; states.

```gherkin
When I tap "Increment"
When I tap the "Back" button
When I tap the button in the "Item 5" row
When I tap the element identified as "favorite-5"
When I check the "I agree to the terms of service." checkbox
Then the app should show the "Increment" button
Then the app's "Elevated" button should be disabled
Then the app's "Done" button in the "Your story" dialog should be enabled
Then the app's button in the "Item 5" row should be enabled
Then the app's "Option 1" radio button should be checked
Then the app's "Components" tab should be selected
```

**Text and fields**: a field is named by its label.

```gherkin
Then the app should show "You have pushed the button this many times: 1"
When I enter "quick" in the app's "Enter an adjective" field
When I type "fox" in the app's "Enter a noun" field
When I clear the app's "Enter a noun" field
Then the app's "Enter a noun" field should contain "fox"
Then the app's "Enter a noun" field should be empty
Then the app's "Enter a noun" field should be shown as invalid
Then the app's "Enter a noun" field should show the message "Please enter a noun."
```

**Dialogs**: a dialog is named by its title.

```gherkin
Then the app should show the "Your story" dialog
Then the app's "Your story" dialog should show "The quick developer saw a time"
When I tap "Done" in the "Your story" dialog
When I dismiss the "Your story" dialog
Then the app should show no dialog
```

**Lists and findings**

```gherkin
When I scroll the app until I see "Item 25"
When I scroll the app until I see the "Option 2" radio button
Then the app should have no unnamed buttons
```

webship-js's own steps go to an address (`Given I am on "/"`), go back (`When I go back`), set the
viewport and press keys. Its steps that read the page's text and fields (`I should see "..."`) find
nothing in an app drawn on a canvas: use the pack's.

## The traps

- **A name matches from its start.** Exactly, then without regard to case and spaces, then by its
  start; never a part in the middle ("Add" never matches "Address"). A button whose tooltip joins its
  name after a hover ("Increment Increment") still matches. A text field's name is its label, then its
  hint: name it by the label.
- **Two controls of one name**: say the kind ("the "Option 1" radio button" beside "the "Option 1"
  checkbox"). `should be enabled` and `should be disabled` pass when one control of that kind and name is
  in that state (a gallery that shows each button enabled and disabled), and their failure counts them. To
  say which one, name the row, group, region or dialog it sits in (`the app's "Done" button in the "Your
  story" dialog should be enabled`): that form holds only when exactly one such control is there.
- **A dialog has no name of its own in the tree**: the steps name it by its title, the first heading or
  line of text in it.
- **An unnamed button is a finding**, not a reason to tap a place on the canvas: reach it through its
  row (`the button in the "Item 5" row`) or an identifier, and keep `Then the app should have no unnamed
  buttons` in a scenario that must fail until the app names it.
- **A list keeps rows near the screen in the tree**: `Then the app should show "Item 20"` can pass for a
  row just below the screen. Scroll to it first when the scenario is about what a person sees.
- **A short message leaves again**: assert it with `Then the app should announce "..."`, which reads
  the announcements made since the last action.
- **A field with the keyboard focus when the page opened**: the app edits it in a hidden element of its
  own, and the field in the tree stays empty. `enter` and `type` say so; open that page from another one
  after the tree is on (`When I tap "Validation"` from the app's home page).
- **Routes**: `Then the app should be on "/validation"` reads the route after the `#` of an app with
  hash addresses (`Given I am on "/#/validation"` opens it), and the path of one with path addresses.
- **No fixed waits.** The steps wait on the app's frames; a Then step waits for what it expects.

## The examples

Three features that pass, each against the app it names:

- [`examples/counter.feature`](examples/counter.feature): the counter of `flutter create`
  (`bash cmd-flutter-project.sh flapp --install`).
- [`examples/forms-and-dialogs.feature`](examples/forms-and-dialogs.feature): the forms sample
  (`bash cmd-flutter-project.sh flform --source https://github.com/flutter/samples.git --path form_app --install`).
- [`examples/lists-and-routes.feature`](examples/lists-and-routes.feature): the testing sample
  (`bash cmd-flutter-project.sh fllist --source https://github.com/flutter/samples.git --path testing_app --install`).

## The book

For any automated functional testing in this work (a Gherkin feature, a step definition, choosing a
step, a test run and its failures), read the book *Automated Functional Testing Recipes* first.

- **Where.** Use the first that exists: `.claude/automated-functional-testing-recipes/` in the project,
  `~/.claude/automated-functional-testing-recipes/` (installed by webship/webship-js-ai-agent,
  webship/webship-js-skills or webship/ai-agents), or
  https://github.com/webship/webship-js-ai-agent/tree/2.0.x/automated-functional-testing-recipes
- **How.** Its `README.md` first, then the chapter that matches the task (one file per chapter,
  named by its subject), not the single complete file.
- **Which wins.** The installed webship-js package and the step pack are the source of truth for
  step phrasing. When they differ from the book, follow them and say so.
- **For Flutter.** Start with `ch15-accessibility-testing.md` (the tree the steps read),
  `ch27-testing-spa.md` (an app with routes and no page loads), `ch07-waiting-dynamic-content.md` (why
  a wait names its signal, never a time) and `ch21-when-tests-go-bad.md` (flaky, brittle and slow
  scenarios).
