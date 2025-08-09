# MSX JSON Parser

A small library to parse JSON files under MSX BASIC.

## Rationale

There are a lot of network cartridges available for MSX. You may want to use them to connect to the many REST endpoints around us, but most only communicate in JSON. This lib provides JSON parsing capabilities to fill this gap.

The lib was designed to blend with MSX BASIC idiomatically, and it uses a macro command interface just like PLAY and DRAW to achieve this goal.

## Features

* Install with `BLOAD "JSON.BIN",R`. This will install three API calls into the `DEFUSR` user routines.
* Optimized for size. The entire lib fits under 1kb.
* Not relocatable. Provided binary loads from `0xD000`, but you can change the `ORG` in the source file if you need a different start address.
* JSON file must be loaded into BASIC-visible memory (`0x8000-0xFFFF`).
* JSON parsing follows [RFC 7159](https://tools.ietf.org/html/rfc7159) to the letter. Take care with caveats of the format (integers may not start with a 0, strings must always use double-quotes instead of single quotes, trailing commas before closing an array are not allowed, etc).
* No extra memory beyond the lib itself. No additional data structures are created when parsing the JSON, to minimize memory usage. However, all lib calls are O(n) in the size of the JSON file.
* Unit-tested to ensure lib quality.

## Usage

There are three calls available in the API:

* `S=USR(AD)`: Sets JSON start address `AD`.
* `T=USR1(Q$)`: Gets the type of the JSON token pointed by query `Q$`.
* `V$=USR2(Q$)`: Gets the value of the JSON token pointer by query `Q$` as a string.

Detailed usage for each call is as follows:

## `S=USR(AD)`: Sets JSON start address

Sets the JSON start address as the given integer AD. Validates the JSON and returns the validation status. Example:

`IF USR(&H9000)=0 THEN PRINT "NOT A VALID JSON FILE"`

Status code on return follows the MSX BASIC boolean convention:

* 0 = JSON is invalid
* -1 = JSON is valid

This call is always required. Further calls to `USR1` and `USR2` will fail if there is not a valid JSON file set up by this call.

Errors:
* Returns `Type mismatch` if `AD` is not an integer.

## `T=USR1(Q$)`: Gets type of JSON token

Gets the type of JSON token pointed by query `Q$`. The return code is an integer whose meaning is:

* 0 = nothing found
* 1 = object (dict)
* 2 = array
* 3 = string
* 4 = number
* 5 = true
* 6 = false
* 7 = null

Suppose you have made a query to your drone api and received this JSON:

```json
{
        "info": {
                "name": "Cool Drone",
                "origin": "China"
        },
        "hasCamera": true,
        "hasMicrophone": false,
        "password": null,
        "position": [1.0, 2.0, -1.0]
}
```

These are some sample queries:

```basic
PRINT USR1("&info")
1
PRINT USR1("&info&name")
3
PRINT USR1("&info&origin")
3
PRINT USR1("&hasCamera")
5
PRINT USR1("&hasMicrophone")
6
PRINT USR1("&password")
7
PRINT USR1("&position")
2
PRINT USR1("&position#0")
4
PRINT USR1("&position#4")
0
PRINT USR1("&unknown")
0
```

The format for the query `Q$` is described below.

Errors:
* Returns `Type mismatch` if `Q$` is not a string.
* Returns `Invalid function call` if `Q$` is not in the format expected.
* Returns `Invalid function call` if `USR(AD)` was not called first.

## `V$=USR2(Q$)`: Gets value of JSON token

Gets the value of the JSON token pointer `Q$`. The value is always returned as a string, even when the JSON token type is different. For instance, the number `10` will be returned as a string `"10"`. To differentiate between `10` and `"10"`, you need to check the type returned by `USR1(Q$)`.

Some sample queries for the JSON above:

```basic
PRINT USR2("&info&name")
Cool Drone
PRINT USR2("&info&origin")
China
PRINT USR2("&hasCamera")
true
PRINT USR2("&hasMicrophone")
false
PRINT USR2("&password")
null
PRINT USR2("&position#0")
1.0
```

If the string length is greater than 255 chars, then only the first 255 chars will be returned (this is a limitation of MSX BASIC).

Errors:
* Returns `Type mismatch` if `Q$` is not a string.
* Returns `Invalid function call` if `Q$` is not in the format expected.
* Returns `Invalid function call` if `USR(AD)` was not called first.
* Returns `Invalid function call` if the JSON type is not string, number, true, false or null.

## Query format

There are currently three commands in the macro language used by the queries:

* `#N`: Traverse to the `N`-th element of this collection (object or array). The numbering is 0-based.
* `$`: Traverse to the value pointed by the current object key.
* `&KEY`: Traverse to the value pointed by the given key.

Let's again consider the JSON file above. The `#N` command retrieves the `N`-th element of an array or object:

```basic
PRINT USR2("#0")
info
PRINT USR2("#1")
hasCamera
PRINT USR2("&position#0")
1.0
PRINT USR2("&position#1")
2.0
PRINT USR2("&position#2")
-1.0
```

For objects, the element pointed is always the key. If you want the value pointed by the key, you need the command `$`:

```basic
PRINT USR2("#0")
info
PRINT USR2("#0$#0")
name
PRINT USR2("#0$#0$")
Cool Drone
```

If the object or array is shorter than the query, `USR1(Q$)` will return zero, and `USR2(Q$)` will return `Invalid function call`. You can use this to find the length of an array:

```basic
PRINT USR1("&position#0")
4
PRINT USR1("&position#1")
4
PRINT USR1("&position#2")
4
PRINT USR1("&position#3")
0
```

Spaces are allowed between `#` and the number, to facilitate BASIC usage with `STR$`:

```basic
PRINT USR2("# 0")
info
```

The `&` command retrieves the value pointed by a key. No spaces are allowed between `&` and the key, as the key may contain spaces. Keys containing the chars `$&#` are not allowed. String comparison is a naive byte-oriented comparison, escapes and unicode will not work with this command.

```basic
PRINT USR2("&info&name")
Cool Drone
```

## Credits

Written by Ricardo Bittencourt in 2017. Free for commercial usage (a note in the credits is appreciated).

