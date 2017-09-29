# danger-conflict_checker

Check whether Pull Request with the same destination conflicts and warn.


[Exmple Pull Request message](https://github.com/justice3120/danger-conflict_checker-example/pull/4)

## Installation

    $ gem install danger-conflict_checker

## Usage

### methods
Get information about the conflict between PRs.

```
check_results = conflict_checker.check_conflict
```

Warn in PR comment about the conflict between PRs.

```
conflict_checker.check_conflict_and_comment
```
