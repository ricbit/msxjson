# MSX JSON Parser

A small library to parse JSON files under MSX BASIC.

## Rationale

There are many network cartridges available for MSX. You may want to use them to connect to the many REST endpoints around us, but many of them only communicate in JSON. This lib provides JSON parsing capabilities to fill this gap.

The lib was designed to blend with MSX BASIC idiomatically, and it uses a macro command interface just like PLAY and DRAW to achieve this goal.

## Features

* Install with `BLOAD "JSON.BIN",R`. This will install three API calls into the `DEFUSR` user routines.
* Optimized for size. The entire lib fits under 1kb.
* Not relocatable. Provided binary loads from `0xD000`, but you can change the `ORG` in the source file if you need a different start address.
* JSON file must be loaded into BASIC-visible memory (`0x8000-0xFFFF`).
* JSON parsing follows [RFC 7159](https://tools.ietf.org/html/rfc7159) to the letter. Take care with caveats of the format (integers may not start with a 0, strings must always use double-quotes instead of single quotes, trailing commas before closing an array is not allowed, etc).
* No extra memory beyond the lib itself. No additional data structures are created when parsing the JSON, to minimize memory usage. However, all lib calls are O(n) in the size of the JSON file.

## Usage

There are three calls available in the API:

* `S=USR(AD)`: Sets JSON start address `AD`.
* `T=USR1(Q$)`: Gets the type of the JSON token pointed by query `Q$`.
* `V$=USR2(Q$)`: Gets the value of the JSON token pointer by query `Q$` as a string.

Detailed usage for each call is as follows:

## `S=USR(AD)`: Sets JSON start address

Sets the JSON start address as the given integer AD. Validates the JSON and returns the validation status. Example:

`IF NOT USR(&H9000) THEN PRINT "NOT A VALID JSON FILE"`

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

```
PRINT USR1("%info")
1
PRINT USR1("%info%name")
3
PRINT USR1("%info%origin")
3
PRINT USR1("%hasCamera")
5
PRINT USR1("%hasMicrophone")
6
PRINT USR1("%password")
7
PRINT USR1("%position")
2
PRINT USR1("%position#0")
4
PRINT USR1("%position#4")
0
PRINT USR1("%unknown")
0
```



