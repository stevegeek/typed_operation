## [0.5.0] - Unreleased

### Added

- Positional params are now supported
- A new set of methods exist to define params, `.param`, `.named`, `.positional`, `.optional`
- Class methods to get names of parameters, positional and named, optional or required.

### Breaking changes

- TypedOperation now uses [Literal::Data](https://github.com/joeldrapper/literal) under the hood, instead of [vident-typed](https://github.com/stevegeek/vident-typed)
- Param option `convert:` has been removed, use a coercion block instead
- Param option `allow_nil:` has been removed, use `optional:` or `.optional()` instead
- The method `.curry` now actually curries the operation, instead of partially applying (use `.with` for partial application of parameters)
- `.operation_key` has been removed
- Ruby >= 3.1 is now required

### Changed

- TypedOperation does **not** depend on Rails. Rails generator support exists but is conditionally included.
- Numerous fixes

## [0.4.3] - Unreleased

### Added

- Added ability to pattern matching on params with operation instance or partially applied operations

## [0.4.2] - 2023/07/27

### Changed

- Params that have default values are no longer required to prepare the operation.

## [0.4.1] - 2023-06-22

### Changed

- Updated tests.
- Tweaked operation templates.

## [0.4.0] - 2023-06-22

### Removed

- Removed dry-monads as a dependency of TypedOperation. It can now be included in ApplicationOperation instead.

### Added

- Generator now creates a test file.

### Changed

- Avoided leaking the implementation detail of using dry-struct under the hood.

## [0.3.0] - 2023-06-19

### Removed

- Ruby 2.7 is not supported currently.
- Rails 6 is not supported currently due to vident dependency. Considering Literal::Attributes instead.

### Changed

- Updated test config.
- Added Github workflow for testing.

### Added

- Added some tests and updated docs.
- Added typed operation install and 'typed_operation' generators.

### Fixed

- Fixed 'require's.

## [0.1.0] - 2023-05-04

### Added

- Initial implementation of the project.
