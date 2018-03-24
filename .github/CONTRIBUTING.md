## Pull requests

We gladly accept pull requests to add documentation, fix bugs and, in some circumstances,
add new features to Spree.

Here's a quick guide:

1. Fork the repo

2. Clone the fork to your local machine

3. Create new branch then make changes and add tests for your changes. Only
refactoring and documentation changes require no new tests. If you are adding
functionality or fixing a bug, we need tests!

4. Run the tests. `make build-no-cache generate-accounts run generate-accounts-after-run fixtures tests clean`

5. Push to your fork and submit a pull request. If the changes will apply cleanly
to the master branch, you will only need to submit one pull request.

  Don't do pull requests against `-stable` branches. Always target the master branch. Any bugfixes we'll backport to those branches.

At this point, you're waiting on us. We like to at least comment on, if not
accept, pull requests within several days days.
We may suggest some changes or improvements or alternatives.

Some things that will increase the chance that your pull request is accepted.

Syntax:

* Two spaces, no tabs.
* No trailing whitespace. Blank lines should not have any space.
* Follow the conventions you see used in the source already.
* Alphabetize the class methods to keep them organized

And in case we didn't emphasize it enough: we love tests!

