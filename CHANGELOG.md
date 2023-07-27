## [0.4.2] - 2023/07/27

### Changed

- Params that have default values are no longer required to prepare the operation.

## [0.4.1] - 2023/06/22

### Changed

- Updated tests.
- Tweaked operation templates.

## [0.4.0] - 2023/06/22

### Removed

- Removed dry-monads as a dependency of TypedOperation. It can now be included in ApplicationOperation instead.

### Added

- Generator now creates a test file.

### Changed

- Avoided leaking the implementation detail of using dry-struct under the hood.

## [0.3.0] - 2023/06/19

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

## [0.1.0] - Unreleased

### Added

- Initial implementation of the project.
