# OOP or not: a guide for picking the tool

A single reference note, not a full course. Starting point: write plain data and
functions, and use an OOP feature only when its specific trigger shows up.

Related topics covered in chat: `enum` vs `enum class`, abstract structs and
`virtual`, `std::variant` + `std::visit`.

---

## 1. Split "OOP" into its parts

"OOP" isn't one thing. Its parts carry very different risks:

| Feature | Verdict |
|---|---|
| Member functions (`c.area()`) | Fine. It's just syntax for `area(&c)`. |
| Private fields + methods (encapsulation) | Use when there's an **invariant**. |
| `virtual` / abstract base | Use only for **open, runtime-mixed, stable** interfaces. |
| Inheritance for code reuse | Almost never. Use composition. |
| Deep hierarchies (depth 3+) | Avoid. |

## 2. The default

**Plain structs + free functions.** Data lives in structs and behavior in functions
that take them.

For "this value is one of several kinds", go down this list and stop at the first
row that fits:

| Situation | Tool |
|---|---|
| Same data for every kind, only behavior differs | `enum class` + `switch` |
| Different data per kind, **closed** set | `std::variant` + `std::visit` |
| Only one operation varies (callback, hook, comparator) | function pointer / `std::function` |
| Type known at compile time, one kind per container | template (+ C++20 concepts) |
| **Open** set, kinds mixed at runtime | `virtual` (or a hand-made ops table) |

## 3. Triggers for each OOP feature

### Private fields + methods

- **Trigger:** fields must agree with each other. Examples: "this vector is always
  sorted", "`len` matches the buffer", "this handle is open or null, never dangling".
- **Otherwise:** keep everything public. `struct Point { double x, y; };` needs no
  getters.
- This matches C++ Core Guidelines **C.2**: use `class` when there's an invariant,
  `struct` when members vary independently. A `struct` with a `private:` section
  works just as well if you prefer the keyword. The only differences between
  `struct` and `class` are the default access and the default inheritance (public
  vs private).

### `virtual` / abstract base

Use it when **all** of these hold:

- The set of kinds is **open**: someone else (users, plugins, another module) adds
  kinds *without editing your code*.
- Kinds are **mixed at runtime** in the same container or call path.
- The interface is **small and stable**: a few methods that rarely change.

Two more legitimate triggers:

- **A library requires it**: its API makes you inherit from its base. Follow the
  API.
- **Swapping a real dependency for a fake in tests** (filesystem, network, clock),
  but try a function pointer or a template parameter first.

When you do use it: write `override` on every override, and give the base a
`virtual ~Base() = default;`.

### Inheritance for code reuse

- "B inherits from A to get A's helpers" → use **composition** instead: B *contains*
  an A, or both call shared free functions.
- Inherit only to implement an interface, not to share code.

### Hierarchies

One interface plus concrete types under it (depth 1) covers nearly all real needs.
`Animal → Mammal → Dog → Poodle` is where OOP goes wrong.

## 4. Smells

### Too much OOP

- An abstract base with **one** implementation and no realistic second one.
- `dynamic_cast` or "what type is this really?" checks. That's a closed set
  dressed up as an open one, so use a variant.
- `protected` data members.
- Inheriting just to reuse code.
- Getters and setters for fields with no invariant.

### Too little OOP

- Users of your code have to **edit your variant** to add their own kind.
- A hand-written struct of function pointers that you keep fighting: entries you
  forgot to fill, casts on `void*` self pointers. That's `virtual` with no compiler
  help.
- The same big `switch` copied into many places, *and* new kinds get added often.

## 5. Meta-rule: wait for the second real case

Don't add an abstraction for one implementation "in case". Write the concrete
thing first. When a **second real** kind shows up, pick enum, variant, function
pointer, or virtual based on what the two actually share. With two examples you can
see the right shape. With one, you're guessing.

---

**Short version:** plain data first. Private fields when there's an invariant.
Virtual only for open, runtime-mixed, stable interfaces. Never inherit for reuse.
