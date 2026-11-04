## General UI & UX
- Make sure all UI components added here adhere to the UI style and standards already set out (Storybook theme)
- Buttons & dropdowns should have a slight shadow to give the illusion of a depth to them. This shadow should be bolder than the vague shadows we have at the moment. Mimicing balatro's chunky ui. This will need you to replace the grow/shrink on hover with a new hover: shade and click: shadow disappear.
- When the visuals of the app change because of time (revisiting the focus screen after long focus away, the focus button changing color throughout the day, position of the sun/moon and color of sky in home screen, etc) \
  you should use tweens for the color and positions of things to make sure that the transition is smooth and not sharp. It should cover 0.1s per hour of time difference.
- Project panel popups are not correctly sized to stay on screen. Sometimes the Pets/Places panel is not centralised and the 'x' clips off screen if the title / focus time is too long.
- On both desktop & mobile, vertical/horizontal swipes shoudl be detected with less motion, accomodating for the longer edge (so you need to swipe less up/down on mobile, and less left/right on desktop)
- For all text entry input elements, prevent input including symbols and spaces to prevent malicious injection. If the text contains such characters, fade in + wiggle some red text underneath the text area conveying an error message.

## Home Screen
- On startup, the app should use the same animation as when you've created an account ('camera' pans up to reveal parallax scenery, focus button popups up, quote types out, ui fades in)
- (when no active holiday) the focus button should be a color between green & blue, depending on the time of day. Blue at midnight, green at midday. In between the color should shift shades every 5 mins. Use the tweening methods from the general UI & UX instructions above for the transitions.

## Projects Screen
- Remove 'Longest' stat.
- Reduce stat panel to be the same height as the stat panel in the Gifts screen, and therefore simplify time values (only show most significant time value- if 1hr 30 mins, show 1.5h. if 45 mins show 45m. if 20 seconds, show 20s)
- Move up project list to fill the space
- 'Swipe Left To Complete' should be 'Your Projects | Swipe to Complete/Delete' (where the instruction section is in smaller font size than 'Your Projects')
- On mobile only, turn the Pets & Places leaderboard to only show one at a time, decided by a dropdown top right of that section. Hide the 'Pets' and 'Places' in this version.
- Give completing a project a toast, and style both the delete and complete with danger and success colors. Move the 'undo' button to anchor to the right of the toast and give it an undo icon to the right of its text. Apply this to deleting pets in the choose focus screen too.

## Gifts Screen
- Remove the 'Stats' label above the general stats panel
- For all gift popups, add a 'Cosmetic' badge to any gift that can be worn, replacing the description's 'Can be worn' repeated section. Shoudl show next to the gift name.

## Stats Screen
- Get rid of week history panels below stats graph- navigate between time periods w/ arrows to the left & right of the 'This {time period}' & '{Total focus time for this period}' (respectively), then make both graph panel and friends leaderboard bigger to fill the gap evenly.
- Add an add friend ghosted button icon to the top right of the friends leaderboard panel. Should bring up a popup with a search bar that'll let you search the database for friends unique usernames (they don't have this yet so dw)
- Delete the 'rest day' function for streaks.
- On clicking the streak flame icon, the icon + time text should fade out in 0.1s and your streak record, with a line art of a golden trophy cup holding a flame as the icon should fade in in 0.1s.

## Focus Screen
- Replace the long and intrusive weather chooser dropdown with a list of icons to represent each weather state, and make the button small and round. The location based option should use the current weather of your location as the base icon (slightly offset left & up) and overlay it with a map pin icon (slightly offset right & down) to show it's based on your location.
- When an animal jumps out of the bush again with your present it should return to rotation 0 on landing.
- End focus pie chart separating lines should be thinner and match the light/dark theme. Get rid of the surrounding outline, make it fill up its whole circle with color.
- In light mode, focus quote is hard to read (the shadows and transparency are bad, make the text muted instead with no shadow)
- The volume and pause buttons should be ghosted buttons and just be icons.

## General
- Restructure all .json files to have one attribute per line. Makes it easier for me to edit them.
- Convert all app icno files to .svg - they get blurry on my phone
- Once all is and merged into dev, branch off again and aggressively delete dead code
