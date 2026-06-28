import {
  Message,
  Message_Tags,
  Role,
  type Asset,
  type ToolCall,
} from "../generated/ts/quaynor";
import { fromInternal, toInternal, type ChatMessage } from "../src/message";

describe("fromInternal", () => {
  test("converts user message without assets", () => {
    const internal = Message.Message.new({
      role: Role.User,
      content: "Hello",
      assets: [],
    });

    expect(fromInternal(internal)).toEqual({
      role: Role.User,
      content: "Hello",
    });
  });

  test("converts assistant message with assets", () => {
    const assets: Asset[] = [{ id: "img-1", path: "./photo.png" }];
    const internal = Message.Message.new({
      role: Role.Assistant,
      content: "I see an image",
      assets,
    });

    expect(fromInternal(internal)).toEqual({
      role: Role.Assistant,
      content: "I see an image",
      assets,
    });
  });

  test("converts system message", () => {
    const internal = Message.Message.new({
      role: Role.System,
      content: "You are helpful.",
      assets: [],
    });

    expect(fromInternal(internal)).toEqual({
      role: Role.System,
      content: "You are helpful.",
    });
  });

  test("converts tool calls message", () => {
    const toolCalls: ToolCall[] = [
      { name: "get_weather", argumentsJson: '{"city":"Oslo"}' },
    ];
    const internal = Message.ToolCalls.new({
      role: Role.Assistant,
      content: "",
      toolCalls,
    });

    expect(fromInternal(internal)).toEqual({
      role: Role.Assistant,
      content: "",
      toolCalls,
    });
  });

  test("converts tool response message", () => {
    const internal = Message.ToolResp.new({
      role: Role.Tool,
      name: "get_weather",
      content: '{"temp": 12}',
    });

    expect(fromInternal(internal)).toEqual({
      role: Role.Tool,
      name: "get_weather",
      content: '{"temp": 12}',
    });
  });
});

describe("toInternal", () => {
  test("converts user message without assets", () => {
    const msg: ChatMessage = { role: Role.User, content: "Hello" };
    const internal = toInternal(msg);

    expect(internal.tag).toBe(Message_Tags.Message);
    expect(internal.inner).toEqual({
      role: Role.User,
      content: "Hello",
      assets: [],
    });
  });

  test("converts message with assets", () => {
    const assets: Asset[] = [{ id: "img-1", path: "./photo.png" }];
    const msg: ChatMessage = {
      role: Role.User,
      content: "Look at this",
      assets,
    };
    const internal = toInternal(msg);

    expect(internal.tag).toBe(Message_Tags.Message);
    if (internal.tag === Message_Tags.Message) {
      expect(internal.inner.assets).toEqual(assets);
    }
  });

  test("converts tool calls message", () => {
    const toolCalls: ToolCall[] = [
      { name: "search", argumentsJson: '{"query":"test"}' },
    ];
    const msg: ChatMessage = {
      role: Role.Assistant,
      content: "Let me search",
      toolCalls,
    };
    const internal = toInternal(msg);

    expect(internal.tag).toBe(Message_Tags.ToolCalls);
    expect(internal.inner).toEqual({
      role: Role.Assistant,
      content: "Let me search",
      toolCalls,
    });
  });

  test("converts tool response message", () => {
    const msg: ChatMessage = {
      role: Role.Tool,
      name: "search",
      content: "found 3 results",
    };
    const internal = toInternal(msg);

    expect(internal.tag).toBe(Message_Tags.ToolResp);
    expect(internal.inner).toEqual({
      role: Role.Tool,
      name: "search",
      content: "found 3 results",
    });
  });
});

describe("fromInternal / toInternal round trip", () => {
  const cases: ChatMessage[] = [
    { role: Role.User, content: "Hi" },
    {
      role: Role.Assistant,
      content: "Hello",
      assets: [{ id: "a1", path: "/tmp/img.png" }],
    },
    {
      role: Role.Assistant,
      content: "",
      toolCalls: [{ name: "calc", argumentsJson: '{"x":1}' }],
    },
    { role: Role.Tool, name: "calc", content: "1" },
  ];

  test.each(cases)("round trips %j", (msg) => {
    expect(fromInternal(toInternal(msg))).toEqual(msg);
  });

  test.each([
    Message.Message.new({
      role: Role.System,
      content: "Be concise.",
      assets: [],
    }),
    Message.ToolCalls.new({
      role: Role.Assistant,
      content: "Calling tool",
      toolCalls: [{ name: "foo", argumentsJson: "{}" }],
    }),
    Message.ToolResp.new({
      role: Role.Tool,
      name: "foo",
      content: "ok",
    }),
  ])("round trips internal message", (internal) => {
    expect(toInternal(fromInternal(internal))).toEqual(internal);
  });
});
