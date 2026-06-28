import { PromptPart } from "../generated/ts/quaynor";
import { Prompt } from "../src/prompt";

describe("Prompt", () => {
  test("builds text parts", () => {
    const prompt = new Prompt([Prompt.Text("Hello")]);

    expect(prompt._parts).toHaveLength(1);
    expect(prompt._parts[0]).toEqual(new PromptPart.Text({ content: "Hello" }));
  });

  test("builds image parts", () => {
    const prompt = new Prompt([Prompt.Image("./dog.png")]);

    expect(prompt._parts).toHaveLength(1);
    expect(prompt._parts[0]).toEqual(new PromptPart.Image({ path: "./dog.png" }));
  });

  test("builds audio parts", () => {
    const prompt = new Prompt([Prompt.Audio("./clip.wav")]);

    expect(prompt._parts).toHaveLength(1);
    expect(prompt._parts[0]).toEqual(new PromptPart.Audio({ path: "./clip.wav" }));
  });

  test("combines multiple parts in order", () => {
    const prompt = new Prompt([
      Prompt.Text("Describe this:"),
      Prompt.Image("./a.png"),
      Prompt.Text("And this:"),
      Prompt.Image("./b.png"),
      Prompt.Audio("./c.wav"),
    ]);

    expect(prompt._parts).toHaveLength(5);
    expect(prompt._parts[0]).toEqual(new PromptPart.Text({ content: "Describe this:" }));
    expect(prompt._parts[1]).toEqual(new PromptPart.Image({ path: "./a.png" }));
    expect(prompt._parts[2]).toEqual(new PromptPart.Text({ content: "And this:" }));
    expect(prompt._parts[3]).toEqual(new PromptPart.Image({ path: "./b.png" }));
    expect(prompt._parts[4]).toEqual(new PromptPart.Audio({ path: "./c.wav" }));
  });
});
