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

The design of extensible programming languages has long grappled with the challenge of allowing user-defined constructs without sacrificing analyzability. Consider the requirement that every function or control structure in a language should be redefinable, including fundamental operations such as variable assignment. While a language may provide built-in syntax for expressions like `a = 5`, the goal is to enable user-defined functions to achieve equivalent functionality, such as through a function `let` invoked as `let(a, 5)`.

Traditional approaches to this problem have relied on Lisp-style macro systems, dating all the way back to Lisp 1.5 [@hart1963macro;@steele1996evolution]. In such systems, `let` can be implemented as a macro that treats its first argument `a` as an unevaluated symbol rather than a variable reference, evaluates the second argument `5`, and then invokes the built-in assignment operation to bind the symbol `a` to the value 5. However, this approach introduces significant complications:

1. **Complexity**: Macro systems add substantial language complexity, particularly regarding macro hygiene: the challenge of preventing unintended variable capture and ensuring that macro expansions do not interfere with the lexical scoping of the surrounding code [@kohlbecker1986hygienic].

2. **Static analysis impediments**: The presence of macros fundamentally undermines static reasoning about program behavior. Given an expression such as `foo(2 + 2)`, one cannot determine whether this can be simplified to `foo(4)` without first resolving whether `foo` is a macro. Macros can observe and act upon syntactic differences between expressions that are semantically equivalent, necessitating macro resolution before any program optimization or analysis can occur.

# Contribution

This work proposes a alternative approach that achieves most of the expressiveness of traditional macro systems while maintaining the ability to perform static analysis. Our key insight is to explicitly distinguish between variables that are being **bound** (newly introduced into scope) and variables that are being **used** (referenced from existing scope). This distinction, combined with explicit block scoping, enables what we term **reasonable macros**: extensible language constructs that can be analyzed statically without prior macro expansion.

The fundamental guiding principle of our design is:

_Every construct in the language can be redefined without privileged language constructs, while the scope and binding structure of variables remains immediately apparent from the source code alone, without requiring evaluation of any function or macro._

# Technical approach

Our approach bridges the gap between fexprs and traditional macros through _selective evaluation_ based on syntactic markers. The core insight is that evaluation behavior can be determined purely syntactically: expressions containing explicit binding markers remain unevaluated for structural manipulation, while unmarked expressions are evaluated normally. This guarantees that macros can observe syntactic differences only in the presence of explicit binding markers, in all other cases semantically equivalent expressions can be freely substitued for each other, ensuring that referential transparency is preserved.

## Explicit bindings

We introduce a syntactic distinction that governs evaluation behavior:

- **Variable Usage**: Variables resolved from existing scope use standard notation (e.g., `x`)
- **Variable Binding**: Variables that introduce fresh bindings are prefixed with a marker (e.g., `:x`)

This marking scheme enables what we term _reasonable macros_: functions that can access syntactic structure when needed while preserving static reasoning for unmarked expressions:

```javascript
// no bindings, equivalent to f(4)
f(2 + 2)

// :x remains unevaluated
f(:x)

// :x unevaluated, y + z evaluated
f(:x, y + z)
```

The presence of binding markers provides a syntactic guarantee about evaluation behavior, eliminating the need for runtime type checking (as in fexprs) or complete macro expansion (as in traditional macro systems).

## Explicit block scope

To support static reasoning while allowing user-defined binding constructs, variable scope must be tracked syntactically. We employ explicit block syntax `{ ... }` with the innovation that binding declarations are separated from their scope blocks. Such a block is equivalent to a lambda abstraction that does not specify its bound variables explicitly but rather determines them based on the explicit bindings that appear to its left in the abstract syntax tree. This separation enables precise control over variable binding while maintaining syntactic clarity about scope boundaries.

As a more concrete example, let us consider the following function call:

```javascript
foo(:x, y, { bar(x) })
//  |      \________/
//  |      scope of x
//  |
//  '-- binding of x
```

Both the scope and the origin of the variable `x` in the block `{ bar(x) }` are determined syntactically, without knowing the definition of `foo` (and thus without knowing whether `foo` is a macro or a regular function). Since the explicit binding `:x` appears to the left of the block `{ bar(x) }`, the block is desugared to a lambda abstraction with the bound variable `x`.

More precisely, the association between explicit bindings and blocks works as follows: A function `f` with non-block arguments `f_0 ... f_m-1`, a block `{ ... }` as argument `f_m`, and further arguments `f_m+1 ... f_n` desugars the block into a curried lambda abstraction of `k` bound variables and consumes these bindings (making them unavailable to blocks occurring after `f_m`), where `k` is the number of explicit bindings occurring in the arguments `f_0 ... f_m-1` that are not consumed by other blocks.

## Nested blocks

Sequential binding operations using the explicit form can lead to deeply nested structures that impair readability. Consider a series of variable bindings:

```javascript
let(:a, x, {
  let(:b, y, {
    let(:c, z, {
      f(a, b, c)
    })
  })
})
```

While this nesting clearly shows the scope structure, it becomes unwieldy for longer sequences. To address this, we introduce syntactic sugar that allows blocks to consume bindings by enclosing them:

```javascript
{
  let(:x, y),
  f(x)
}
```

This block-enclosed syntax is equivalent to the more explicit form `let(:x, y, { f(x) })`. The desugaring process recognizes that the `let` construct within the block contains an explicit binding `:x` and is followed by another element in the enclosing block, so the binding is automatically consumed by the enclosing block. This transformation preserves the static analyzability of the binding structure while providing more natural syntax for common patterns.

The approach scales naturally to multiple nested bindings:

```javascript
{
  let(:a, x),
  let(:b, y),
  f(a, b)
}
```

This desugars to `let(:a, x, { let(:b, y, { f(a, b) }) })`, creating the expected nested scope structure. Each binding construct that contains explicit bindings automatically receives the remainder of the block as its block argument.

To handle expressions that do not introduce bindings (such as side effects), the system treats non-binding block elements differently. When a block element contains no explicit bindings that could be consumed by the enclosing block, the element is evaluated as an argument to an anonymous function that returns the rest of the block:

```javascript
{
  let(:x, Foo),
  print("..."),
  use_x(x)
}
```

This desugars to an expression where the `print` call executes its side effect before the remainder of the block continues with access to the binding `x`. This mechanism allows natural mixing of binding constructs and effectful computations while maintaining the clear separation between binding and usage.

The nested block syntax preserves all the static reasoning properties of the explicit form. Variable bindings remain syntactically apparent, scope boundaries are clearly delineated, and the desugaring process produces standard lambda calculus constructs that can be analyzed and optimized using conventional techniques.

## Macro definitions

To complete the macro system, we need mechanisms for defining constructs that can observe and manipulate the syntactic structure of explicitly marked bindings.

Macro definitions are distinguished from regular function definitions through a syntactic marker. A macro definition uses the `#` prefix (e.g., `#f = ...`), while regular function definitions use standard syntax (e.g., `:f = ...`). The environment tracks both the names in scope and their classification as either macros or regular values. This distinction matters only during the desugaring phase when translating to call-by-value lambda calculus; it does not impact the evaluation rules, which can continue to use standard lambda calculus environments.

When a macro is applied to arguments, its arguments undergo a static transformation that makes syntactic structure observable. Arguments are wrapped in data structures that preserve the distinction between evaluated expressions and syntactic elements that contain explicit bindings. This transformation occurs during the desugaring phase, before any evaluation takes place and relies only on syntactic information.

The argument transformation follows these patterns:

```javascript
f(x)          // f(Value(x))
f(:x)         // f(Binding("x"))
f(bar(x, y))  // f(Value(bar(x, y)))
f(bar(x, :y)) // f(Call(Value(bar), [Value(x), Binding("y")]))
f(:bar(x, y)) // f(Call(Binding("bar"), [Value(x), Value(y)]))
```

In the case of `foo(bar(x, :y))`, the presence of the explicit binding `:y` within the `bar` call prevents the entire expression from being evaluated. Instead, it is preserved as a `Call` structure that contains both evaluated components (`Value(x)`) and syntactic components (`Binding("y")`). This selective preservation allows macros to observe syntactic structure precisely where it is explicitly marked, while maintaining referential transparency for unmarked subexpressions.

## Multi-level bindings

The basic explicit binding mechanism supports bindings that are active in the immediately following scope, but many programming constructs require bindings that persist across multiple scope levels. A prominent example is the definition of a recursive function, where the function being defined must be available both within its own definition (for recursive calls) and in the scope following the definition (for external use).

Multi-level bindings extend the explicit binding syntax to support this pattern through repeated markers. While single-level bindings use one marker (`:x`), multi-level bindings use multiple markers to indicate their scope lifetime. A binding `::x` remains active for the next two scopes, `:::x` for three scopes, and so on.

Consider the definition of a recursive function:

```javascript
{
  ::factorial(:n) = {
    if(n == 0, 1, n * factorial(n - 1))
  },
  factorial(5)
}
```

The `::factorial` binding with two markers indicates that the function will be available both within its own definition (enabling the recursive call `factorial(n - 1)`) and in the subsequent scope (enabling the call `factorial(5)`).

The multi-level binding mechanism preserves static analyzability by making the scope lifetime explicit in the syntax. A static analyzer can determine the availability of any identifier by counting binding markers and tracking scope nesting levels, without requiring knowledge of the specific constructs being used.

# Algorithm

TODO: Present a pseudocode algorithm to desugar reasonable macros + explicit bindings into cbv lambda calculus, based on the following Rust code:

```

#[derive(Debug, Clone)]
pub struct Ast(pub usize, pub A);

#[derive(Debug, Clone)]
pub enum A {
    Var(String),
    Atom(String),
    String(String),
    Binding(usize, BindType, String),
    Block(Vec<Ast>),
    Call(Box<Ast>, Vec<Ast>),
}

#[derive(Debug, Clone)]
pub enum Expr {
    Var(usize),
    String(usize),
    Effect(usize),
    Abs(Box<Expr>),
    Rec(Box<Expr>),
    App(Box<Expr>, Box<Expr>),
    Type(Box<Expr>),
    Unpack([Box<Expr>; 3]),
    Handle([Box<Expr>; 2]),
    Compare([Box<Expr>; 4]),
}

pub fn abs(body: Expr) -> Expr {
    Expr::Abs(Box::new(body))
}

pub fn app(f: Expr, arg: Expr) -> Expr {
    Expr::App(Box::new(f), Box::new(arg))
}

pub fn nil() -> Expr {
    Expr::String(Str::Nil as usize)
}

pub fn desugar<'c>(block: Vec<Ast>, code: &'c str, ctx: &mut Ctx) -> Result<Expr, String> {
    fn resolve_var(v: &str, ctx: &Ctx) -> Option<usize> {
        ctx.vars.iter().rev().position(|(_, x)| *x == v)
    }
    fn resolve_str<'c>(s: String, ctx: &mut Ctx) -> usize {
        ctx.strs.iter().position(|x| *x == s).unwrap_or_else(|| {
            ctx.strs.push(s);
            ctx.strs.len() - 1
        })
    }
    fn is_macro(Ast(_, ast): &Ast, ctx: &Ctx) -> bool {
        if let A::Var(v) = ast {
            if let Some((BindType::Macro, _)) = ctx.vars.iter().rev().find(|(_, x)| x == v) {
                return true;
            }
        }
        false
    }
    fn has_bindings(Ast(_, ast): &Ast, ctx: &Ctx) -> bool {
        match ast {
            A::Binding(_, _, _) => true,
            A::Var(_) | A::Atom(_) | A::String(_) | A::Block(_) => false,
            A::Call(f, _) if is_macro(f, ctx) => false,
            A::Call(f, _) if has_bindings(f, ctx) => true,
            A::Call(_, args) => args.iter().any(|arg| has_bindings(arg, ctx)),
        }
    }
    fn desug_macro(ast: Ast, ctx: &mut Ctx) -> Result<Expr, (usize, String)> {
        fn desug_all(xs: Vec<Ast>, ctx: &mut Ctx) -> Result<Vec<Expr>, (usize, String)> {
            xs.into_iter().map(|x| desug_macro(x, ctx)).collect()
        }
        match ast.1 {
            A::Call(f, args) if has_bindings(&ast, ctx) => {
                let f = desug_macro(*f, ctx)?;
                let args = desug_all(args, ctx)?;
                let list = args.into_iter().fold(nil(), |l, x| app(l, x));
                Ok(app(app(Expr::String(Str::Compound as usize), f), list))
            }
            A::Var(_) | A::Atom(_) | A::String(_) | A::Call(_, _) => {
                Ok(app(Expr::String(Str::Value as usize), desug_val(ast, ctx)?))
            }
            A::Binding(_, _, _) => {
                Ok(app(Expr::String(Str::Binding as usize), desug_val(ast, ctx)?))
            }
            A::Block(_) => desug_val(ast, ctx),
        }
    }
    fn desug_val<'c>(Ast(pos, ast): Ast, ctx: &mut Ctx) -> Result<Expr, (usize, String)> {
        match ast {
            A::Var(v) if v.ends_with("!") => {
                Ok(Expr::Effect(resolve_str(v[..v.len() - 1].to_string(), ctx)))
            }
            A::Var(v) => match resolve_var(&v, ctx) {
                Some(v) => Ok(Expr::Var(v)),
                None => match v.as_str() {
                    "=" => Ok(abs(abs(abs(app(Expr::Var(0), Expr::Var(1)))))),
                    "=>" => Ok(abs(abs(Expr::Var(0)))),
                    "~>" => Ok(abs(abs(Expr::Rec(Box::new(Expr::Var(0)))))),
                    "type" => Ok(abs(Expr::Type(Box::new(Expr::Var(0))))),
                    "__compare" => Ok(abs(abs(abs(abs(Expr::Compare(
                        [3, 2, 1, 0].map(|v| Expr::Var(v).into()),
                    )))))),
                    "__unpack" => {
                        Ok(abs(abs(abs(Expr::Unpack([2, 1, 0].map(|v| Expr::Var(v).into()))))))
                    }
                    "__handle" => Ok(abs(abs(Expr::Handle([1, 0].map(|v| Expr::Var(v).into()))))),
                    _ => Err((pos, v.to_string())),
                },
            },
            A::Atom(s) => Ok(Expr::String(resolve_str(s.to_string(), ctx))),
            A::String(s) => Ok(Expr::String(resolve_str(format!("\"{s}\""), ctx))),
            A::Binding(lvl, c, b) => {
                ctx.bindings.push((lvl, c, b.to_string()));
                Ok(Expr::String(resolve_str(format!("\"{b}\""), ctx)))
            }
            A::Block(mut items) => {
                let mut desugared = vec![];
                if items.is_empty() {
                    items.push(Ast(pos, A::Atom(NIL.to_string())));
                }
                for ast in items {
                    let bindings = ctx.bindings.len();
                    let drained = ctx.drain_bindings();
                    ctx.vars.extend(drained);
                    if bindings == 0 {
                        ctx.vars.push((BindType::Variable, String::new()))
                    }
                    desugared.push((bindings, desug_val(ast, ctx)?));
                }
                let (mut bindings, mut expr) = desugared.pop().unwrap();
                expr = (0..max(1, bindings)).fold(expr, |x, _| abs(x));
                for (prev_bindings, x) in desugared.into_iter().rev() {
                    let (f, arg) = if bindings == 0 { (expr, x) } else { (x, expr) };
                    expr = (0..max(1, prev_bindings)).fold(app(f, arg), |x, _| abs(x));
                    ctx.vars.truncate(ctx.vars.len() - max(1, bindings));
                    bindings = prev_bindings;
                }
                ctx.vars.truncate(ctx.vars.len() - max(1, bindings));
                ctx.clear_bindings();
                Ok(expr)
            }
            A::Call(f, args) => {
                let bindings = mem::replace(&mut ctx.bindings, vec![]);
                let is_macro = is_macro(&f, ctx);
                let mut f = desug_val(*f, ctx)?;
                if args.is_empty() {
                    f = app(f, nil());
                }
                for x in args {
                    f = app(f, if is_macro { desug_macro(x, ctx)? } else { desug_val(x, ctx)? })
                }
                ctx.bindings.splice(0..0, bindings);
                Ok(f)
            }
        }
    }
    match desug_val(Ast(0, A::Block(block)), ctx) {
        Err((i, v)) => Err(format!("Unbound variable '{v}' at {}", pos_at(i, code))),
        Ok(Expr::Abs(body)) => Ok(*body),
        Ok(_) => unreachable!("Expected the main block to be desugared to an abstraction!"),
    }
}
```

# Related work

The challenge of balancing expressiveness with static analyzability in metaprogramming has been explored through several distinct approaches, each with particular trade-offs between power and reasoning capabilities.

## Fexprs and operatives

An alternative to macro-based metaprogramming emerged through the development of _fexprs_: functions that receive their arguments unevaluated and can selectively evaluate them in controlled environments [@pitman1980special]. This approach was later refined in Shutt's Kernel language, which distinguishes between _operatives_ (functions that do not evaluate their arguments by default) and _applicatives_ (functions that do evaluate their arguments) [@shutt2010fexprs].

The fundamental insight of fexprs is that operatives represent a more primitive abstraction than applicatives, since any applicative can be constructed by wrapping an operative with automatic argument evaluation. However, this generality comes at the cost of static reasoning: because operatives can selectively evaluate or ignore their arguments, expressions like `f(2 + 2)` cannot be optimized to `f(4)` without first determining whether `f` is an operative or applicative.

Mitchell [@mitchell1993abstraction] and Wand [@wand1998theory] identified this limitation in their foundational work on fexprs, noting that the ability to observe syntactic structure necessarily impedes equational reasoning. While fexprs provide semantic abstraction without requiring phase separation between compile-time and run-time, they sacrifice the compiler's ability to perform optimizations based on expression equivalence.

Our approach represents a deliberate restriction of fexpr-style operatives, trading some expressive power for static analyzability. Unlike Kernel's operatives, which can dynamically choose whether to evaluate any argument, our approach determines evaluation behavior syntactically through binding markers. This restriction enables translation to standard call-by-value lambda calculus while preserving the ability to define custom binding constructs.

## Restricted metaprogramming approaches

Several researchers have explored restricted forms of metaprogramming that preserve some static reasoning capabilities. These approaches generally involve constraining when and how syntactic structure can be observed, though they differ in their specific mechanisms and the extent of their restrictions.

The approach presented in this paper builds upon insights from both macro systems and fexprs while introducing novel syntactic constraints. By making variable bindings explicit through syntactic markers, we enable selective access to syntactic structure: arguments containing explicit bindings remain unevaluated for structural manipulation, while other arguments are evaluated normally. This provides a middle ground between the full power of fexprs and the static analyzability of conventional function calls.

## Comparison with existing approaches

Our explicit binding approach differs from traditional macros in that it eliminates the need for complete macro expansion before optimization can occur. Unlike fexprs, it provides syntactic guarantees about when evaluation occurs, enabling static reasoning about expression equivalence. The key innovation is that evaluation behavior is determined syntactically by the presence of binding markers rather than by runtime type checking or compile-time macro resolution.

# References

\vspace{1em}

::: {#refs}
:::
