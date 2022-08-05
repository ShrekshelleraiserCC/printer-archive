## Acceptable print formats
* A string (will be forcibly fit to page width)
* A multi-line (partial/full) blit table (BG section is ignored!) [2D blit table]
* Bimg [3D blit table]

## Setting up the printer

1. place a turtle facing a printer. (turtle needs wireless modem on right side)
2. place a hopper above and below the printer and attach modems to each.
3. place a chest below the turtle, attaching a modem to it as well.
4. place a chest for supplies somewhere, attach a modem to it.
5. place an output chest and attach a modem to it.
6. (optional) add a speaker somewhere, attaching a modem to it.

## (terrible) rednet protocol

The printer will host a service on rednet using the protocol named `printer`.

To print a document simply send a message to the printer with the `printer` protocol.
The contents of the message should contain:

```lua
{
  job=string|table, -- the requested print
  title=string, -- an (optional) title for the document
  color=char, -- (optional) the blit character to use when printing a string (defaults to 'f')
}
```

You won't recieve a response back until the document is printed, the response you receive will contain 2 elements.

```lua
{
  [1], -- boolean indicating success
  [2], -- error message of failure
}
```

The printer also makes some information available.
* You can request the ink levels of the printer by just sending the string `getDyeCount`, the printer will respond with a [0-15] indexed table of counts.
* You can request the paper level of the printer by sending the string `getPaperCount`, the printer will respond with a number.