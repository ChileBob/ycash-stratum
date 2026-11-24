# AGENTS.md - Perl Best Practices & Linting Rules

## Guidelines for All Agents Working with Perl Code in This Repository

### 1. Code Style & Formatting

- **Follow the style guide**: Use `perlcritic` checks configured and adhere to them.
- **Consistent indentation**: Use tabs or spaces consistently (preferred: 2 spaces)
- **CamelCase for packages**: `PackageName::SubroutineName()`
- **snake_case for subroutines and filenames**: `my_subroutine_name`
- **File extensions**: Keep `.pm` for modules, `.pl` for scripts, `.t` for test files

### 2. Module Requirements

- **Use `use strict; use warnings;`**: This is mandatory in all Perl files
- **Modern Perl features**: Use modern List::Util qw(first last) and similar
- **Version compatibility**: Support at least Perl 5.20+ with deprecation warnings enabled
- **Deprecated modules**: Avoid CPAN.pm, File::Spec, Getopt::Long; use alternatives if available

### 3. Best Practices

- **Context awareness**: Understand when code runs in list or scalar context
- **Error handling**: Use try/catch with `eval` blocks for exceptions (if module supports) and proper return codes
- **File I/O**: Always close filehandles; use lexical filehandles (`open(my $fh, '<', $file)`); handle read/write operations carefully
- **Hash usage**: Prefer named parameters in subroutines over positional arguments when complexity warrants

### 4. Testing & Quality Assurance

- **Test files**: Store test cases with `-t` or `.spec` suffixes
- **Coverage**: Achieve adequate coverage and maintain acceptable `perlcritic` scores
- **Linting**: Regularly run `perlcritic` to check for code quality issues

### 5. Git & Version Control

- **Commit message conventions**: Use conventional commits with clear descriptions
- **Branch naming**: Use feature branches like `feature/`, `bugfix/`, `refactor/` prefixes
- **Pull requests**: Review existing templates and follow repository structure when creating PRs

### 6. Documentation Standards

- **Pod documentation**: Include comprehensive Pod docs for all public modules/subroutines:

    ```perl
    =head1 DESCRIPTION

    Brief description of the module.

    =head2 FUNCTION_NAME ( @args )

    Description of subroutine/function...

    Parameters:
      - @args : List of arguments

    Returns:
        Description of return value.

    Examples:
      use FunctionName;
      my $result = FunctionName->new( arg1 => 'value' );
    ```

  - **Examples**: Always include usage examples in docs

### 7. Security Considerations

- **Avoid dangerous functions**: Never use `eval` with user input without sanitization
- **Input validation**: Validate all external and internal inputs
- **Security headers**: Ensure any web-facing components include appropriate security headers where applicable

### 8. Performance Optimization

- **Time complexity**: Write efficient algorithms with favorable time/space complexity: O(n) preferred over O(n²)
- **Avoid redundant work**: Minimize repeated computations; use caching when feasible
- **Memory usage**: Be mindful of memory usage in loops and closures

### 9. Code Organization

- **Modularity**: Keep functions small and focused on specific responsibilities
- **DRY principle**: Use pragmatism to avoid duplication while maintaining clarity
- **Single responsibility**: Each module should have a clear, single purpose

### 10. Git Configuration & Workflow

- **Pre-commit linting**: Run `perlcritic` before committing any Perl code
- **Branch hygiene**: Keep branch names meaningful and descriptive
- **Test inclusion**: Ensure all test cases are included in commits related to them
- **Changelog updates**: Update Changelogs appropriately when making meaningful changes

### 11. Linting Tool Configuration

- **perlcritic settings**: Use the predefined configuration that is appropriate for this codebase
- **Continuous integration**: Integrate `perlcritic` checks into CI pipelines
- **Automated reviews**: Configure automated Perl linting tools and PR checkers to scan for violations of style rules before merge approval

### 12. Environment & Dependencies

- **Dependency management**: Use appropriate dependency managers (`inc::Module::Install`, `cpanfile`) when available
- **Platform compatibility**: Ensure all code works on both Linux-based systems as specified in the platform requirements

---

**Note**: These guidelines apply to all agents working within this repository context. Violations without discussion should be avoided, and changes to these rules require consensus among project maintainers.
