import type { RustTokenStreamInterface } from "../generated/ts/quaynor";
import { TokenStream } from "../src/streaming";

function mockStream(tokens: (string | undefined)[]): RustTokenStreamInterface {
  let index = 0;
  return {
    nextToken: async () => tokens[index++],
    completed: async () => tokens.filter((t): t is string => t !== undefined).join(""),
  };
}

describe("TokenStream", () => {
  test("nextToken returns tokens then undefined", async () => {
    const stream = new TokenStream(mockStream(["Hello", " ", "world", undefined]));

    expect(await stream.nextToken()).toBe("Hello");
    expect(await stream.nextToken()).toBe(" ");
    expect(await stream.nextToken()).toBe("world");
    expect(await stream.nextToken()).toBeUndefined();
  });

  test("completed returns full response", async () => {
    const stream = new TokenStream(mockStream(["The", " sky", " is", " blue", undefined]));

    await expect(stream.completed()).resolves.toBe("The sky is blue");
  });

  test("async iterator yields all tokens", async () => {
    const stream = new TokenStream(mockStream(["a", "b", "c", undefined]));
    const tokens: string[] = [];

    for await (const token of stream) {
      tokens.push(token);
    }

    expect(tokens).toEqual(["a", "b", "c"]);
  });

  test("async iterator yields nothing for empty stream", async () => {
    const stream = new TokenStream(mockStream([undefined]));
    const tokens: string[] = [];

    for await (const token of stream) {
      tokens.push(token);
    }

    expect(tokens).toEqual([]);
  });

  test("completed delegates to inner stream", async () => {
    const inner: RustTokenStreamInterface = {
      nextToken: async () => undefined,
      completed: async () => "done",
    };
    const stream = new TokenStream(inner);

    await expect(stream.completed()).resolves.toBe("done");
  });
});
