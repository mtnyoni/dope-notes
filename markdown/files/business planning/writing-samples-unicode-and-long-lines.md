---
slug: "writing-samples-unicode-and-long-lines"
title: "Writing Samples — Unicode and Long Lines"
description: "Café, Maputo, café da manhã, and 日本語: sample text for checking UTF-8 cursor movement and wrapping."
---

# Writing Samples

Português: O café está pronto. Amanhã vamos rever o plano e conversar com a equipa.
Français: Les idées évoluent grâce aux échanges avec les clients.
日本語: 小さな改善を毎週続けます。

This intentionally long paragraph has no manual line breaks, so the editor must wrap the text according to the available width and continue to position the caret correctly as the window becomes narrower or wider. Moving the buffer gap through this paragraph must not change the displayed spacing or create an artificial break between the text before the cursor and the text after it.

Short line.

Another paragraph after an empty line.

End of sample.
