# Contributing to Logsearch Genesis Kit

When contributing to this repository, please first discuss the
change you wish to make via issue, email, or any other method with
the owners of this repository before making a change.

Please note we have a Code of Conduct, please follow it in all
your interactions with the project.

## Pull Request Process

1. Ensure that the Kit still compiles, and can be deployed using a
   recent vintage of the Genesis CLI (v2.8.12+).

2. All hooks must follow Genesis Perl conventions:
   - Use `underscore_names` (not camelCase)
   - No function prototypes
   - Use destructuring binds for named arguments
   - Tab indentation with 2-space tab stops
   - Include vim modeline and fold markers

3. Update the kit version in `kit.yml` following semantic versioning.

4. Ensure all tests pass:
   ```bash
   cd spec
   ginkgo -p .
   ```

5. Provide the context of the discussion with the repository
   owners and core team members that lead to the submission of the
   pull request. This may be as simple as a link to an issue.

6. Update documentation (README.md, MANUAL.md) for new features
   or parameter changes.

7. After review and approval, your Pull Request will be merged by
   a repository owner.

## Development Setup

### Prerequisites

- Genesis CLI v2.8.12+
- BOSH CLI v2+
- Go 1.19+ (for running tests)
- Perl 5.14+ with required modules

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/genesis-community/logsearch-genesis-kit.git
   cd logsearch-genesis-kit
   ```

2. Install test dependencies:
   ```bash
   # For Ginkgo tests
   go install github.com/onsi/ginkgo/v2/ginkgo@latest

   # For Perl hook testing
   cpanm -n Test::Exception Test::Deep Test::Differences
   ```

3. Run tests:
   ```bash
   # Run all tests
   make test

   # Run specific test suite
   cd spec && ginkgo -p -focus="small-footprint" .
   ```

### Testing Changes

Before submitting a PR, ensure:

1. **Unit Tests Pass**: All Ginkgo tests in `spec/` pass
2. **Manifest Generation**: Test manifest generation for various feature combinations
3. **Hook Functionality**: Verify all Genesis hooks work correctly
4. **Documentation**: Update docs for any new features or parameters

### Adding New Features

1. **Create Feature Manifest**: Add `manifests/features/my-feature.yml`
2. **Update Blueprint Hook**: Modify `hooks/blueprint.pm` to handle the feature
3. **Add Tests**: Create tests in `spec/` for the new feature
4. **Document Feature**: Update README.md and MANUAL.md

### Hook Development Guidelines

Hooks are written in Perl and must follow Genesis conventions:

```perl
package Genesis::Hook::Blueprint::Logsearch;
use strict;
use warnings;
use parent 'Genesis::Hook::Blueprint';

# Blueprint hook implementation
sub process {
    my ($self) = @_;
    
    # Hook logic here
    
    return $self->done();
}

1;
```

Key requirements:
- Always return `$self->done(<result>)` from `perform` method
- Use Genesis logging functions: `info`, `warning`, `error`, `bail`
- Include proper error handling
- Follow defensive programming practices

### Code Style

#### Perl Code
- Use `underscore_names` (not camelCase)
- No function prototypes
- Tab indentation with 2-space tab stops
- Include vim modeline:
  ```perl
  # vim: set ts=2 sw=2 sts=2 noet fdm=marker foldlevel=1:
  ```
- Use fold markers for methods:
  ```perl
  # method_name - description {{{
  sub method_name {
      # implementation
  }
  # }}}
  ```

#### YAML Manifests
- Use 2-space indentation
- Quote strings with special characters
- Use consistent key ordering
- Include helpful comments

#### Documentation
- Use clear, concise language
- Include examples for all parameters
- Provide troubleshooting guidance
- Keep README.md focused, detailed info in MANUAL.md

## Release Process

1. **Version Bump**: Update version in `kit.yml`
2. **Update Changelog**: Document changes in CHANGELOG.md
3. **Tag Release**: Create git tag (e.g., v1.1.0)
4. **GitHub Release**: Create release with compiled kit archive
5. **Announce**: Notify Genesis community of new release

## Getting Help

- **Issues**: Open GitHub issues for bugs or feature requests
- **Discussions**: Use GitHub Discussions for questions
- **Community**: Join the Genesis community Slack/Discord
- **Documentation**: Refer to Genesis project documentation

## Code of Conduct

This project adheres to the Genesis Community Code of Conduct. By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.