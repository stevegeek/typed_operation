
## [1.0.0.beta3] - 2025/04/08

### Breaking changes

- Literal updated to release version so ImmutableBase now only freezes itself, not its properties too.

## [1.0.0.beta2] - 2024/06/24

### Added

- Now uses the new Literal::Properties
- Dropped the `#with` instance method
- install generator now can take a `--action_policy` switch to include the Action Policy integration

## [1.0.0.beta1] - 2023/08/26

### Added

- Action Policy integration. Optionally include `TypedOperation::ActionPolicyAuth` to get a operation execution authorization mechanism
  based on [Action Policy](https://actionpolicy.evilmartians.io/). This is an optional feature and is not included by default.

## [1.0.0.pre3] - 2023/08/24

### Added

- It is now possible to define two hooks, `#before_execute_operation` & `#after_execute_operation` which are called before and after the operation `#perform` method is executed. Note if you
  implement these methods remember to call `super` in them.

### Changes

- You now implement `#perform` (instead of `#call`) to define the operation logic. This is so that the before and after hooks can be called around the operation logic. It is still possible to
  use `#call` but then calling the hooks is the responsibility of the implementor. The recommended way is to use `#perform` to implement your operation logic now.

### Fixes

- Fixed a bug where a coercion block on an optional param was causing an error when the param was not provided.

## [1.0.0.pre2] - 2023/08/22

### Breaking changes

- `TypedOperation::Base` now uses `Literal::Struct` & is the parent class for an operation where the arguments are mutable (not frozen). But note that 
  no writer methods are defined, so the arguments can still not be changed after initialization. Just that they are not frozen. 
- `TypedOperation::ImmutableBase` now uses `Literal::Data` & is the parent class for an operation where the arguments are immutable (frozen on initialization), 
  thus giving stronger immutability guarantees (ie that the operation does not mutate its arguments).

## [1.0.0.pre1] - 2023/08/20

### Added

- Positional params are now supported
- A new set of methods exist to define params, `.param`, `.named`, `.positional`, `.optional`
- Class methods to get names of parameters, positional and named, optional or required.
- Added ability to pattern matching on params with operation instance or partially applied operations

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
