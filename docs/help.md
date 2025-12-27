---
{
  "IncludeTOC": true,
}
---

# Mavis AAC Help

Mavis AAC has a few features designed to make composing messages easier.

This application was originally designed and built for a specific person who was a very competent typist, but who also possessed a distinct antipathy for computing technology.

The default settings and capabilities were strongly influenced by her needs and abilities as well as my best guesses on how to make living with this technology easier for her. There are many possible ways to modify and improve the software for specific needs.

# Text To Speech Intro

You can be lazy. Text to speech does not care about capitalization and usually doesn't care much about homophones either - *their*, *they're* and *there* are all pronounced about the same.

Sometimes there are subtle differences with some punctuation, like hyphens and commas. It might be noticeable, but is generally not distracting.

Unfortunately, right now most of the voices don't recognize the difference between `"Hello."`, `"Hello?"` and `"Hello!"` -- that's a current limitation of the Apple Speech synthesizer.

If there is a persistent problem, there are ways to tweak pronunciation inside the voice synthesizer. See the section on [Fixing Pronunciations](#fixing-pronunciations) for me details.

# Keyboard Navigation

You shouldn’t need to use menus with Mavis AAC most of the time. Hunting through menus takes your fingers off the home row and ends up slowing you down.

Whatever you type in the composition text will be spoken when you press **Return**.

The last 10 phrases are remembered and you can quickly access them using the **Command** key ⌘ and up ↑ and down ↓ arrow keys.

⌘Delete will remove the currently selected history item.

All the standard Mac keyboard tricks work - for instance ⌘A will select all text and you can then delete it all with the **Delete** key. That will let you quickly start over.

⌘← and ⌘→ (**Command** with the left or right arrow keys) will let you skip to the beginning or end of the composition.

⌥← and ⌥→ (**Option** with the left or right arrow keys) will let you skip backward and forward word by word.

⌥ Delete (Option with Delete) will delete a "word" backwards.

# Message History

If you need to quickly repeat the last message, **Command** key and Return **⌘-Return** will respeak the last message.

Alternatively, **Command** key and up arrow **⌘↑** will recall the last message in the history. **Return** will speak it aloud.

# Tab Completion

When you press the **Tab** key, Mavis AAC will suggest matching options from the list of preconfigured phrases and available soundbites based on the text already typed. Even small fragments of words can be used and they need not be in order. Matches will be ordered and the best match will be the last in the list, automatically selected.

For instance:
`blinds up`

Might result in the following suggestions:
 * It was nice catching up
 * Ask me Yes-No questions. It will speed things up.
 * **Could you raise the blinds up please?**

All of those match some fragment, but the last one matches "best" and would be selected automatically.

When the completion menu is showing, you can navigate the completion choices with the up **↑** and down **↓** arrow keys.

The first press of the **Return** key will accept the current highlighted completion, and a second press of **Return** will speak the text aloud.

The **Escape** key (**esc** on the top left of your keyboard), cancels the completion menu and selects nothing.

> NOTE: There is no "best" way to do completions. This mechanism proved simple, fast, predictable and moderately effective. However, there are many ways to potentially alter the behavior.

When there is nothing typed, **Tab** brings up a list of all phrases and soundbites.

# FaceTime Calls

If you are on a FaceTime call, you can add Mavis AAC to the call so you can speak with both your voice and the synthesizer.

Go to the **Chat** menu and select **Start SharePlay**. SharePlay is the name of a FaceTime feature that allows you to share a window on your computer with the person you are talking to.

Though this works on MacOS, it is much better supported on iOS devices.

# Speak Sentences Automatically

Mavis can (and does by default) automatically speak each sentence while you type. Technically, it speaks every time the space bar is pressed and the previous sentence ends with a period, exclamation point or question mark.

There is a preference for this in the **Chat** menu - **Speak Sentences Automatically**.

# Fixing Pronunciations

Under the **Window** menu select **Edit Pronunciations**.

Each line of this file corrects the pronunciation of a word.

For example, this line below tells the voice synthesizer that "Ez" - should be pronounced like "Ezz" - short for Ezra - instead of like E-Z as in "easy."

```
Ez|Ezz
```

This can't solve homographs (***read** 'em and weep* versus *I **read** that yesterday*), but if that's a problem, let me know. It's not unsolvable, just harder.

There is no requirement that pronunciation corrections have much to with the orthography. For instance, you can also do:

```
pepsi|coke
ttyl|talk to you later
ty|thank you
thx|thanks
```

The only limitation is that only single words are matched.


# Soundbites

Soundbites are voice bank recordings that you can play them back exactly as recorded. The catch is that what you type into Mavis must exactly match the phrase.

If you don't remember the exact phrase, type "z" and hit the **Tab** key - that will bring up all known phrases. You can scroll through them or type a few characters to show a limited set of matching results.

You can disable **Soundbites** in the **Chat** menu.

> NOTE: Soundbites do not play over Facetime or phone calls.


# Noisy Typing

Noisy Typing plays an audible click sound when you type into Mavis. This plays over the speakers to let people know that you are typing "conversationally", not beavering away on some other distraction on your device.

You can disable **Noisy Typing** in the **Chat** menu.

> NOTE: Noisy typing sounds do not play over Facetime or phone calls.


# Ring Bell

The Ring Bell button (or **Command-R** or **⌘R**) plays a ringing bell sound to get someone's attention without removing what you've already typed into Mavis.

The Double Bell button (or **Command-Shift-R** or **⌘⇧R**) is a litte louder and more aggressive.

The bell sounds were selected to be pleasant, but still capable of getting attention

The volume of the ring can be adjusted in the **Settings**.


# SMS Button (MacOS only)

The SMS button sends a pre-composed message via Apple Messages to get someone's attention. This may be delayed for a while, or not arrive - it's just sending a text message.  The recipient and message are controlled in **Settings**.


# Settings

Adjusting the voice and volumes for various features is possible via the **Settings** panel.

## Voice Controls

Choose your voice and set it's basic speaking properties.

## Sound Effects

Adjust the volume of various sound effect.

## Adjusting The Font Size

Use the **Font** menu and the aptly named **Bigger** and **Smaller** options to adjust your font size so you can use it easily.

## Configuration

**Edit Pronunciations** and **Edit Phrases** should be self-explanatory.

**Import File** allows you to import several different special files that you have saved on your device.

### soundbites

**Show Soundsbites** under **Window** will open the directory where you can place soundbite files.

Any number of sound files that are in the `.wav` or `.m4a` formats can be placed here. The name of each file will be used as the text to use when matching a soundbite. The matching is not case sensitive, but punctuation matters.

For instance `Hello.wav` and `Hello!.wav` could be distinct entries. Typing "hello" would only match the first. "hello!" would only match the second.


# Open Script (MacOS Only)

This is a very simple and rough feature that allows you to stage a conversation ahead of time to save time typing. This has been used for either phone calls or in-person conversations with a doctor.

You can paste in series of paragraphs. Right-clicking on a line will let you speak it aloud.

It is not a full featured editor and there is no undo support. This is not necessarily a good place to compose your conversation, though it is possible to do so.

# Enable Corrector (MacOS Only)

The corrector is a small-ish neural network that tries to turn keyboard input with typos into something approximating human speech when you press the Tab key.

This currently replaces the default tab complete feature when enabled, though this could be easily adjusted.

It will generate up to 5 candidate corrections in approximately one second. Experiments show that is has a reasonble chance of offering the correct answer. This is an area of interest and potential improvement.

It is not enabled by default because it is not always correct and not clearly of value in all cases, particularly if typing/motor skills are reasonable.

You can turn this feature on/off under the **Chat** menu using the **Enable Corrector** menu option.

### Show Corrections Automatically

If the built-in spell/grammar checker detects you have an error, Mavis can automatically trigger the correct when you try to speak something that likely won't make perfect sense.

This is useful as long as the builtin dictionary match the words you normally use. This is on by default if you enable the corrector, but it can be turned off separately via the **Show Corrections Automatically** menu item in the **Chat** menu.

### Corrector Goals

This feature evolved from observing our first user. As progressive loss of motor control led to both increased typos and increased correction time, the goal was provide a reasonable chance (>70%) of correction within a couple of simple keystrokes to prevent frustration.

# Warnings and Alerts

## Default Voice Warning

If Mavis does not find a Personal, Enhanced or Premium voice to use it will show a dialog on launch. It will instead pick the first voice in the system language that is installed.

If you select **Take Me To Settings**, the **System Settings** app will open to the **Live Speech** section. There you can use the **Voice** section to select "Manage Voices..." which will allow you to download and install other voices from Apple.