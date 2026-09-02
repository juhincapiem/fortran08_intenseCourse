## OOP
Only availabel in mdoern Fortran.

Full OOP is built on top derived types by adding:
- type-bound procedures (methods)
- encapsultaion (private fields)
- in heritance & polymorphism (extend, class)


### Derived types
A derived type groups related data into a single entity - like a "class" in python. It's the foundation for OOP in modern Fortran, but by itself it's just data grouping.  




## About public and private
- When using "private" in a Module, EVERYTHING is private unless you explicitly made "public". This includes:
    -functions and subroutines
    - parameters and modules variables
    - derived types
    - even the components (fields) of derived types
- Only names listed in a "public" statement are visible from outside
- This is encapsulation: the module controls exactly what it exposes. 