<div align="center">
<img src="IconComposerExport.png" alt="IconComposerExport" width="256">

# Icon Composer Export

</div>

## What it does

[Icon Composer](https://developer.apple.com/icon-composer/) (new in Xcode 26) authors app icons as `.icon` bundles that can define separate light, dark, and tinted (monochrome) appearances. This tool wraps Apple's own `actool` and `iconutil` command line tools to render a `.icon` bundle into full-size PNGs, so you can drop the result straight into a README, a website, or anywhere else that just wants a plain image.

## Limitations

**Only the light and dark appearances can be exported. Tinted (monochrome) export is intentionally not supported.**

Icon Composer's tinted appearance isn't just "whatever the icon author put in a tinted override" — the system automatically converts *every* layer to a monochrome silhouette, including layers that have no explicit tinted override at all. This tool works by rewriting an icon's `icon.json` so that a requested appearance's overrides become the default values, then asks `actool` to render that as a normal static icon. That trick reproduces `dark` correctly, since dark overrides are genuinely optional per layer and unoverridden layers are supposed to keep their light-mode color. But it cannot reproduce `tinted` correctly for most real icons, since it can only promote overrides that were actually authored — any layer without an explicit tinted override would incorrectly keep its full light-mode color instead of turning monochrome. Rather than silently producing a wrong asset, `--appearance tinted` is not offered at all.

If your icon happens to define an explicit tinted override for every single color-bearing layer, this limitation doesn't affect it in practice — but this tool has no way to verify that, so it doesn't try.

## But why

Because I want to have them in my GitHub READMEs. And either no one else cares or I am incapable or searching the web properly. This could have been a shell script, too, I know. Anyway, here it is.

## Requirements

- macOS 26 or later
- Xcode 26 or later (for `actool`/`iconutil`, and to build the tool itself)

## Building

```
swift build -c release
```

The built binary ends up at `.build/release/icon-composer-export`. Alternatively, run it directly without a separate build step:

```
swift run -c release icon-composer-export <input> [--appearance <appearance>] [<output>]
```

## Usage

```
USAGE: icon-composer-export <input> [--appearance <appearance>] [<output>]

ARGUMENTS:
  <input>                 Path to the Icon Composer (.icon) file to render.
  <output>                Directory to write the rendered PNG(s) into. Defaults
                          to the input file's directory.

OPTIONS:
  --appearance <appearance>
                          Which appearance to render: light or dark. If
                          omitted, both are rendered. (values: light, dark)
  -h, --help              Show help information.
```

### Examples

Render both light and dark next to the input file:

```
icon-composer-export MyIcon.icon
```

Render just the dark appearance:

```
icon-composer-export MyIcon.icon --appearance dark
```

Render everything into a specific directory:

```
icon-composer-export MyIcon.icon ./exported-icons
```

## License

[MIT](LICENSE)
