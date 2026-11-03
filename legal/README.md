# Legal

Everything the app says about privacy, terms, your data and licences lives
here, so changing it is a text edit. Have a lawyer read the policy and the
terms before release: these are plain-English drafts, not legal advice.

| File | What it is | Shown |
| --- | --- | --- |
| `privacy_policy.md` | The Privacy Policy | Create account (the box above Create), Settings, the Data popup and the under 18 popup |
| `terms_of_service.md` | The Terms of Service | Create account and Settings |
| `business.json` | Who runs the app and how to reach you | Filled into both documents |
| `DATA.md` | What data the app keeps, for how long, and what you must do about requests | Not in the app: notes for you |
| `LICENSES.md` | Every font, picture, sound and piece of code the app ships, with its licence | Not in the app: Settings, Licences shows the licences themselves |

## Editing the Privacy Policy or Terms

1. Open the `.md` file in any text editor (or in Godot: double-click it in
   the FileSystem dock).
2. The first line, after `# `, is the popup's title.
3. A line starting `## ` is a heading. A line starting `- ` is a bullet.
   Leave a blank line between paragraphs.
4. Words in braces are filled in for you:
   - `{app}`: the app's name (Project Settings, Application, Config, Name).
   - `{name}`, `{email}`, `{address}`, `{country}`, `{website}`,
     `{policy_updated}`, or any other key you add to `business.json`.
5. Change `policy_updated` in `business.json` whenever either document
   changes.

## Your business details

Fill in `business.json` before release:

| Key | What to put |
| --- | --- |
| `name` | Your name, or your company's legal name |
| `trading_as` | A trading name, if you use one |
| `email` | A support address people can write to about their data |
| `address` | A postal address (UK law expects one for data requests) |
| `country` | Whose law the terms follow, e.g. "England and Wales" |
| `website` | Where the policy also lives online (the App Store asks for a link) |
| `company_number`, `vat_number` | If you register a company or for VAT |
| `policy_updated` | The date the policy or terms last changed |

## Which words are where

The words around the documents (the box's "I agree to the Privacy Policy
and Terms of Service", the under 18 popup, the Data popup) are in
`data/text.json`, under `create`, `data` and `legal`.

## Before release

- Put the policy on a web page too. The App Store and Steam both ask for a
  privacy policy link, and Apple asks for an App Privacy form: with
  everything on the device, it's "Data Not Collected", unless friends or
  sign-in change that (see `DATA.md`).
- Check the open questions at the end of `LICENSES.md`.
