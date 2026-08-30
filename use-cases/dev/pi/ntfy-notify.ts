import type {
  ExtensionAPI,
  SessionEntry,
} from "@earendil-works/pi-coding-agent";

const NTFY_URL =
  process.env.PI_NTFY_URL ?? "https://ntfy.skylake.mihaly.codes/home-clanker";
const WEB_URL = "https://ntfy.skylake.mihaly.codes/home-clanker";

const INPUT_RE =
  /\b(should i|shall i|would you like|would you prefer|want me to|do you want|let me know|your call|proceed)\b/i;

function lastAssistant(branch: SessionEntry[]) {
  for (let i = branch.length - 1; i >= 0; i--) {
    const entry = branch[i];
    if (entry.type !== "message") continue;
    const message = entry.message;
    if (message.role !== "assistant") continue;
    const text = message.content
      .filter((c) => c.type === "text")
      .map((c) => c.text)
      .join("\n")
      .trim();
    return { text, stopReason: message.stopReason };
  }
  return { text: "", stopReason: undefined };
}

export default function (pi: ExtensionAPI) {
  pi.on("agent_settled", async (_event, ctx) => {
    const { text, stopReason } = lastAssistant(ctx.sessionManager.getBranch());
    if (!text || stopReason === "aborted") return;

    const name =
      ctx.sessionManager.getSessionName() ??
      ctx.sessionManager.getCwd().split("/").filter(Boolean).pop();
    const needsInput = text.endsWith("?") || INPUT_RE.test(text);
    const kind = needsInput
      ? "input"
      : stopReason === "error"
        ? "error"
        : "done";
    const titles = {
      input: "pi needs input",
      error: "pi error",
      done: "pi done",
    };
    const emojis = { input: "⏸️", error: "⚠️", done: "✅" };
    const tags = {
      input: "hourglass_flowing_sand",
      error: "warning",
      done: "white_check_mark",
    };
    const line =
      text
        .split("\n")
        .map((s) => s.trim())
        .find(Boolean) ?? "";

    await fetch(NTFY_URL, {
      method: "POST",
      headers: {
        Title: `${titles[kind]}: ${name}`,
        // Always ntfy default (3 = medium). Hermes: pi must only ever send
        // medium priority — no "high" even when needs input.
        Priority: "default",
        Tags: tags[kind],
        Click: WEB_URL,
      },
      body: `${emojis[kind]} ${line}`.slice(0, 150),
    }).catch((e) => console.error(`ntfy: failed to send notification: ${e}`));
  });
}
