# danger-conflict_checker

Warn about the conflict between PRs.

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
