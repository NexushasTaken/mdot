# hybrid

**$value** - printable value
**descrive_value(value)** - represents the actual value
  returns
    - `if type(value) in [boolean, string, integer, number]` - tostring(value)
    - else - empty string
**descrive_type()** - describe the type in `types.*`

**public methods**
- expect_type(value: any, expected: type): string
  returns
    - `if #describe_value(value) == 0` - `expected type $value.describe_type(), got $value.descrive_type()`
    - else  - `expected type $value.describe_type(), got $value.descrive_type(): $descrive_value()`

### builtin types list

- types.boolean - checks for type(val) == "boolean"
  **descrive_value()** - `true` or `false`
  **descrive_type()** - `boolean`

- types.number - checks for type(val) == "number"
- types.integer - checks for a number with no decimal component `n % 1 == 0`
    - `if n % 1 ~= 0` - `expected value to be number with no decimal point(integer), got: $descrive_value(value)`
**number and integer methods**
  - range(min: number, max: number, inclusive?: boolean) - if exclusive then `$min < $value < $max` else `$min <= $value <= $max`
    **error messages**
      - `expected value to be "$value.descrive_type()", got $descrive_value(value)`
**descrive_value()** - `$value`
**descrive_type()**
  - `if min and max`: exclusive `$min < number < $max` or inclusive `$min <= number <= $max`
  - `if not min and max`: exclusive `number < max` or inclusive `number <= max`
  - `if min and not max`: exclusive `number > min` or inclusive `number >= min`

- types.string - checks for type(val) == "string"
  **methods**
    - length_range(min: number, max: number) - both min and max is inclusive
    - pattern(pattern: string)
  **descrive_value()** - `"$string"`
  **descrive_type()** - `"string"`

- types.array - checks for table of numerically increasing indexes
  **methods**
    - length_range(min: number, max: number) - both min and max is inclusive
  **descrive_type()** - `array`

- types.table - checks for type(val) == "table"
  **descrive_type()** - `table`
- types.func - checks for type(val) == "function"
  **descrive_type()** - `function`
- types.null - checks for type(val) == "nil"
  **descrive_type()** - `nil`
- types.userdata - checks for type(val) == "userdata"
  **descrive_type()** - `userdata`
- types.any - succeeds no matter value is passed, including nil
  **descrive_type()** - `any`

**error messages** for all builtin types
  for boolean, string, integer, number - same as `expect_type(value, type)`
  for array, table, func, null, userdata - same as `expect_type(value, type)`
  **probably** no error message for types.any?

**methods**
  methods for all builtin types
  - is_optional() - checks if the value is nil; but types.null doesn't have this method
  - describe_value() - return empty string if its not boolean, string, integer or number

## type constructors
- types.one_of(types, ...) - checks if value matches one of the types provided
  **describe_type()** - return valid types
  **error messages** - `expect_type(value, $describe_type())`
- types.map_of(type_pair, ...) - checks if value is table that matches key and value types
  **describe_type()** - return valid key-value pairs types
  **errors messages**
    - if type(value) is not valid key type - return valid key types
    - if type(value) is valid
      - return the first error that is invalid value type
- types.tuple(type, ...) - <description>

- types.array_of - checks if value is array containing a type
**array_of methods**
- length_range(min: number, max: number) - both min and max is inclusive

- types.shape - checks the shape of a table

## undecided
- types.literal - checks if value matches the provided value with ==
- types.range - checks if value is between two other values

- types.proxy - dynamically load a type checker
- types.equivalent - checks if values deeply compare to one another
- types.custom - lets you provide a function to check the type
- types.array_contains - checks if value is an array that contains a type (short circuits by default)
- types.pattern - checks if Lua pattern matches value
- types.partial - shorthand for an open types.shape
