---
title: "Resonable macros through explicit bindings"
author:
  - |
    Frederic Kettelhoit\
    Recurse Center\
    fred@fkettelhoit.com
date: \today
abstract: |
  We present macros that can be reasoned about statically without requiring a macro expansion phase. This is achieved by distinguishing variables that are being _bound_ from variables that are being _used_, in combination with _explicit block scopes_. The resulting macro system enables _local reasoning_, by supporting local evaluation without requiring full knowledge of the macros in scope.
---

# Introduction

Modern programming languages face a fundamental tension between expressiveness and static analyzability. While macro systems provide the flexibility to define custom control structures and extend language syntax, they often compromise the ability to reason about programs statically. This paper introduces a novel approach to resolve this tension through _explicit bindings_, a mechanism that enables macro-like expressiveness while preserving static reasoning capabilities.

# Motivation

The design of extensible programming languages has long grappled with the challenge of allowing user-defined constructs without sacrificing analyzability. Consider the requirement that every function or control structure in a language should be redefinable, including fundamental operations such as variable assignment. While a language may provide built-in syntax for expressions like `a = 5`, the goal is to enable user-defined functions to achieve equivalent functionality, such as through a function `set` invoked as `set(a, 5)`.

Traditional approaches to this problem have relied on Lisp-style macro systems, dating all the way back to Lisp 1.5 [@hart1963macro;@steele1996evolution]. In such systems, `set` can be implemented as a macro that treats its first argument `a` as an unevaluated symbol rather than a variable reference, evaluates the second argument `5`, and then invokes the built-in assignment operation to bind the symbol `a` to the value 5. However, this approach introduces significant complications:

1. **Complexity**: Macro systems add substantial language complexity, particularly regarding macro hygiene: the challenge of preventing unintended variable capture and ensuring that macro expansions do not interfere with the lexical scoping of the surrounding code [@kohlbecker1986hygienic].

2. **Static Analysis Impediments**: The presence of macros fundamentally undermines static reasoning about program behavior. Given an expression such as `foo(2 + 2)`, one cannot determine whether this can be simplified to `foo(4)` without first resolving whether `foo` is a macro. Macros can observe and act upon syntactic differences between expressions that are semantically equivalent, necessitating macro resolution before any program optimization or analysis can occur.

# Contribution

This work proposes a alternative approach that achieves most of the expressiveness of traditional macro systems while maintaining the ability to perform static analysis. Our key insight is to explicitly distinguish between variables that are being **bound** (newly introduced into scope) and variables that are being **used** (referenced from existing scope). This distinction, combined with explicit block scoping, enables what we term **reasonable macros**: extensible language constructs that can be analyzed statically without prior macro expansion.

The fundamental principle guiding of our design is:

_Every construct in the language can be redefined without privileged language constructs, while the scope and binding structure of variables remains immediately apparent from the source code alone, without requiring evaluation of any function or macro._

# Technical Approach

Our approach bridges the gap between fexprs and traditional macros through _selective evaluation_ based on syntactic markers. The core insight is that evaluation behavior can be determined purely syntactically: expressions containing explicit binding markers remain unevaluated for structural manipulation, while unmarked expressions are evaluated normally. This guarantees that macros can observe syntactic differences only in the presence of explicit binding markers, in all other cases semantically equivalent expressions can be freely substitued for each other, ensuring that referential transparency is preserved.

## Explicit Bindings

We introduce a syntactic distinction that governs evaluation behavior:

- **Variable Usage**: Variables resolved from existing scope use standard notation (e.g., `x`)
- **Variable Binding**: Variables that introduce fresh bindings are prefixed with a quote marker (e.g., `:x`)

This marking scheme enables what we term _reasonable macros_: functions that can access syntactic structure when needed while preserving static reasoning for unmarked expressions:

```
f(2 + 2)     // no explicit bindings, equivalent to f(4)
f(:x)        // :x remains unevaluated for structural access
f(:x, y + z) // y + z evaluated, x remains syntactic
```

The presence of binding markers provides a syntactic guarantee about evaluation behavior, eliminating the need for runtime type checking (as in fexprs) or complete macro expansion (as in traditional macro systems).

## Explicit Block Scope

To support static reasoning while allowing user-defined binding constructs, variable scope must be tracked syntactically. We employ explicit block syntax `{ ... }` with the innovation that binding declarations are separated from their scope blocks. This separation enables precise control over variable binding while maintaining syntactic clarity about scope boundaries.

# Related Work

The challenge of balancing expressiveness with static analyzability in metaprogramming has been explored through several distinct approaches, each with particular trade-offs between power and reasoning capabilities.

## Fexprs and Operatives

An alternative to macro-based metaprogramming emerged through the development of _fexprs_—functions that receive their arguments unevaluated and can selectively evaluate them in controlled environments [@pitman1980special]. This approach was later refined in Shutt's Kernel language, which distinguishes between _operatives_ (functions that do not evaluate their arguments by default) and _applicatives_ (functions that do evaluate their arguments) [@shutt2010fexprs].

The fundamental insight of fexprs is that operatives represent a more primitive abstraction than applicatives, since any applicative can be constructed by wrapping an operative with automatic argument evaluation. However, this generality comes at the cost of static reasoning: because operatives can selectively evaluate or ignore their arguments, expressions like `f(2 + 2)` cannot be optimized to `f(4)` without first determining whether `f` is an operative or applicative.

Mitchell [@mitchell1993abstraction] and Wand [@wand1998theory] identified this limitation in their foundational work on fexprs, noting that the ability to observe syntactic structure necessarily impedes equational reasoning. While fexprs provide semantic abstraction without requiring phase separation between compile-time and run-time, they sacrifice the compiler's ability to perform optimizations based on expression equivalence.

Our approach represents a deliberate restriction of fexpr-style operatives, trading some expressive power for static analyzability. Unlike Kernel's operatives, which can dynamically choose whether to evaluate any argument, our approach determines evaluation behavior syntactically through binding markers. This restriction enables translation to standard call-by-value lambda calculus while preserving the ability to define custom binding constructs.

## Restricted Metaprogramming Approaches

Several researchers have explored restricted forms of metaprogramming that preserve some static reasoning capabilities. These approaches generally involve constraining when and how syntactic structure can be observed, though they differ in their specific mechanisms and the extent of their restrictions.

The approach presented in this paper builds upon insights from both macro systems and fexprs while introducing novel syntactic constraints. By making variable bindings explicit through syntactic markers, we enable selective access to syntactic structure—arguments containing explicit bindings remain unevaluated for structural manipulation, while other arguments are evaluated normally. This provides a middle ground between the full power of fexprs and the static analyzability of conventional function calls.

## Comparison with Existing Approaches

Our explicit binding approach differs from traditional macros in that it eliminates the need for complete macro expansion before optimization can occur. Unlike fexprs, it provides syntactic guarantees about when evaluation occurs, enabling static reasoning about expression equivalence. The key innovation is that evaluation behavior is determined syntactically by the presence of binding markers rather than by runtime type checking or compile-time macro resolution.

# References

\vspace{1em}

::: {#refs}
:::
