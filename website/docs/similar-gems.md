---
layout: default
title: Similar Gems
nav_order: 9
permalink: /similar-gems
---

# Similar Gems Comparison
{: .no_toc }

## Table of contents
{: .no_toc .text-delta }

1. TOC
{:toc}

---

## This is Not a Value Judgment

All of these gems are excellent and well-maintained. The Ruby community benefits from having multiple approaches to the same problem. This comparison helps you understand trade-offs, not to claim one is definitively better than another.

Choose based on your specific needs, team preferences, and project requirements.

---

## typed_operation Overview

typed_operation implements the Command pattern with **runtime type checking** via the literal gem. It encapsulates business logic into callable, composable operations with strongly typed parameters.

**Key features:**
- Runtime type validation at instantiation (before execution)
- Partial application and currying for functional composition
- Pattern matching support (Ruby 3+)
- Optional Dry::Monads integration for railway-oriented programming
- Framework-agnostic with optional Rails integration
- Flexible result types (return plain values, monads, or custom objects)

## Comparison with Alternatives

### Trailblazer

**What it is:** Comprehensive framework for modeling business logic as visual circuits with automatic error routing on success/failure tracks.

**Key differences:**
- **Workflow orchestration** vs typed_operation's command encapsulation
- **Contract validation** (Reform/Dry-validation) as workflow steps vs runtime type checking at instantiation
- **Opinionated result objects** with structured context vs flexible returns
- **Full ecosystem** (Cells, Reform, Representable) vs focused gem

**Choose Trailblazer if:** You want comprehensive architecture, visual circuit debugging, and full-stack guidance for large applications.

**Choose typed_operation if:** You want focused type safety without framework lock-in and prefer composable operations.

### Dry-rb Ecosystem

**What it is:** Suite of functional programming gems (dry-monads, dry-types, dry-validation) for composable type-safe operations.

**Key differences:**
- **Functional composition** (stateless transformations via monadic chains) vs command objects with typed attributes
- **Sophisticated type system** (constraints, coercion strategies, sum/product types) vs simpler runtime checking
- **Explicit railway-oriented programming** (Result monads everywhere) vs optional integration
- **Steeper learning curve** (monads, FP patterns) vs traditional OOP with type checking

**Choose Dry-rb if:** Your team embraces functional programming, needs powerful type constraints, or wants maximum composability.

**Choose typed_operation if:** You want operation patterns with type safety but prefer OOP approaches and simpler setup.

### Interactor

**What it is:** Lightweight service objects with shared context, organizers for sequencing, and automatic rollback.

**Key differences:**
- **No type safety** (hash-based context) vs runtime type checking
- **Implicit parameter contracts** vs explicit parameter declarations
- **Shared mutable context** across operations vs isolated immutable parameters
- **Built-in rollback** for multi-step processes vs manual cleanup
- **Simplicity-focused** vs type-safety-focused

**Choose Interactor if:** You need simple service objects with automatic rollback and prioritize rapid development over type safety.

**Choose typed_operation if:** Type safety matters, you want explicit contracts, or need functional composition patterns.

### active_interaction

**What it is:** Service objects that behave like ActiveModels with type filters, ActiveModel validations, and form integration.

**Key differences:**
- **Rails-style coercion** (strings to integers automatically) vs strict types
- **ActiveModel validations** (declarative) vs manual validation in hooks
- **Rails coupling** (ActiveModel/ActiveSupport dependencies) vs framework-agnostic
- **Opinionated outcome pattern** (`.valid?`, `.result`, `.errors`) vs flexible returns
- **Seamless form integration** vs no form opinions

**Choose active_interaction if:** Building Rails apps with forms, want ActiveModel validations, and Rails-style coercion matches your needs.

**Choose typed_operation if:** You need framework independence, strict type checking without coercion, or functional programming patterns.

### light-service

**What it is:** Workflow orchestration through organizers with expect/promise contracts and railway-oriented programming.

**Key differences:**
- **Expect/promise contracts** (runtime presence checking) vs typed parameters (type enforcement)
- **Shared mutable context** (accumulates state) vs immutable parameters
- **Built-in rollback** with `rolled_back` blocks vs manual cleanup
- **Rich control flow DSL** (reduce_if, reduce_case, iterate, etc.) vs explicit composition
- **Workflow-focused** vs operation-focused

**Choose light-service if:** Building multi-step workflows with conditional logic and need automatic rollback for transaction-like operations.

**Choose typed_operation if:** Type safety is paramount, you prefer immutable operations, or need functional composition patterns.

## Quick Decision Guide

**Type safety without framework commitment** → typed_operation
- Runtime type checking, lightweight, composable, framework-agnostic

**Comprehensive architecture with visual debugging** → Trailblazer
- Full ecosystem, circuit-based workflows, large applications

**Functional programming with powerful types** → Dry-rb ecosystem
- Monads, sophisticated type constraints, maximum composability

**Rails simplicity with automatic rollback** → Interactor
- Minimal API, transaction-like operations, rapid development

**Rails forms with ActiveModel integration** → active_interaction
- Form objects, familiar validations, Rails conventions

**Workflow orchestration with control flow** → light-service
- ETL pipelines, complex multi-step processes, declarative workflows

## What Makes typed_operation Unique

1. **Partial application & currying** - Build operations incrementally, pass partially-configured operations
2. **Pattern matching** - Full Ruby 3+ pattern matching support with `deconstruct` and `deconstruct_keys`
3. **Flexible result types** - Return plain values, Dry::Monads, or custom objects—your choice
4. **Runtime type safety** - Catches type errors at instantiation before execution
5. **Framework-agnostic** - Works anywhere, optional Rails integration

## Can You Mix Them?

Yes! These gems often work together:
- typed_operation + Dry::Monads for Result types
- typed_operation + dry-validation for complex validation
- Multiple gems in same codebase for different needs (e.g., typed_operation for API handlers, Interactor for simple services)
