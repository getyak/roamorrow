import type { ReactNode } from "react";

/** Render the approved policy's limited Markdown without accepting raw HTML. */
function inlineContent(text: string): ReactNode[] {
  return text.split(/(\[[^\]]+\]\(https:\/\/[^)]+\)|\*\*[^*]+\*\*|`[^`]+`)/g).map((part, index) => {
    const link = /^\[([^\]]+)\]\((https:\/\/[^)]+)\)$/.exec(part);
    if (link) {
      return (
        <a key={index} href={link[2]} className="underline underline-offset-4">
          {link[1]}
        </a>
      );
    }
    if (part.startsWith("**") && part.endsWith("**")) {
      return <strong key={index}>{part.slice(2, -2)}</strong>;
    }
    if (part.startsWith("`") && part.endsWith("`")) {
      return (
        <code key={index} className="break-words font-mono text-[0.9em]">
          {part.slice(1, -1)}
        </code>
      );
    }
    return part;
  });
}

function tableCells(row: string): string[] {
  return row
    .trim()
    .replace(/^\||\|$/g, "")
    .split("|")
    .map((cell) => cell.trim());
}

export function PolicyText({ text }: { text: string }) {
  return text.split(/\n\s*\n/).map((block, index) => {
    if (block.startsWith("### ")) {
      return (
        <h3 key={index} className="mt-12 font-display text-[24px] font-medium">
          {block.slice(4)}
        </h3>
      );
    }
    const lines = block.split("\n");
    if (lines[0]?.startsWith("|") && lines[1]?.trim().startsWith("| -")) {
      const headings = tableCells(lines[0]);
      return (
        <div key={index} className="my-8 overflow-x-auto">
          <table className="w-full table-fixed border-collapse text-left font-body text-[14px] leading-relaxed md:text-[16px]">
            <thead>
              <tr className="border-b border-border-default">
                {headings.map((heading, cellIndex) => (
                  <th
                    key={cellIndex}
                    scope="col"
                    className={`p-3 align-top font-medium ${cellIndex === 0 ? "w-[28%]" : ""}`}
                  >
                    {inlineContent(heading)}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {lines.slice(2).map((row, rowIndex) => (
                <tr key={rowIndex} className="border-b border-border-subtle">
                  {tableCells(row).map((cell, cellIndex) =>
                    cellIndex === 0 ? (
                      <th
                        key={cellIndex}
                        scope="row"
                        className="break-words p-3 align-top font-medium"
                      >
                        {inlineContent(cell)}
                      </th>
                    ) : (
                      <td key={cellIndex} className="break-words p-3 align-top text-fg-muted">
                        {inlineContent(cell)}
                      </td>
                    ),
                  )}
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      );
    }
    return (
      <p key={index} className="ds-body-lg mt-6 whitespace-pre-line text-fg-muted">
        {inlineContent(block)}
      </p>
    );
  });
}
