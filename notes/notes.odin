package notes

import "base:runtime"

Note :: struct {
	slug:        string,
	title:       string,
	description: string,
	content:     []u8,
}

get_note_by_slug :: proc(slug: string) -> ^Note {
	for &note in notes_list {
		if note.slug == slug {
			return &note
		}
	}
	return nil
}

// Varied lengths exercise sidebar clipping, editor wrapping, and scrolling.
notes_list := [?]Note {
	{
		slug = "summary",
		title = "Summary",
		description = "Three decisions.",
		content = dummy_article_bytes(
			`Launch the pilot next month.
Keep the first release small.
Talk to customers every Friday.`,
		),
	},
	{
		slug = "business-plan",
		title = "Business Plan",
		description = "A practical plan for a small customer-feedback service.",
		content = dummy_article_bytes(
			`Business Plan

We help independent shops understand the feedback they already receive. Owners can collect comments, group recurring requests, and choose one improvement to try each week.

The first release should support one workspace, a simple inbox, and a weekly summary. We will recruit five local businesses for a four-week pilot.

Success means that at least three owners return each week and can describe a decision they made using the service.`,
		),
	},
	{
		slug = "financial-plan-and-first-year-operating-budget",
		title = "Financial Plan and First-Year Operating Budget",
		description = "Launch costs, monthly spending, pricing experiments, and the assumptions behind our first-year revenue targets.",
		content = dummy_article_bytes(
			`Financial Plan

These are planning assumptions for a fictional business, not actual financial results.

Launch budget
- Design and prototype: 1,200 units
- Equipment and setup: 800 units
- Customer research: 300 units
- Reserve for unexpected costs: 700 units

Monthly operating costs
Hosting starts at 60 units. Tools and administration add 90 units. We will cap experiments at 150 units per month until customers demonstrate repeat use.

Pricing
The pilot is free. After the pilot, we will test a single plan at 25 units per workspace per month. We will ask customers whether the weekly summary saves enough time to justify the price.

Revenue assumptions
Ten paying workspaces would produce 250 units per month before expenses. Forty would produce 1,000 units. Neither number is a forecast; both are checkpoints for evaluating demand.

Review
Compare actual spending with this budget every month. If acquisition costs rise or renewals fall, pause expansion and investigate before committing more money.`,
		),
	},
	{
		slug = "customer-interview-notes",
		title = "Customer Interview Notes: What Owners Need Before They Will Trust an Automated Weekly Summary",
		description = "A longer research note covering busy mornings, inconsistent feedback, trust in generated summaries, and the need to trace every recommendation back to the original customer comment.",
		content = dummy_article_bytes(
			`Customer Interview Notes

Research question
How do small-business owners decide which customer requests deserve attention?

Interview 1: The café owner
The owner receives comments in person, through delivery apps, and on social media. The difficulty is remembering which problems happened repeatedly. A single angry review can feel more urgent than ten quiet requests for a better collection process.

She wants a short summary with examples. A recommendation without the original comments is difficult to trust. She would rather read three useful observations than a page of confident conclusions.

Interview 2: The repair shop
The manager keeps a notebook beside the till. Staff write short notes between customers, so spelling, language, and detail vary. He needs the system to preserve the original wording while grouping related concerns.

He also wants to mark an issue as resolved. Otherwise, last month's delay keeps appearing in every discussion even after the team changes its process.

Interview 3: The clothing store
The owner reviews feedback once a week, usually after closing. She compares complaints with returns and sales. A summary is useful only if it distinguishes product problems from delivery problems.

Patterns
- Owners want evidence attached to each observation.
- Repeated requests matter more than isolated comments.
- Resolved issues should remain searchable without dominating the next summary.
- Teams need a way to correct an inaccurate category.

Open questions
Would owners invite staff into the same workspace? How much history should the default view show? Which languages appear most often in each business?

Next steps
Build a small prototype with linked evidence, editable categories, and a resolved state. Ask the same owners to use it with their own comments before adding more features.`,
		),
	},
	{
		slug = "release-checklist",
		title = "Release Checklist",
		description = "Small checks before shipping.",
		content = dummy_article_bytes(
			`Release Checklist

[ ] Create, edit, and delete a note.
[ ] Type past the end of a visible line.
[ ] Press Enter on an empty line.
[ ] Move Up and Down through short and long lines.
[ ] Resize the window while editing.
[ ] Confirm sidebar descriptions stop before the right padding.
[ ] Confirm a long document follows the caret when scrolling.
[ ] Save changes and reopen the application.`,
		),
	},
	{
		slug = "writing-samples-unicode-and-long-lines",
		title = "Writing Samples — Unicode and Long Lines",
		description = "Café, Maputo, café da manhã, and 日本語: sample text for checking UTF-8 cursor movement and wrapping.",
		content = dummy_article_bytes(
			`Writing Samples

Português: O café está pronto. Amanhã vamos rever o plano e conversar com a equipa.
Français: Les idées évoluent grâce aux échanges avec les clients.
日本語: 小さな改善を毎週続けます。

This intentionally long paragraph has no manual line breaks, so the editor must wrap the text according to the available width and continue to position the caret correctly as the window becomes narrower or wider. Moving the buffer gap through this paragraph must not change the displayed spacing or create an artificial break between the text before the cursor and the text after it.

Short line.

Another paragraph after an empty line.

End of sample.
`,
		),
	},
}

// Fixtures own writable bytes for the lifetime of the application.
dummy_article_bytes :: proc "contextless" (text: string) -> []u8 {
	context = runtime.default_context()
	bytes := make([]u8, len(text))
	copy(bytes, transmute([]u8)text)
	return bytes
}
