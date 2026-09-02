## OOP
OOP was introduced in Fortran 2003 (not available in earlier versions).

Full OOP is built on top of derived types by adding:
- type-bound procedures (methods)
- encapsulation (private fields)
- inheritance & polymorphism (extends, class)


### Derived types
A derived type groups related data into a single entity - like a "class"
in Python. It's the foundation for OOP in modern Fortran, but by itself
it's just data grouping.


### Type-bound procedures
A type-bound procedure links functions and subroutines to a specific
derived type. Inside the type, you write a "contains" section, where you
link functions or subroutines (defined in the module's "contains" section)
by using the "procedure ::" declaration.

So there are TWO contains:
- the one inside the type: DECLARES which methods exist
- the one in the module: holds the actual CODE of those methods

Some extra info:
- Inside a method, declare the passed object (self) as "class(triangle)",
  not "type(triangle)". Reason: "class" allows polymorphism — the method
  works for triangle AND any type that inherits from it. "type" would
  limit it to exactly triangle.
- Methods can be functions (called in an expression: c = tri%centroid())
  or subroutines (called with call: call tri%scale(2.0)).
- The intent of self reflects the method's role:
    - intent(in)    → method only reads/consults the object (e.g. centroid)
    - intent(inout) → method modifies the object (e.g. scale)


### Pure procedures
Use "pure" for functions/subroutines that have NO side effects:
no I/O (read, write, print, open, close), no modifying global/module
state. They only compute from their inputs and return a result.
- Calculation functions (centroid, norm): can be pure.
- I/O subroutines (read_nodes, find_section): CANNOT be pure.
Why it matters: pure functions are safe to parallelize (GPU/OpenACC),
the compiler verifies there are no side effects, and they're easier to
reason about and test.


## About public and private
- When using "private" in a module, EVERYTHING is private unless you
  explicitly make it "public". This includes:
    - functions and subroutines
    - parameters and module variables
    - derived types (the type name itself)
    - even the components (fields) of derived types
- Only names listed in a "public" statement are visible from outside.
- This is encapsulation: the module controls exactly what it exposes.