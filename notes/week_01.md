# Week 1 — Modern Fortran Basics

> Personal learning notes. Written in my own words.
> Two goals: (1) remember what I undestood, (2) quick syntax cheatsheet

----

## Software Engineering Practices: Git workflow

### The three zones
- **Working directory** --> files as they are on my disk (where I write and edit)
- **Staging area** --> the "waiting room" for the next commit ('git add')
- **Repository** --> saved the history of commits ('git commit')
- **Online repository** --> finally, you can upload your files to GitHub ('git push')

### Commit rhythm
- One commit per coherent, finished unit (e.g. one exercise that compiles)
- Small and frequent commits
- Commit several times per session, while Push at the end of the session


## What I've learned about Fortran so far

### At the beginning of the program
- Code must be between "program name" and "end program name"
- After the "program" line, always write "implicit none", which deactivates a very weird rule that defines variables types depending on the first letter of the variable's name
- Best practice: one line to declare the variable, and another one to assign a value to it (initialization)
- What if... I initialize a varible on the same line where it's declared? It has a hidden effect: it receives the attirbute SAVE, which causes its value to remain constant between calls. 


### Variable types
- I've used 4 types so far: integer, real, character and logical.
- For double precision: use (kind=8) which means 8 bytes, or 64 bites. I've heeard about a more fancy way to declare double precision... Lets see what happen in the future

### Conditional
- if + then
- else if + then
- else
- end if

### Input/Output format
- When using "print" or "write" commands, you have to inform the type of variable are going to be printed on terminal. For e.g., if you a string and then a real number, it would be    '(A, ES12.4)'
- "ES" is scientific notation, where "S" means scientific and "E" is the exponent. The number 12 means the total length for that field, 4 is the numer of decimals. 
