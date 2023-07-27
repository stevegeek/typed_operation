## [0.5.0] - Unreleased

### Breaking changes

- TypedOperation now uses [Literal::Data](https://github.com/joeldrapper/literal) under the hood, instead of [vident-typed](https://github.com/stevegeek/vident-typed)
- param 'convert:' option has been removed, use a coercion block instead

### Changed

- TypedOperation does not depend on Rails. Rails generator support exists but is conditionally included.

## [0.4.2] - Unreleased

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
