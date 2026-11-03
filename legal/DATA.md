# Your users' data

What the app keeps, where, for how long, and what that means for you. Last
checked 1 November 2026, against the app as it is now.

## What's kept

| What | Example | Why | Where |
| --- | --- | --- | --- |
| Name | "Sam" | Shown on your profile, to friends later | This device |
| Where you study | "University of York" | Your profile; never shown to friends | This device |
| Date of birth | 2012-03-14 | Under 18s need a parent's approval; birthday events | This device |
| When you agreed to the policy and terms | a timestamp | Proof of agreement | This device |
| Character look | hat, colours | Your character | This device |
| Projects and pets | "Dissertation", grades | The app itself | This device |
| Focus time per day | seconds per project, pet and place | Stats, levels, achievements | This device |
| Gifts, shelf, XP | | The app itself | This device |
| Settings | sound on | | This device |
| Rough location (only with Local sunrise and weather on) | Leeds, 53.8, -1.5 | Real sunrise and weather | This device; looked up through GeoJS, weather from Open-Meteo |

The save is one JSON file per account in the app's own folder (`user://`),
plus a `.bak` copy. Nothing is sent to you: there's no server, no
analytics and no adverts. GeoJS and Open-Meteo see the device's internet
address when the location setting is on.

## Do you need data requests and deletion?

Yes, and the app already handles them itself:

- **Access and portability**: Settings, Data lists what's kept, and
  Download saves it all as a JSON file (on a computer, wherever you pick;
  on a phone, in the app's folder in Files).
- **Deletion**: Settings, Data, Delete removes the account's save, its
  backup and any old copies from the device, and forgets the rough
  location. Deleting the app removes everything.

While everything stays on the device you hold none of it, so there's
nothing for you to look up or delete when someone writes in: point them to
Settings, Data. Under UK GDPR you still need the policy, a contact address
and to answer within a month.

## Retention limits

None needed while it's all on the device: it stays until the person deletes
it, which they control.

## When friends and accounts arrive (roadmap phase 4)

Data then leaves the device, so you become responsible for it. Plan for:

- **Keep less**: send friends only what they see (name, character, shelf,
  achievements, weekly minutes). Never send where someone studies or their
  date of birth. Keep the date of birth on the device; the server only
  needs "under 18 or not".
- **Retention**: delete accounts that haven't signed in for 2 years, after
  an email warning a month before. Delete server backups within 30 days of
  an account going.
- **Requests**: Data's Download and Delete should also fetch and delete the
  server copy, so requests stay self-service. Answer emailed requests
  within a month.
- **Children**: the parent approval popup is enough on the device. With a
  server, under 18s fall under the ICO's Children's Code: high privacy by
  default (friends off until turned on, no public profiles).
- **Processors**: list your hosting provider in the policy, and have a data
  processing agreement with them.
- Update the policy, `DATA.md` and the App Store privacy form.
